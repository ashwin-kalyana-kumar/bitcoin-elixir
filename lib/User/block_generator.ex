defmodule User.BlockGenerator do
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

  def generate_coinbase_transaction(amount, private_key, public_key, public_key_hash) do
    coinbase_txn = %Transaction.Transaction{
      full_public_key: public_key,
      transaction_output: %Transaction.TransactionOutput{
        amount: amount,
        pub_key_script: public_key_hash
      },
      unique_id: :rand.uniform(1_000_000_000_000)
    }

    txid = Crypto.CryptoModule.hash_transaction(coinbase_txn)
    coinbase_txn = coinbase_txn |> Map.put(:txid, txid)
    sign = Crypto.CryptoModule.sign_transaction(private_key, coinbase_txn)
    coinbase_txn |> Map.put(:signature, sign)
  end

  def generate_hash(block, nonce, condition_number) do
    #    IO.puts("Trying with number #{nonce}")
    block = block |> Map.update!(:block_header, fn x -> x |> Map.put(:nonce, nonce) end)
    hash = Crypto.CryptoModule.hash_block(block)
    <<val::size(condition_number), _rest::bitstring>> = hash

    if(val == 0) do
      block |> Map.update!(:block_header, fn x -> x |> Map.put(:block_hash, hash) end)
    else
      generate_hash(block, nonce + 1, condition_number)
    end
  end

  defp verify_transaction(mint_pid, transaction) do
    # unspent = check_unspent(transaction.transaction_input, mint_pid)
    unspent =
      if(mint_pid != nil) do
        GenServer.call(
          mint_pid,
          {:verify_unspent_tx, transaction.transaction_input,
           transaction.transaction_output.amount}
        )
      else
        true
      end

    sign = transaction.signature
    transaction = transaction |> Map.put(:signature, nil)

    authentic =
      Crypto.CryptoModule.verify_transaction_sign(transaction.full_public_key, transaction, sign)

    cond do
      unspent and authentic -> :valid
      authentic -> :authentic
      true -> :invalid
    end
  end

  defp get_input_transactions(transactions) when transactions == [] do
    []
  end

  defp get_input_transactions(transactions) do
    [txn | rest] = transactions
    txn.transaction_input ++ get_input_transactions(rest)
  end

  def generate_next_block(
        block_number,
        transactions,
        coinbase_amount,
        previous_block_hash,
        public_key,
        private_key,
        public_key_hash,
        condition_number,
        success_pid,
        mint_guy,
        m_pid
      ) do
    coinbase_txn =
      generate_coinbase_transaction(coinbase_amount, private_key, public_key, public_key_hash)

    init_count = Enum.count(transactions)

    auth_count =
      Enum.count(transactions, fn x -> verify_transaction(mint_guy, x) == :authentic end)

    transactions =
      Enum.filter(transactions, fn x -> verify_transaction(mint_guy, x) == :valid end)

    #        IO.puts(
    #         "out of #{init_count} transactions #{auth_count} were authentic and #{
    #          Enum.count(transactions)
    #       } were valid"
    #    )

    input_txns = get_input_transactions(transactions)
    transactions = [coinbase_txn | transactions]
    txids = get_txids_from_transactions(transactions)
    merkle_root = calculate_merkle(txids)

    header = %BlockChain.BlockHeader{
      previous_block_hash: previous_block_hash,
      merkle_root: merkle_root,
      timestamp: :calendar.datetime_to_gregorian_seconds(:calendar.universal_time())
    }

    block = %BlockChain.Block{
      block_number: block_number,
      block_header: header,
      transactions: transactions
    }

    block = generate_hash(block, :rand.uniform(1_000_000_000), condition_number)
    GenServer.cast(success_pid, {:you_found_a_new_block, block, input_txns, m_pid})
    block
  end
end
