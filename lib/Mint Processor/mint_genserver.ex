defmodule MintProcessor.MintGenServer do

  use GenServer

  def start_link() do

    uv_tx = %{}
    us_tx = %{}
    tx_map = %{}

    mint_state = %MintProcessor.Structure{unverified_transaction: uv_tx, unused_transaction: us_tx, mint_tx_map: tx_map}
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

  def verify_integrity_of_tx(curr_tx_check, other_tx_list, curr_amount, total_amount, tx_map, unused_tx_list) when other_tx_list == [] do
    flag = Map.get(unused_tx_list,curr_tx_check.txid)

    if flag == -1 do
      transaction = Map.get(tx_map, curr_tx_check.txid, nil)
      if transaction == nil do
        false
      else
        cond do
          transaction.transaction_output.pub_key_script == curr_tx_check.public_key_hash ->
            curr_amount = curr_amount + transaction.transaction_output.amount
            if curr_amount >= total_amount do
              true
            else
              false
            end

          transaction.transaction_output.sender_pub_key_script == curr_tx_check.public_key_hash ->
            curr_amount = curr_amount + transaction.transaction_output.got_back_amount
            if curr_amount >= total_amount do
              true
            else
              false
            end

          true ->
            false
        end
      end
    else
      false
    end

  end

  def verify_integrity_of_tx(curr_tx_check, other_tx_list, curr_amount, total_amount, tx_map, unused_tx_list) do
    flag = Map.get(unused_tx_list,curr_tx_check.txid)

    if flag == -1 do
      transaction = Map.get(tx_map, curr_tx_check.txid, nil)
      if transaction == nil do
        false
      else
        cond do
          transaction.transaction_output.pub_key_script == curr_tx_check.public_key_hash ->
            [head | tail] = other_tx_list
            curr_amount = curr_amount + transaction.transaction_output.amount
            verify_integrity_of_tx(head, tail, curr_amount, total_amount, tx_map, unused_tx_list)

          transaction.transaction_output.sender_pub_key_script == curr_tx_check.public_key_hash ->
            [head | tail] = other_tx_list
            curr_amount = curr_amount + transaction.transaction_output.got_back_amount
            verify_integrity_of_tx(head, tail, curr_amount, total_amount, tx_map, unused_tx_list)

          true ->
            false
        end
      end
    else
      false
    end

  end

  def handle_cast({:tx_happened, transaction},mint_state) do
    old_uv_tx = mint_state.unverified_transaction
    old_tx_map = mint_state.mint_tx_map

    #verify Transaction before adding
    sign = transaction.signature
    transaction = transaction |> Map.put(:signature, nil)

    authentic =
      Crypto.CryptoModule.verify_transaction_sign(transaction.public_key, transaction, sign)

    new_mint_state =
    if(authentic) do
      new_uv_tx = Map.put(old_uv_tx, transaction.txid, -1)
      new_tx_map = Map.put(old_tx_map, transaction.txid, transaction)

      mint_state
      |> Map.update!(:unverified_transaction, fn _x -> new_uv_tx end)
      |> Map.update!(:mint_tx_map, fn _x -> new_tx_map end)
    else
      mint_state
    end

    {:noreply,new_mint_state}
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

  def handle_call({:verify_unspent_tx,tx_input_list, amount},_from,mint_state) do
    [head | tail] = tx_input_list
    curr_amount = 0
    tx_map = mint_state.mint_tx_map
    unused_tx_list = mint_state.unused_transaction

    flag = verify_integrity_of_tx(head, tail, curr_amount, amount, tx_map, unused_tx_list)

    {:reply,flag,mint_state}
  end

  def handle_call({:get_blockchain},_from,mint_state) do
    {:reply,mint_state.mint_blockchain,mint_state}
  end
end
