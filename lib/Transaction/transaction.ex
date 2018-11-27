defmodule Transaction.Transaction do
  @doc """
    txid -> the transaction ID of the current transaction. This is calculated
            by hashing the entire transaction using SHA
    transaction_output -> the output block of the transaction. of type list of TransactionOutput
    transaction_input -> the input block of the transaction. of type list of TransactionInput
    full_public_key -> the full public key of the sender
    signature -> The signature of the sender. This includes txid, list of
                 all block_input (as individual key-value pairs), list of pub_key_scripts,
                 amounts from all block_output all hashed using the private_key
                 of the sender of this transaction.
  """
  defstruct [
    :txid,
    :unique_id,
    :full_public_key,
    :transaction_output,
    :transaction_input,
    :signature
  ]
end
