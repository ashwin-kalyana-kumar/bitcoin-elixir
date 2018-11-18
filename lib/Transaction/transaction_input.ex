defmodule Transaction.TransactionInput do
  @doc """
    txid -> the txid from the transaction which is being provided as input.
    public_key_hash -> the public_key_hash of the block from the previous transaction
                       which will be compared to the hash generated when verifying
                       the signature.
  """

  defstruct [
    :txid,
    :public_key_hash
  ]
end
