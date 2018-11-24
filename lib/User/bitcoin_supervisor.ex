defmodule User.Supervisor do

  use DynamicSupervisor

  def start_link() do
    DynamicSupervisor.start_link(strategy: :one_for_one, name: :user_super)
  end

  def start_child(n,m_pid,total_node) when n == 1 do
    neighbour = %User.NeighborStruct{left_guy: total_node,right_guy: n+1,random_guy: :rand.uniform(total_node)}
    spec = %{id: 1, restart: :temporary, start: {User.BitcoinUser, :start_link, [n,m_pid,neighbour,#how to add blockchain]}}
    {:ok, _child} = DynamicSupervisor.start_child(:user_super, spec)
  end

  def start_child(n,m_pid,total_node) do
    if n == 100 do
      neighbour = %User.NeighborStruct{left_guy: n-1,right_guy: 1,random_guy: :rand.uniform(total_node)}
    else
      neighbour = %User.NeighborStruct{left_guy: n-1,right_guy: n+1,random_guy: :rand.uniform(total_node)}
    end
    spec = %{id: n, restart: :temporary, start: {User.BitcoinUser, :start_link, [n,m_pid,neighbour,#how to add blockchain]}}
    {:ok, _child} = DynamicSupervisor.start_child(:user_super, spec)
    start_child(n-1,m_pid,total_node)
  end

  def add_new_node() do
    total_children = count_children(user_super)
    node_to_add = :random.uniform(total_children)
    cond do
      node_to_add == 1 -> # add
      node_to_add == 100 -> #add
      tru -> #add
    else

    end
  end


end
