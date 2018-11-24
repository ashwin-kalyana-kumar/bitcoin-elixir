defmodule MintProcessor.Structure do
  defstruct [
    :unverified_transaction,
    :unused_transaction,
    :used_transaction,
    :mint_blockchain,
    :mint_tx_map
  ]
end
