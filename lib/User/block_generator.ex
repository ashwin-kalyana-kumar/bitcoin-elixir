defmodule User.BlockGenerator do
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

  defp generate_coinbase_transaction(amount, private_key, public_key, public_key_hash) do
    coinbase_txn = %Transaction.Transaction{
      full_public_key: public_key,
      transaction_output: %Transaction.TransactionOutput{
        amount: amount,
        pub_key_script: public_key_hash
      }
    }

    txid = Crypto.CryptoModule.hash(coinbase_txn)
    coinbase_txn = coinbase_txn |> Map.put(:txid, txid)
    sign = Crypto.CryptoModule.sign(private_key, coinbase_txn)
    coinbase_txn |> Map.put(:signature, sign)
  end

  def generate_hash(block, nonce, condition_number) do
    block = block |> Map.update?(:block_header, fn x -> x |> Map.put(:nonce, nonce) end)
    hash = Crypto.CryptoModule.hash(block)
    <<val::size(condition_number), _rest::bitstring>> = hash

    if(val == 0) do
      block |> Map.update?(:block_header, fn x -> x |> Map.put(:block_hash, hash) end)
    else
      generate_hash(block, nonce + 1, condition_number)
    end
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
        success_pid
      ) do
    coinbase_txn = generate_coinbase_transaction(10, private_key, public_key, public_key_hash)
    transactions = [coinbase_txn | transactions]
    txids = get_txids_from_transactions(transactions)
    merkle_root = calculate_merkle(txids)

    header = %Block.BlockHeader{
      previous_block_hash: previous_block_hash,
      merkle_root: merkle_root,
      timestamp: :calendar.datetime_to_gregorian_seconds(:calendar.universal_time())
    }

    block = %Block.Block{
      block_number: block_number,
      block_header: header,
      transactions: transactions
    }

    block = generate_hash(block, :rand.uniform(100_000_000), condition_number)
    GenServer.cast(success_pid, {:you_found_a_new_block, block})
  end
end
