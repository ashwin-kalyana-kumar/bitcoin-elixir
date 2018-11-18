defmodule User.Wallet do
  defstruct [
    :private_key,
    :public_key,
    :pubkey_hash_script,
    :pubkey_hashes,
    :balance,
    :unused_transactions,
    :mint_master_pid
  ]
end
