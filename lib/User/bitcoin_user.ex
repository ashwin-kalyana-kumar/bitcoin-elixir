defmodule User.BitcoinUser do
  use GenServer

  def start_link(id, pid, neighbors, block_chain, miner) do
    {pub_key, priv_key} = Crypto.CryptoModule.get_key_pair()
    public_key_hash = Crypto.CryptoModule.hash_key(pub_key)

    wallet = %User.Wallet{
      private_key: priv_key,
      public_key: pub_key,
      pubkey_hash_script: public_key_hash,
      pubkey_hashes: %{},
      # change to zero
      balance: 0,
      unused_transactions: [],
      mint_master_pid: pid
    }

    state = %User.UserStruct{
      id: id,
      wallet: wallet,
      neighbors: neighbors,
      incoming_txns: [],
      block_chain: block_chain,
      miner: miner
    }

    GenServer.start_link(__MODULE__, state)
  end

  def init(state) do
    {:ok, state}
  end

  defp get_transactions(_transactions, amount, _script) when amount <= 0 do
    {0 - amount, []}
  end

  defp get_transactions(transactions, amount, script) do
    [first | rest] = transactions

    current_amount =
      cond do
        first.transaction_output.pub_key_script === script ->
          first.transaction_output.amount

        first.transaction_output.sender_pub_key_script === script ->
          first.transaction_output.got_back_amount

        true ->
          0
      end

    {excess_amount, txns} = get_transactions(rest, amount - current_amount, script)
    {excess_amount, [first | txns]}
  end

  defp build_transaction_input(input_transactions, _hash) when input_transactions === [] do
    []
  end

  defp build_transaction_input(input_transactions, hash) do
    [first | rest] = input_transactions

    txn_input = %Transaction.TransactionInput{txid: first.txid, public_key_hash: hash}
    [txn_input | build_transaction_input(rest, hash)]
  end

  def build_transaction(
        input_transactions,
        amount,
        pubkey_hash,
        get_back_amount,
        self_pubkey_hash,
        full_public_key,
        private_key
      ) do
    txn_input = build_transaction_input(input_transactions, self_pubkey_hash)

    txn_output = %Transaction.TransactionOutput{
      amount: amount,
      pub_key_script: pubkey_hash,
      got_back_amount: get_back_amount,
      sender_pub_key_script: self_pubkey_hash
    }

    transaction = %Transaction.Transaction{
      full_public_key: full_public_key,
      transaction_input: txn_input,
      transaction_output: txn_output,
      unique_id: :rand.uniform(1_000_000_000_000)
    }

    txid = Crypto.CryptoModule.hash_transaction(transaction)
    transaction = transaction |> Map.put(:txid, txid)
    signature = Crypto.CryptoModule.sign_transaction(private_key, transaction)
    transaction = transaction |> Map.put(:signature, signature)
    transaction
  end

  defp check_unspent(txids, _mint_pid) when txids == [] do
    true
  end

  defp check_unspent(txids, mint_pid) do
    # TODO: check if this is a coinbase transaction. txids == nil inside the mint genserver
    [first | rest] = txids
    # TODO: implement the mint gen server
    txn_status = GenServer.call(mint_pid, {:check_status, first})

    if(txn_status === :valid) do
      check_unspent(rest, mint_pid)
    else
      false
    end
  end

  def check_authenticity_of_txn(transaction) do
    sign = transaction.signature
    transaction = transaction |> Map.put(:signature, nil)

    authentic =
      Crypto.CryptoModule.verify_transaction_sign(transaction.full_public_key, transaction, sign)

    cond do
      authentic ->
        #        IO.puts("Authentic Transaction")
        :authentic

      true ->
        #        IO.puts("Invalid_transaction")
        :invalid
    end
  end

  defp check_block_hash(block) do
    hash = block.block_header.block_hash
    block = block |> Map.put(:block_header, Map.put(block.block_header, :block_hash, nil))
    new_hash = Crypto.CryptoModule.hash_block(block)

    if(new_hash === hash) do
      true
    else
      false
    end
  end

  defp reduce_merkle([a, _b | _rest]) when a === :end do
    [:end, :end]
  end

  defp reduce_merkle([a, b | _rest]) when b === :end do
    [Crypto.CryptoModule.hash_binary(a <> a), :end, :end]
  end

  defp reduce_merkle([a, b | rest]) do
    [Crypto.CryptoModule.hash_binary(a <> b) | reduce_merkle(rest)]
  end

  defp calculate_merkle([a, b | rest]) do
    cond do
      a === :end ->
       # IO.puts("This is not supposed to happen!")
        0

      b === :end ->
        a

      true ->
        calculate_merkle(reduce_merkle([a, b | rest]))
    end
  end

  defp get_txids_from_transactions(transactions) when transactions == [] do
    [:end, :end]
  end

  defp get_txids_from_transactions(transactions) do
    [txn | rest] = transactions
    [txn.txid | get_txids_from_transactions(rest)]
  end

  def verify_block(prev_block_list, block) do
    invalid_txns =
      block.transactions
      |> Enum.filter(fn txn -> check_authenticity_of_txn(txn) === :invalid end)

    txids = get_txids_from_transactions(block.transactions)
    merkle = calculate_merkle(txids)

    prev_block =
      if(prev_block_list == nil || prev_block_list == []) do
        [1]
      else
        # IO.inspect(prev_block_list)

        prev_block_list
        |> Enum.filter(fn x ->
          x.block_header.block_hash === block.block_header.previous_block_hash
        end)
      end

    block_integrity = check_block_hash(block)
    #    IO.inspect(prev_block_list)

    if(
      invalid_txns === [] and merkle === block.block_header.merkle_root and prev_block != [] and
        block_integrity
    ) do
      #    IO.puts("valid block!!")
      :valid
    else
      # IO.puts(
      #   "invalid block user_pid!! because #{invalid_txns === []} and #{
      #     merkle === block.block_header.merkle_root
      #   } and #{prev_block != []} and #{block_integrity}"
      # )

      :invalid
    end
  end

  defp delete_unwanted_branches(chain_map, last_block_number) do
    if(last_block_number < 6) do
      chain_map
    else
      [latest_block | _rest] = chain_map |> Map.get(last_block_number)

      try do
        prev_hash = latest_block.block_header.previous_block_hash
        # get proper chain from someoone
        [prev1_block] =
          chain_map
          |> Map.get(last_block_number - 1, [])
          |> Enum.filter(fn x -> x.block_header.block_hash === prev_hash end)

        [prev2_block] =
          chain_map
          |> Map.get(last_block_number - 2, [])
          |> Enum.filter(fn x ->
            x.block_header.block_hash === prev1_block.block_header.previous_block_hash
          end)

        [prev3_block] =
          chain_map
          |> Map.get(last_block_number - 3, [])
          |> Enum.filter(fn x ->
            x.block_header.block_hash === prev2_block.block_header.previous_block_hash
          end)

        [prev4_block] =
          chain_map
          |> Map.get(last_block_number - 4, [])
          |> Enum.filter(fn x ->
            x.block_header.block_hash === prev3_block.block_header.previous_block_hash
          end)

        [prev5_block] =
          chain_map
          |> Map.get(last_block_number - 5, [])
          |> Enum.filter(fn x ->
            x.block_header.block_hash === prev4_block.block_header.previous_block_hash
          end)

        chain_map |> Map.put(last_block_number - 5, [prev5_block])
      rescue
        _e in MatchError ->
          #        IO.puts("Latest Block")
          #        IO.inspect( Map.get(chain_map,last_block_number, []), limit: :infinity)
          #        IO.puts("Block no -1")
          #        IO.inspect( Map.get(chain_map,last_block_number - 1, []))
          #        IO.puts("Block no -2")
          #        IO.inspect( Map.get(chain_map,last_block_number - 2, []))
          #        IO.puts("Block no -3")
          #        IO.inspect( Map.get(chain_map,last_block_number - 3, []))
          #        IO.puts("Block no -4")
          #        IO.inspect( Map.get(chain_map,last_block_number - 4, []))
          #        IO.puts("Block no -5")
          #        IO.inspect( Map.get(chain_map,last_block_number - 5, []))
       #   IO.puts("problem in branch deletion.")
          chain_map
      end
    end
  end

  defp add_block_to_chain(chain, block) do
    cond do
      block.block_number < chain.latest_block_number - 5 ->
        chain

      block.block_number <= chain.latest_block_number ->
        updated_map = chain.block_map |> Map.update(block.block_number, [block], &[block | &1])

        chain |> Map.put(:block_map, updated_map)

      block.block_number == chain.latest_block_number + 1 ->
        updated_map = chain.block_map |> Map.update(block.block_number, [block], &[block | &1])
        updated_map = delete_unwanted_branches(updated_map, block.block_number)

        chain =
          chain
          |> Map.put(:block_map, updated_map)
          |> Map.put(:latest_block_number, block.block_number)

        chain

      true ->
        chain
    end
  end

  defp update_incoming_txns(transactions, block) do
    transactions |> Enum.reject(&(&1 in block.transactions))
  end

  defp broadcast_transaction(transaction, neighbors) do
    GenServer.cast(neighbors.left_guy, {:new_transaction, transaction})
    GenServer.cast(neighbors.right_guy, {:new_transaction, transaction})
    GenServer.cast(neighbors.random_guy, {:new_transaction, transaction})
  end

  defp broadcast_block(block, neighbors, pid, m_pid) do
    GenServer.cast(neighbors.left_guy, {:new_block, block, pid, m_pid})
    GenServer.cast(neighbors.right_guy, {:new_block, block, pid, m_pid})
    GenServer.cast(neighbors.random_guy, {:new_block, block, pid, m_pid})
  end

  defp already_got_this_transaction(transaction, incoming_txns) do
    transaction in incoming_txns
  end

  defp already_got_this_block?(block, chain) do
    block_list = chain.block_map |> Map.get(block.block_number, [])

    unique_list =
      block_list
      |> Enum.filter(fn x -> x.block_header.block_hash == block.block_header.block_hash end)

    if(unique_list != []) do
      true
    else
      false
    end
  end

  def handle_cast({:send_hash, pid}, state) do
    GenServer.cast(
      pid,
      {:this_is_my_hash, state.id, state.wallet.pubkey_hash_script, self()}
    )

    {:noreply, state}
  end

  def handle_cast({:this_is_my_hash, id, hash, pid}, state) do
    value = %User.PubKeyHashStruct{user_pid: pid, pubkey_hash: hash}
    pubkey_hashes = state.wallet |> Map.get(:pubkey_hashes)
    pubkey_hashes = pubkey_hashes |> Map.put(id, value)
    updated_wallet = state.wallet |> Map.put(:pubkey_hashes, pubkey_hashes)
    state = state |> Map.put(:wallet, updated_wallet)

    {:noreply, state}
  end

  def handle_cast({:request_bitcoin, pid, amount}, state) do
    GenServer.cast(pid, {:this_is_my_hash, state.id, state.wallet.pubkey_hash_script, self()})
    GenServer.cast(pid, {:send_money, state.id, amount})
    {:noreply, state}
  end

  def handle_cast({:send_money, id, amount}, state) do
    cond do
      state.wallet.unused_transactions == [] ->
        {:noreply, state}

      state.wallet.balance < amount ->
        {:noreply, state}

      true ->
        {excess_amount, transactions} =
          get_transactions(
            state.wallet.unused_transactions,
            amount,
            state.wallet.pubkey_hash_script
          )

        hash_struct = Map.get(state.wallet.pubkey_hashes, id)

        if(hash_struct != nil) do
          transaction =
            build_transaction(
              transactions,
              amount,
              hash_struct.pubkey_hash,
              excess_amount,
              state.wallet.pubkey_hash_script,
              state.wallet.public_key,
              state.wallet.private_key
            )

          # TODO: remove the transactions which are used

          new_wallet =
            if(excess_amount > 0) do
              state.wallet
              |> Map.update(:unused_transactions, [transaction], fn x ->
                List.insert_at(x, Enum.count(x), transaction)
              end)
              |> Map.update(:balance, 0, &(&1 - amount))
            else
              state.wallet |> Map.update(:balance, 0, &(&1 - amount))
            end

          new_wallet =
            new_wallet
            |> Map.update(:unused_transactions, [], fn x ->
              Enum.reject(x, fn item -> item in transactions end)
            end)

          state = state |> Map.put(:wallet, new_wallet)
          #          IO.puts("#{state.id} sent money to #{id}")

          GenServer.cast(
            Map.get(state.wallet.pubkey_hashes, id).user_pid,
            {:you_received_bitcoin, transaction.txid, amount}
          )

          broadcast_transaction(transaction, state.neighbors)
          # TODO: tell mint guy that you made this txn
          GenServer.cast(state.wallet.mint_master_pid, {:tx_happened, transaction})
          {:noreply, state}
        else
          {:noreply, state}
        end
    end
  end

  def handle_cast({:you_received_bitcoin, txid, amount}, state) do
    new_wallet =
      state.wallet
      |> Map.update(:unused_transactions, [], &[txid | &1])
      |> Map.update(:balance, 0, &(&1 + amount))

    #    IO.puts("#{state.id} got money. new balance #{new_wallet.balance}")
    state = state |> Map.put(:wallet, new_wallet)
    {:noreply, state}
  end

  def handle_cast({:new_transaction, transaction}, state) do
    if(already_got_this_transaction(transaction, state.incoming_txns)) do
      {:noreply, state}
    else
      #    IO.inspect(transaction.txid)
      state = state |> Map.update(:incoming_txns, [transaction], &[transaction | &1])
      broadcast_transaction(transaction, state.neighbors)
      {:noreply, state}
    end
  end

  def handle_cast({:update_neighbors, node_map}, state) do
    neighbours = state.neighbors
    left_n = Map.fetch!(node_map, neighbours.left_guy)
    right_n = Map.fetch!(node_map, neighbours.right_guy)
    random_n = Map.fetch!(node_map, neighbours.random_guy)

    update_neighbours = %User.NeighborStruct{
      left_guy: left_n,
      right_guy: right_n,
      random_guy: random_n
    }

    state = state |> Map.put(:neighbors, update_neighbours)
    {:noreply, state}
  end

  def handle_cast({:update_neighbours_dueto_new_node, {which_neigh, node_pid}}, state) do
    neighbours = state.neighbors

    neighbours =
      if which_neigh == :right_negh do
        Map.put(neighbours, :right_guy, node_pid)
      else
        Map.put(neighbours, :left_guy, node_pid)
      end

    state =
      state
      |> Map.put(:neighbors, neighbours)

    {:noreply, state}
  end

  def handle_cast({:start_mining, m_pid}, state) do
    previous_block_hash =
      if(state.block_chain.latest_block_number == 0) do
        nil
      else
        state.block_chain.block_map
        |> Map.get(state.block_chain.latest_block_number)
        |> hd
        |> Map.get(:block_header)
        |> Map.get(:block_hash)
      end

    new_pid =
      spawn(
        User.BlockGenerator,
        :generate_next_block,
        [
          state.block_chain.latest_block_number + 1,
          state.incoming_txns,
          50,
          previous_block_hash,
          state.wallet.public_key,
          state.wallet.private_key,
          state.wallet.pubkey_hash_script,
          20,
          self(),
          state.wallet.mint_master_pid,
          m_pid
        ]
      )

    state = state |> Map.put(:spawned_process, new_pid)

    {:noreply, state}
  end

  def handle_cast({:check_your_blockchain, m_pid}, state) do
    update_blockchain = GenServer.call(m_pid, {:get_blockchain})

    new_state = state |> Map.update!(:block_chain, fn _x -> update_blockchain end)

    {:noreply, new_state}
  end

  def handle_cast({:new_block, block, pid, m_pid}, state) do
    # TODO: check if you already have that block, if so ignore this message, else do the following and broadcast this message
    cond do
      block.block_number > state.block_chain.latest_block_number + 1 ->
        update_blockchain = GenServer.call(m_pid, {:get_blockchain})

        new_state = state |> Map.update!(:block_chain, fn _x -> update_blockchain end)

        {:noreply, new_state}

      block.block_number < state.block_chain.latest_block_number - 5 ->
        GenServer.cast(pid, {:check_your_blockchain, m_pid})
        {:noreply, state}

      true ->
        if(already_got_this_block?(block, state.block_chain)) do
          {:noreply, state}
        else
          spawned_pid = state.spawned_process

          valid =
            verify_block(
              Map.get(state.block_chain.block_map, block.block_number - 1),
              block
            )

          longest_chain = state.block_chain.latest_block_number

          new_state =
            if(valid == :valid and longest_chain <= block.block_number) do
              broadcast_block(block, state.neighbors, pid, m_pid)
              new_block_chain = add_block_to_chain(state.block_chain, block)
              updated_incoming_txns = update_incoming_txns(state.incoming_txns, block)

              new_pid =
                if(state.miner) do
                  if Process.alive?(spawned_pid) do
                    Process.exit(spawned_pid, :kill)
                    #      IO.puts("killing the process state = #{Process.alive?(spawned_pid)}")
                  end

                  spawn(
                    User.BlockGenerator,
                    :generate_next_block,
                    [
                      block.block_number + 1,
                      state.incoming_txns,
                      50,
                      block.block_header.block_hash,
                      state.wallet.public_key,
                      state.wallet.private_key,
                      state.wallet.pubkey_hash_script,
                      20,
                      self(),
                      state.wallet.mint_master_pid,
                      m_pid
                    ]
                  )
                else
                  nil
                end

              state
              |> Map.put(:block_chain, new_block_chain)
              |> Map.put(:incoming_txns, updated_incoming_txns)
              |> Map.put(:spawned_process, new_pid)
            else
              state
            end

          # TODO: Spawn a process to calculate the block
          # TODO: update the spawned_pid
          #      IO.puts("this is #{state.id}\'s chain")
          #      IO.inspect(new_block_chain)

          {:noreply, new_state}
        end
    end

    # To update this node blockchain as it is different from the rest of the network

    # To update the node that has sent the new blockc as it is different from the rest of the network
  end

  def handle_cast({:you_found_a_new_block, block, _input_txns, m_pid}, state) do
    longest_chain = state.block_chain.latest_block_number

    # Verify the block
    valid =
      verify_block(
        Map.get(state.block_chain.block_map, block.block_number - 1),
        block
      )

    {new_state, new_block_number} =
      if(longest_chain <= block.block_number and valid == :valid) do
        broadcast_block(block, state.neighbors, self(), m_pid)
        new_chain = add_block_to_chain(state.block_chain, block)
        before_updating = Enum.count(state.incoming_txns)
        updated_txns = update_incoming_txns(state.incoming_txns, block)

        # TODO: Spawn a process to calculate the block
        # TODO: update the spawned_pid
        # TODO: Send the input_txns to the mint processor
        GenServer.cast(state.wallet.mint_master_pid, {:block_generated, block})
        count = Enum.count(block.transactions)

        # IO.puts(
        #   "#{state.id} generated a new block with block number #{block.block_number} with #{count} transactions and has #{
        #     Enum.count(updated_txns)
        #   } transactions left out of #{before_updating}"
        # )

        #        IO.inspect(block.block_header.block_hash)
        new_wallet = state.wallet

        new_wallet =
          new_wallet
          |> Map.update(:balance, 50, fn x -> x + 50 end)
          |> Map.update(:unused_transactions, [hd(block.transactions)], fn x ->
            List.insert_at(x, Enum.count(x), hd(block.transactions))
          end)

        state =
          state
          |> Map.put(:block_chain, new_chain)
          |> Map.put(:incoming_txns, updated_txns)
          |> Map.put(:wallet, new_wallet)

        {state, block.block_number + 1}
      else
        {state, longest_chain + 1}
      end

    new_pid =
      spawn(
        User.BlockGenerator,
        :generate_next_block,
        [
          new_block_number,
          new_state.incoming_txns,
          50,
          block.block_header.block_hash,
          new_state.wallet.public_key,
          new_state.wallet.private_key,
          new_state.wallet.pubkey_hash_script,
          20,
          self(),
          new_state.wallet.mint_master_pid,
          m_pid
        ]
      )

    new_state =
      new_state
      |> Map.put(:spawned_process, new_pid)

    {:noreply, new_state}
  end

  def handle_call({:print_wallet}, _from, state) do
    {:reply, state.wallet.balance, state}
  end

  def handle_call({:get_neighbours}, _from, state) do
    neighbours = state.neighbors

    {:reply, neighbours, state}
  end
end
