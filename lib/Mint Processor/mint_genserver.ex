defmodule MintProcessor.MintGenServer do

  use GenServer

  def start_link() do

    uv_tx = %{}
    us_tx = %{}
    used_tx = []

    mint_state = %MintProcessor.Structure{unverified_transaction: uv_tx, unused_transaction: us_tx, used_transaction: used_tx}
    GenServer.start_link(__MODULE__,mint_state)
  end

  def init(mint_state) do
    {:ok, mint_state}
  end

  def update_uvtx_used_tx(_tx_remove, tx_list_remove, uv_tx) when tx_list_remove == [] do
    uv_tx
  end

  def update_uvtx_used_tx(tx_remove, tx_list_remove, uv_tx) do

    update_uv_tx = Map.delete(uv_tx, tx_remove)

    [head | tail] = tx_list_remove
    update_uvtx_used_tx(head, tail, update_uv_tx)
  end

  def handle_cast({:tx_happened, tx_id},mint_state) do
    # the whole transaction
    old_uv_tx = mint_state.unverified_transaction

    # Verify Signature

    new_uv_tx = Map.put_new(old_uv_tx, tx_id, -1)

    mint_state = mint_state |>
                  Map.update!(:unverified_transaction, fn _x -> new_uv_tx end)

    {:noreply,mint_state}
  end

  def handle_cast({:block_generated, tx_used_list, _block}, mint_state) do
    old_used_list = mint_state.used_transaction
    old_uv_tx = mint_state.unverified_transaction
    #old_blockchain = mint_state.mint_blockchain
    # first coinbase tx add in UV
    new_used_list = tx_used_list + old_used_list

    [head | tail] = tx_used_list
    updated_uv_tx = update_uvtx_used_tx(head, tail, old_uv_tx)

    #update_blockchain =

    new_mint_state = mint_state
                  |> Map.update!(:used_transaction, fn _x -> new_used_list end)
                  |> Map.update!(:unverified_transaction, fn _x -> updated_uv_tx end)
                  #|> Map.update!(:mint_blockchain, fn _x -> update_blockchain end)
    {:noreply,new_mint_state}
  end

  def handle_call({:verify_unspent_tx,unspent_tx_list, amount, pb_key_script},_from,mint_state) do

    # tru false return
  end

  def handle_call({:get_blockchain},_from,mint_state) do
    {:reply,mint_state.mint_blockchain,mint_state}
  end
end
