defmodule BlockChain.Block do
  @doc """
    block_header -> the header of the block
    transactions -> list of all transactions. Of type transaction.Transaction
    coinbase_transaction -> the transaction which gives bitcoins to the user,
                            who mined this block.
    added_transactions -> the transaction fee from each transaction in this block

  """
  defstruct [
    :block_number,
    :block_header,
    :transactions,
    # coinbase_transaction is to be included in the list of transactions
    # :coinbase_transaction,
    # stretch goal
    :added_transactions,
    # stretch goal
    :other
  ]

  # TODO: discuss on how to process coinbase transactions.
end
