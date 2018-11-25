defmodule Bitcoin do
  @moduledoc """
  Documentation for Bitcoin.
  """

  defp wait_indef() do
    receive do
      :hello -> nil
    after
      5_000 ->
        IO.puts("starting new guy")
    end
  end

  defp keep_requesting(_pid, num, _list) when num == [] do
    nil
  end

  defp keep_requesting(pid, num, list) do
    {_, req_pid, _, _} = Enum.random(list)
    GenServer.cast(pid, {:request_bitcoin, req_pid, 5})
    keep_requesting(pid, num - 1, list)
  end

  defp start_node_mining(spec_list) when spec_list == [] do
    nil
  end

  defp start_node_mining(spec_list) do
    [{_, pid, _, _} | rest] = spec_list
    GenServer.cast(pid, {:start_mining})
    start_node_mining(rest)
  end

  def initiate_bitcoin() do
    MintProcessor.MintSupervisor.start_link(nil)
    {_, mint_pid} = MintProcessor.MintSupervisor.start_child()
    User.BitcoinSupervisor.start_link(nil)
    User.BitcoinSupervisor.start_child(25, mint_pid, 25, %{})
    spec_list = DynamicSupervisor.which_children(:user_super)
    IO.inspect(spec_list)
    start_node_mining(spec_list)
    wait_indef()
    GenServer.cast(mint_pid, {:print_bro})
    # child_pid = User.BitcoinSupervisor.add_new_node(mint_pid)

    #    keep_requesting(child_pid, 250, spec_list)
    wait_indef()
    GenServer.cast(mint_pid, {:print_bro})

    wait_indef()
    GenServer.cast(mint_pid, {:print_bro})

    wait_indef()
    GenServer.cast(mint_pid, {:print_bro})

    wait_indef()
    GenServer.cast(mint_pid, {:print_bro})

    wait_indef()
  end
end
