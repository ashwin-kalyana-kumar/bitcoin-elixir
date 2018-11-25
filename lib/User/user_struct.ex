defmodule User.UserStruct do
  @doc """
  wallet -> the wallet of the user. of type User.Wallet
  neighbors -> List of pids, which are neighbors of the current process
  :incoming_txns -> list of incoming transactions, for which the block has to be designed
  """
  defstruct [
    :id,
    :wallet,
    :neighbors,
    :incoming_txns,
    :spawned_process,
    :block_chain,
    :miner
  ]
end
