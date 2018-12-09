defmodule Bitcoin do
  @moduledoc """
  Documentation for Bitcoin.
  """

  def wait_indef() do
    receive do
      :hello -> nil
    after
      200_000 ->
        {:ok}
    end
  end

  def wait_indef2() do
    receive do
      :hello -> nil
    after
      10_000 ->
        {:ok}
    end
  end

  def wait_indef3() do
    receive do
      :hello -> nil
    after
      30_000 ->
        :ok
    end
  end

  def keep_requesting(_pid, num, _list) when num == 0 do
    nil
  end

  def keep_requesting(pid, num, list) do
    {_, req_pid, _, _} = Enum.random(list)
    GenServer.cast(pid, {:request_bitcoin, req_pid, 5})

    keep_requesting(pid, num - 1, list)
  end

  def start_node_mining(spec_list, _m_pid) when spec_list == [] do
    nil
  end

  def start_node_mining(spec_list, m_pid) do
    [{_, pid, _, _} | rest] = spec_list
    GenServer.cast(pid, {:start_mining, m_pid})
    start_node_mining(rest, m_pid)
  end

  def inin() do
    MintProcessor.MintSupervisor.start_link(nil)
    {_, mint_pid} = MintProcessor.MintSupervisor.start_child()
    User.BitcoinSupervisor.start_link(nil)
    User.BitcoinSupervisor.start_child(15, mint_pid, 15, %{})
    spec_list = DynamicSupervisor.which_children(:user_super)
    IO.inspect(spec_list)
    start_node_mining(spec_list, mint_pid)
    wait_indef()
    GenServer.call(mint_pid, {:print_bro}) |> IO.inspect(limit: :infinity)
    child_pid = User.BitcoinSupervisor.add_new_node(mint_pid)

    keep_requesting(child_pid, 5, spec_list)
    wait_indef2()

    GenServer.call(child_pid,{:print_wallet}) |> IO.inspect(limit: :infinity)
    GenServer.call(mint_pid, {:print_bro}) |> IO.inspect(limit: :infinity)
    keep_requesting(child_pid, 5, spec_list)
    wait_indef2()
    GenServer.call(child_pid,{:print_wallet}) |> IO.inspect(limit: :infinity)
    GenServer.call(mint_pid, {:print_bro}) |> IO.inspect(limit: :infinity)
    keep_requesting(child_pid, 5, spec_list)
    wait_indef2()
    GenServer.call(child_pid,{:print_wallet}) |> IO.inspect(limit: :infinity)
    GenServer.call(mint_pid, {:print_bro}) |> IO.inspect(limit: :infinity)
    GenServer.call(child_pid,{:print_wallet}) |> IO.inspect(limit: :infinity)
    keep_requesting(child_pid, 5, spec_list)
    wait_indef3()

  end
end
