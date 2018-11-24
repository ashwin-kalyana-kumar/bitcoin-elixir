defmodule MintProcessor.MintSupervisor do

  use DynamicSupervisor

  def start_link() do
    DynamicSupervisor.start_link(strategy: :one_for_one, name: :mint_super)
  end

  def start_child() do
    spec = %{id: 1, restart: :temporary, start: {MintProcessor.MintGenServer, :start_link, []}}
    {:ok, _child} = DynamicSupervisor.start_child(:mint_super, spec)
  end

  # def function_check() do
  #   IO.puts("Hi")
  #   a = DynamicSupervisor.which_children(:mint_super)
  #   IO.inspect(a)
  # end

end
