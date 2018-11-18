defmodule Transaction.TransactionOutput do
  @doc """
  amount -> the amount of bitcoin sent in this transaction
  pub_key_script -> A random number which when appened to the sender's public
                    key and hashed using SHA 256 will help verify the public_key_hash
                    from the previous transaction(which is the input to the
                    current transaction).
  """
  defstruct [
    :amount,
    :pub_key_script,
    :got_back_amount,
    :sender_pub_key_script
  ]
end
