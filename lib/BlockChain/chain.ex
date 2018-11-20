defmodule BlockChain.Chain do
  @doc """
  the latest block number is the number of the latest block that has
  been generated.
  The block_map is a map with keys being the block number and the value being the
  block. Older blocks(1500 block older ones) will be deleted from the memory and
  only the header will be stored.
  """

  defstruct [
    :latest_block_number,
    :block_map
  ]
end
