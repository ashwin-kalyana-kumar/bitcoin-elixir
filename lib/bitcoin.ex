defmodule Bitcoin do
  @moduledoc """
  Documentation for Bitcoin.
  """

  defp wait_indef() do
    receive do
      :hello -> nil
    end
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
    User.BitcoinSupervisor.start_child(100, mint_pid, 100, %{})
    spec_list = DynamicSupervisor.which_children(:user_super)
    IO.inspect(spec_list)
    start_node_mining(spec_list)
    wait_indef()
  end
end
