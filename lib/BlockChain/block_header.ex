defmodule BlockChain.BlockHeader do
  @doc """
    block_hash -> the hash of the block. Hashed  using SHA
    previous_block_hash -> the hash of the previous block
    nonce -> the nonce which satisfies the condition for a block.
    merkle_root -> the root hash of the merkle tree for all the transactions
                   in this block
    timestamp -> the timestamp when the block was created and added to the chain

  """

  defstruct [
    :block_hash,
    :previous_block_hash,
    :nonce,
    :merkle_root,
    :timestamp
  ]
end
