defmodule User.BitcoinUser do
  use GenServer

  def start_link(id, pid, neighbors, block_chain) do
    {pub_key, priv_key} = Crypto.CryptoModule.get_key_pair()
    public_key_hash = Crypto.CryptoModule.hash_key(pub_key)

    wallet = %User.Wallet{
      private_key: priv_key,
      public_key: pub_key,
      pubkey_hash_script: public_key_hash,
      pubkey_hashes: %{},
      # change to zero
      balance: 100,
      unused_transactions: [],
      mint_master_pid: pid
    }

    state = %User.UserStruct{
      id: id,
      wallet: wallet,
      neighbors: neighbors,
      incoming_txns: [],
      block_chain: block_chain
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
      transaction_output: txn_output
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
      authentic -> :authentic
      true -> :invalid
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
        IO.puts("This is not supposed to happen!")
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

  defp verify_block(prev_block_list, block) do
    invalid_txns =
      block.transactions
      |> Enum.filter(fn txn -> check_authenticity_of_txn(txn) === :invalid end)

    txids = get_txids_from_transactions(block.transactions)
    merkle = calculate_merkle(txids)

    prev_block =
      prev_block_list
      |> Enum.filter(fn x -> x.header.block_hash === block.header.previous_block_hash end)

    block_integrity = check_block_hash(block)

    if(
      invalid_txns === [] and merkle === block.block_header.merkle_root and prev_block != [] and
        block_integrity
    ) do
      :valid
    else
      :invalid
    end
  end

  defp delete_unwanted_branches(chain_map, last_block_number) do
    [latest_block | _rest] = chain_map |> Map.get(last_block_number)
    prev_hash = latest_block.block_header.previous_block_hash

    prev1_block =
      chain_map
      |> Map.get(last_block_number - 1)
      |> Enum.filter(fn x -> x.block_header.block_hash === prev_hash end)

    prev2_block =
      chain_map
      |> Map.get(last_block_number - 2)
      |> Enum.filter(fn x ->
        x.block_header.block_hash === prev1_block.block_header.previous_block_hash
      end)

    prev3_block =
      chain_map
      |> Map.get(last_block_number - 3)
      |> Enum.filter(fn x ->
        x.block_header.block_hash === prev2_block.block_header.previous_block_hash
      end)

    prev4_block =
      chain_map
      |> Map.get(last_block_number - 4)
      |> Enum.filter(fn x ->
        x.block_header.block_hash === prev3_block.block_header.previous_block_hash
      end)

    prev5_block =
      chain_map
      |> Map.get(last_block_number - 5)
      |> Enum.filter(fn x ->
        x.block_header.block_hash === prev4_block.block_header.previous_block_hash
      end)

    chain_map |> Map.put(last_block_number - 5, [prev5_block])
  end

  defp add_block_to_chain(chain, block) do
    cond do
      block.block_number < chain.latest_block_number - 5 ->
        chain

      block.block_number <= chain.latest_block_number ->
        updated_map = chain.block_map |> Map.update(block.number, [block], &[block, &1])
        chain |> Map.put(:block_map, updated_map)

      block.block_number == chain.latest_block_number + 1 ->
        updated_map = chain.block_map |> Map.update(block.number, [block], &[block, &1])
        updated_map = delete_unwanted_branches(updated_map, block.block_number)

        chain
        |> Map.put(:block_map, updated_map)
        |> Map.put(:latest_block_number, block.block_number)

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

  defp broadcast_block(block, neighbors) do
    GenServer.cast(neighbors.left_guy, {:new_block, block})
    GenServer.cast(neighbors.right_guy, {:new_block, block})
    GenServer.cast(neighbors.random_guy, {:new_block, block})
  end

  defp already_got_this_transaction(transaction, incoming_txns) do
    transaction in incoming_txns
  end

  defp already_got_this_block?(block, chain) do
    block_list = chain.block_map |> Map.get(block.block_number, [])

    block_list
    |> Enum.filter(fn x -> x.block_header.block_hash == block.block_header.block_hash end)

    block_list != []
  end

  def handle_cast({:send_hash, pid}, state) do
    GenServer.cast(
      pid,
      {:this_is_my_hash, state.wallet.id, state.wallet.pubkey_hash_script, self()}
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

        transaction =
          build_transaction(
            transactions,
            amount,
            hash_struct.hash,
            excess_amount,
            state.wallet.pubkey_hash_script,
            state.wallet.public_key,
            state.wallet.private_key
          )

        # TODO: remove the transactions which are used

        new_wallet =
          if(excess_amount > 0) do
            state.wallet
            |> Map.update(:unused_transactions, [], &[transaction.txid | &1])
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

        GenServer.cast(
          Map.get(state.wallet.pubkey_hashes, id).user_pid,
          {:you_received_bitcoin, transaction.txid, amount}
        )

        broadcast_transaction(transaction, state.neighbors)
        # TODO: tell mint guy that you made this txn
        GenServer.cast(state.wallet.mint_master_pid, {:tx_happened, transaction})
        {:noreply, state}
    end
  end

  def handle_cast({:you_received_bitcoin, txid, amount}, state) do
    new_wallet =
      state.wallet
      |> Map.update(:unused_transactions, [], &[txid | &1])
      |> Map.update(:balance, 0, &(&1 + amount))

    state = state |> Map.put(:wallet, new_wallet)
    {:noreply, state}
  end

  def handle_cast({:new_transaction, transaction}, state) do
    if(already_got_this_transaction(state, state.incoming_txns)) do
      {:noreply, state}
    else
      state = state |> Map.update(:incoming_txns, [transaction], &[transaction | &1])
      {:noreply, state}
    end
  end

  def handle_cast({:update_neighbors, node_map}, state) do
    neighbours = state.neighbours
    {_, left_n} = Map.fetch!(node_map, neighbours.left_guy)
    {_, right_n} = Map.fetch!(node_map, neighbours.right_guy)
    {_, random_n} = Map.fetch!(node_map, neighbours.random_guy)

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

  def handle_cast({:new_block, block}, state) do
    # TODO: check if you already have that block, if so ignore this message, else do the following and broadcast this message

    if(already_got_this_block?(block, state.block_chain)) do
      {:noreply, state}
    else
      broadcast_block(block, state.neighbors)
      spawned_pid = state.spawned_process

      if Process.alive?(spawned_pid) do
        Process.exit(spawned_pid, :kill)
      end

      valid =
        verify_block(
          Map.get(state.block_chain.block_map, state.block_chain.latest_block_number),
          block
        )

      {new_block_chain, updated_incoming_txns} =
        if(valid == :valid) do
          new_chain = add_block_to_chain(state.block_chain, block)
          updated_txns = update_incoming_txns(state.incoming_txns, block)
          {new_chain, updated_txns}
        else
          {state.block_chain, state.incoming_txns}
        end

      new_pid =
        Process.spawn(
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
            5,
            self(),
            state.wallet.mint_master_pid
          ],
          nil
        )

      # TODO: Spawn a process to calculate the block
      # TODO: update the spawned_pid

      state =
        state
        |> Map.put(:block_chain, new_block_chain)
        |> Map.put(:incoming_txns, updated_incoming_txns)
        |> Map.put(:spawned_process, new_pid)

      {:noreply, state}
    end
  end

  def handle_cast({:you_found_a_new_block, block, input_txns}, state) do
    broadcast_block(block, state.neighbors)
    new_chain = add_block_to_chain(state.block_chain, block)
    updated_txns = update_incoming_txns(state.incoming_txns, block)

    # TODO: Spawn a process to calculate the block
    # TODO: update the spawned_pid
    # TODO: Send the input_txns to the mint processor
    GenServer.cast(state.wallet.mint_master_pid, {:block_generated, input_txns, block})

    new_pid =
      Process.spawn(
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
          5,
          self(),
          state.wallet.mint_master_pid
        ],
        nil
      )

    state =
      state
      |> Map.put(:block_chain, new_chain)
      |> Map.put(:incoming_txns, updated_txns)
      |> Map.put(:spawned_process, new_pid)

    {:noreply, state}
  end

  def handle_call({:get_neighbours}, _from, state) do
    neighbours = state.neighbors

    {:reply, neighbours, state}
  end
end
