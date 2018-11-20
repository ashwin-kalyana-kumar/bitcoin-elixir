defmodule User.NeighborStruct do
  @doc """
  the structure for the network in which the nodes are arranged. They are done
  in a closed imperfect loop, where each node has a left and a right neighbor
  and another random neighbor
  """
  defstruct [
    :left_guy,
    :right_guy,
    :random_guy
  ]
end
