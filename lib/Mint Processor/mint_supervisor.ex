defmodule MintProcessor.MintSupervisor do
  use DynamicSupervisor

  def start_link(arg) do
    DynamicSupervisor.start_link(__MODULE__, arg, name: :mint_super)
  end

  def init(_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_child() do
    spec = %{id: 1, restart: :temporary, start: {MintProcessor.MintGenServer, :start_link, []}}
    DynamicSupervisor.start_child(:mint_super, spec)
  end

  # def function_check() do
  #   IO.puts("Hi")
  #   a = DynamicSupervisor.which_children(:mint_super)
  #   IO.inspect(a)
  # end
end


