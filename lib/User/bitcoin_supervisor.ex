defmodule User.BitcoinSupervisor do

  use DynamicSupervisor

  def start_link() do
    DynamicSupervisor.start_link(strategy: :one_for_one, name: :user_super)
  end

  def update_intial_neighbours(node_map) do
    list = DynamicSupervisor.which_children(:user_super)

    list
    |> Enum.each(fn item ->
      {_,pid,_,_} = item
      GenServer.cast(pid,{:update_neighbors,node_map})
      end)
  end

  def start_child(n,m_pid,total_node,node_map) when n == 1 do
    blockchain = GenServer.call(m_pid,{:get_blockchain})
    neighbour = %User.NeighborStruct{left_guy: total_node,right_guy: n+1,random_guy: :rand.uniform(total_node)}
    spec = %{id: 1, restart: :temporary, start: {User.BitcoinUser, :start_link, [n,m_pid,neighbour,blockchain]}}
    {:ok, child} = DynamicSupervisor.start_child(:user_super, spec)
    update_node_map = Map.put_new(node_map, n, child)
    spawn(fn -> update_intial_neighbours(update_node_map) end)
  end

  def start_child(n,m_pid,total_node,node_map) do
    blockchain = GenServer.call(m_pid,{:get_blockchain})
    neighbour =
    if n == 100 do
      %User.NeighborStruct{left_guy: n-1,right_guy: 1,random_guy: :rand.uniform(total_node)}
    else
      %User.NeighborStruct{left_guy: n-1,right_guy: n+1,random_guy: :rand.uniform(total_node)}
    end
    spec = %{id: n, restart: :temporary, start: {User.BitcoinUser, :start_link, [n,m_pid,neighbour,blockchain]}}
    {:ok, child} = DynamicSupervisor.start_child(:user_super, spec)
    update_node_map = Map.put_new(node_map, n, child)
    start_child(n-1,m_pid,total_node,update_node_map)
  end

  def add_new_node(m_pid) do
    total_children = DynamicSupervisor.count_children(:user_super)
    {_,node_to_add,_,_} = Enum.random(total_children)
    {_,random_neighbour,_,_} = Enum.random(total_children)
    node_to_add_neighbours = Genserver.call(node_to_add,{:get_neighbours})
    neighbour =  %User.NeighborStruct{left_guy: node_to_add, right_guy: node_to_add_neighbours.right_guy, random_guy: random_neighbour}
    blockchain = GenServer.call(m_pid,{:get_blockchain})
    spec = %{id: total_children+1, restart: :temporary, start: {User.BitcoinUser, :start_link, [total_children+1,m_pid,neighbour,blockchain]}}
    {:ok, child} = DynamicSupervisor.start_child(:user_super, spec)
    GenServer.cast(node_to_add,{:update_neighbours_dueto_new_node,{:right_negh,child}})
    GenServer.cast(node_to_add_neighbours.right_guy,{:update_neighbours_dueto_new_node,{:left_negh,child}})
  end
end
