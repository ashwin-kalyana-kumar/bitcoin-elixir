defmodule User.BitcoinUser do
  use GenServer

  def start_link(id, pid, neighbors, block_chain) do
    {pub_key, priv_key} = Crypto.CryptoModule.get_key_pair()
    public_key_hash = Crypto.CryptoModule.hash(public_key)

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

  defp build_transaction(
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

    txid = Crypto.CryptoModule.hash(transaction)
    transaction = transaction |> Map.put(:txid, txid)
    signature = Crypto.CryptoModule.digital_sign(private_key, transaction)
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

  defp verify_transaction(mint_pid, transaction) do
    unspent = check_unspent(transaction.transaction_input, mint_pid)
    sign = transaction.signature
    transaction = transaction |> Map.put(:signature, nil)
    authentic = Crypto.CryptoModule.verify_sign(transaction.public_key, transaction, sign)

    cond do
      unspent and authentic -> :valid
      authentic -> :authentic
      true -> :invalid
    end
  end

  defp check_block_hash(block) do
    hash = block.block_header.block_hash
    block = block |> Map.put(:block_header, Map.put(block.block_header, :block_hash, nil))
    new_hash = Crypto.CryptoModule.hash(block)

    if(new_hash === hash) do
      true
    else
      false
    end
  end

  defp reduce_merkle([a, b | rest]) when a === :end do
    [:end, :end]
  end

  defp reduce_merkle([a, b | rest]) when b === :end do
    [Crypto.CryptoModule.hash(a <> a), :end, :end]
  end

  defp reduce_merkle([a, b | rest]) do
    [Crypto.CryptoModule.hash(a <> b) | reduce_merkle(rest)]
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

  defp get_txids_from_transactions(transctions) when transactions == [] do
    [:end, :end]
  end

  defp get_txids_from_transactions(transactions) do
    [txn | rest] = transactions
    [txn.txid | get_txids_from_transactions(rest)]
  end

  defp verify_block(prev_block_list, block) do
    invalid_txns =
      block.transactions |> Enum.take_while(fn txn -> verify_transaction(txn) === :invalid end)

    txids = get_txids_from_transactions(block.transactions)
    merkle = calculate_merkle(txids)

    prev_block =
      prev_block_list
      |> Enum.take_while(fn x -> x.header.block_hash === block.header.previous_block_hash end)

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
      |> Enum.take_while(fn x -> x.block_header.block_hash === prev_hash end)

    prev2_block =
      chain_map
      |> Map.get(last_block_number - 2)
      |> Enum.take_while(fn x ->
        x.block_header.block_hash === prev1_block.block_header.previous_block_hash
      end)

    prev3_block =
      chain_map
      |> Map.get(last_block_number - 3)
      |> Enum.take_while(fn x ->
        x.block_header.block_hash === prev2_block.block_header.previous_block_hash
      end)

    prev4_block =
      chain_map
      |> Map.get(last_block_number - 4)
      |> Enum.take_while(fn x ->
        x.block_header.block_hash === prev3_block.block_header.previous_block_hash
      end)

    prev5_block =
      chain_map
      |> Map.get(latest_block_number - 5)
      |> Enum.take_while(fn x ->
        x.block_header.block_hash === prev4_block.block_header.previous_block_hash
      end)

    chain_map = chain_map |> Map.put(latest_block_number - 5, [prev5_block])
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

  defp update_incoming_txns(transctions, block) do
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

  def handle_cast({:send_hash, pid}, state) do
    GenServer.cast(
      pid,
      {:this_is_my_hash, state.wallet.id, state.wallet.pubkey_hash_script, self()}
    )

    {:noreply, state}
  end

  def handle_cast({:this_is_my_hash, id, hash, pid}, state) do
    value = %PubKeyHashStruct{user_pid: pid, pubkey_hash: hash}
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
          {:you_received_bitcoin, txid, amount}
        )

        broadcast_transaction(transaction, state.neighbors)
        # TODO: Tell the mint guy that you made this transaction
        {:noreply, state}
    end
  end

  def handle_cast({:you_received_bitcoin, txid, amount}, state) do
    new_wallet =
      state.wallet
      |> Map.update(:unused_transactions, [], &[transaction.txid | &1])
      |> Map.update(:balance, 0, &(&1 + amount))

    state = state |> Map.put(:wallet, new_wallet)
    {:noreply, state}
  end

  def handle_cast({:new_transaction, transaction}, state) do
    # TODO: check if you already have that block, if so ignore this message, else do the following and broadcast this message
    state = state |> Map.update(:incoming_txns, [transaction], &[transaction | &1])
    {:noreply, state}
  end

  def handle_cast({:update_neighbors, neighbors}, state) do
    state = state |> Map.put(:neighbors, neighbors)
    {:noreply, state}
  end

  def handle_cast({:new_block, block}, state) do
    # TODO: check if you already have that block, if so ignore this message, else do the following and broadcast this message
    spawned_pid = state.spawned_process

    if Process.alive?(spawned_pid) do
      Process.exit(spawned_pid, :kill)
    end

    valid = verify_block(block)

    {new_block_chain, updated_incoming_txns} =
      if(valid == :valid) do
        new_chain = add_block_to_chain(state.block_chain, block)
        updated_txns = update_incoming_txns(state.incoming_txns, block)
        {new_chain, updated_txns}
      else
        {state.block_chain, state.incoming_txns}
      end

    # TODO: Spawn a process to calculate the block
    # TODO: update the spawned_pid

    state =
      state
      |> Map.put(:block_chain, new_block_chain)
      |> Map.put(:incoming_txns, updated_incoming_txns)
      |> Map.put(:spawned_process, new_pid)

    {:noreply, state}
  end

  def handle_cast({:you_found_a_new_block, block}, state) do
    broadcast_block(block, neighbors)
    new_chain = add_block_to_chain(state.block_chain, block)
    updated_txns = update_incoming_txns(state.incoming_txns, block)

    # TODO: Spawn a process to calculate the block
    # TODO: update the spawned_pid

    state =
      state
      |> Map.put(:block_chain, new_chain)
      |> Map.put(:incoming_txns, updated_txns)
      |> Map.put(:spawned_process, new_pid)

    {:noreply, state}
  end
end
