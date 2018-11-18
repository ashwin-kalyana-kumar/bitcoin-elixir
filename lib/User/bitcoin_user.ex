defmodule User.BitcoinUser do
  use GenServer

  def start_link(id, pid, neighbors) do
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

    state = %User.UserStruct{id: id, wallet: wallet, neighbors: neighbors, incoming_txns: []}

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

    if(unspent and authentic) do
      :valid
    else
      :invalid
    end
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

        state = state |> Map.put(:wallet, new_wallet)

        GenServer.cast(
          Map.get(state.wallet.pubkey_hashes, id).user_pid,
          {:you_received_bitcoin, txid, amount}
        )
    end

    {:noreply, state}
  end

  def handle_cast({:you_received_bitcoin, txid, amount}, state) do
    new_wallet =
      state.wallet
      |> Map.update(:unused_transactions, [], &[transaction.txid | &1])
      |> Map.update(:balance, 0, &(&1 + amount))

    state = state |> Map.put(:wallet, new_wallet)
    {:noreply, state}
  end
end
