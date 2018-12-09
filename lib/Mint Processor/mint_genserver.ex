defmodule MintProcessor.MintGenServer do
  use GenServer

  def start_link() do
    uv_tx = %{}
    us_tx = %{}
    tx_map = %{}

    mint_state = %MintProcessor.Structure{
      unverified_transaction: uv_tx,
      unused_transaction: us_tx,
      mint_tx_map: tx_map,
      mint_blockchain: %BlockChain.Chain{latest_block_number: 0, block_map: %{}}
    }

    GenServer.start_link(__MODULE__, mint_state)
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

  def check_authenticity_of_txn(transaction) do
    sign = transaction.signature
    transaction = transaction |> Map.put(:signature, nil)

    authentic =
      Crypto.CryptoModule.verify_transaction_sign(transaction.full_public_key, transaction, sign)

    cond do
      authentic -> :authentic
      true -> :invalid
    end
  end

  defp check_block_hash(block) do
    hash = block.block_header.block_hash
    block = block |> Map.put(:block_header, Map.put(block.block_header, :block_hash, nil))
    new_hash = Crypto.CryptoModule.hash_block(block)

    if(new_hash === hash) do
      true
    else
      false
    end
  end

  defp reduce_merkle([a, _b | _rest]) when a === :end do
    [:end, :end]
  end

  defp reduce_merkle([a, b | _rest]) when b === :end do
    [Crypto.CryptoModule.hash_binary(a <> a), :end, :end]
  end

  defp reduce_merkle([a, b | rest]) do
    [Crypto.CryptoModule.hash_binary(a <> b) | reduce_merkle(rest)]
  end

  defp calculate_merkle([a, b | rest]) do
    cond do
      a === :end ->
    #    IO.puts("This is not supposed to happen!")
        0

      b === :end ->
        a

      true ->
        calculate_merkle(reduce_merkle([a, b | rest]))
    end
  end

  defp get_txids_from_transactions(transactions) when transactions == [] do
    [:end, :end]
  end

  defp get_txids_from_transactions(transactions) do
    [txn | rest] = transactions
    [txn.txid | get_txids_from_transactions(rest)]
  end

  defp verify_block(prev_block_list, block) do
    invalid_txns =
      block.transactions
      |> Enum.filter(fn txn -> check_authenticity_of_txn(txn) === :invalid end)

    txids = get_txids_from_transactions(block.transactions)
    merkle = calculate_merkle(txids)
    #  IO.inspect(prev_block_list)

    prev_block =
      if(prev_block_list == nil || prev_block_list == []) do
        [1]
      else
        prev_block_list
        |> Enum.filter(fn x ->
          x.block_header.block_hash === block.block_header.previous_block_hash
        end)
      end

    block_integrity = check_block_hash(block)

    if(
      invalid_txns === [] and merkle === block.block_header.merkle_root and prev_block != [] and
        block_integrity
    ) do
      :valid
    else
      # IO.puts(
      #   "invalid block mint!! because #{invalid_txns === []} and #{
      #     merkle === block.block_header.merkle_root
      #   } and #{prev_block != []} and #{block_integrity}"
      # )

   #   IO.inspect(prev_block_list)

      :invalid
    end
  end

  defp update_maps(removed_blocks, tx_map, unused_map) when removed_blocks == [] do
    {tx_map, unused_map}
  end

  defp update_maps(removed_blocks, tx_map, unused_map) do
    [first | rest] = removed_blocks
    tx_map = tx_map |> Map.delete(hd(first.transactions).txid)
    unused_map = unused_map |> Map.delete(hd(first.transactions).txid)
    update_maps(rest, tx_map, unused_map)
  end

  defp delete_unwanted_branches(chain_map, last_block_number, tx_map, unused_map) do
    [latest_block | _rest] = chain_map |> Map.get(last_block_number)
    prev_hash = latest_block.block_header.previous_block_hash

    [prev1_block] =
      chain_map
      |> Map.get(last_block_number - 1)
      |> Enum.filter(fn x -> x.block_header.block_hash === prev_hash end)

    [prev2_block] =
      chain_map
      |> Map.get(last_block_number - 2)
      |> Enum.filter(fn x ->
        x.block_header.block_hash === prev1_block.block_header.previous_block_hash
      end)

    [prev3_block] =
      chain_map
      |> Map.get(last_block_number - 3)
      |> Enum.filter(fn x ->
        x.block_header.block_hash === prev2_block.block_header.previous_block_hash
      end)

    [prev4_block] =
      chain_map
      |> Map.get(last_block_number - 4)
      |> Enum.filter(fn x ->
        x.block_header.block_hash === prev3_block.block_header.previous_block_hash
      end)

    [prev5_block] =
      chain_map
      |> Map.get(last_block_number - 5)
      |> Enum.filter(fn x ->
        x.block_header.block_hash === prev4_block.block_header.previous_block_hash
      end)

    removed_blocks =
      chain_map
      |> Map.get(last_block_number - 5)
      |> Enum.reject(fn x ->
        x.block_header.block_hash === prev4_block.block_header.previous_block_hash
      end)

    chain_map = chain_map |> Map.put(last_block_number - 5, [prev5_block])
    {new_tx_map, new_unused_map} = update_maps(removed_blocks, tx_map, unused_map)
    {chain_map, new_tx_map, new_unused_map}
  end

  defp remove_from_unused(input, unused_map, tx_map) when input == [] or input == nil do
    {unused_map, tx_map}
  end

  defp remove_from_unused(input, unused_map, tx_map) do
    [first | rest] = input
    unused_map = unused_map |> Map.delete(first.txid)
    tx_map = tx_map |> Map.delete(first.txid)
    remove_from_unused(rest, unused_map, tx_map)
  end

  defp move_transactions(unverified_map, unused_map, tx_map, txns) when txns == [] do
    {unverified_map, unused_map, tx_map}
  end

  defp move_transactions(unverified_map, unused_map, tx_map, txns) do
    [first | rest] = txns
    input = first.transaction_input
    {unused_map, tx_map} = remove_from_unused(input, unused_map, tx_map)
    unverified_map = unverified_map |> Map.delete(first.txid)
    unused_map = unused_map |> Map.put(first.txid, -1)
    move_transactions(unverified_map, unused_map, tx_map, rest)
  end

  defp decrement_all_unspent(keys, txns) when keys == [] do
    txns
  end

  defp decrement_all_unspent(keys, txns) do
    [k | rest] = keys

    txns =
      Map.update!(txns, k, fn x ->
        if(x != -1) do
          x - 1
        else
          x
        end
      end)

    decrement_all_unspent(rest, txns)
  end

  defp update_unused(input, unused_map) when input == [] do
    unused_map
  end

  defp update_unused(input, unused_map) do
    [first | rest] = input
    unused_map = unused_map |> Map.put(first.txid, 10)
    update_unused(rest, unused_map)
  end

  defp lock_transactions(txns, unused_map) when txns == [] do
    unused_map
  end

  defp lock_transactions(txns, unused_map) do
    [first | rest] = txns
    input = first.transaction_input
    unused_map = update_unused(input, unused_map)
    lock_transactions(rest, unused_map)
  end

  defp add_block_to_chain(chain, block, tx_map, unused_map, unverified_map) do
    #    IO.puts("bn #{block.block_number}, cn #{chain.latest_block_number}")

    cond do
      block.block_number < 6 ->
        updated_map = chain.block_map |> Map.update(block.block_number, [block], &[block | &1])

        chain =
          chain
          |> Map.put(:block_map, updated_map)
          |> Map.put(:latest_block_number, block.block_number)

        new_unused_map = lock_transactions(tl(block.transactions), unused_map)

        {chain, tx_map, new_unused_map, unverified_map}

      block.block_number < chain.latest_block_number - 5 ->
        {chain, tx_map, unused_map, unverified_map}

      block.block_number <= chain.latest_block_number ->
        updated_map = chain.block_map |> Map.update(block.block_number, [block], &[block | &1])
        chain = chain |> Map.put(:block_map, updated_map)
   #     IO.puts("branching happened")
        # IO.inspect(Map.get(chain.block_map, block.block_number))
        new_unused_map = lock_transactions(tl(block.transactions), unused_map)
        {chain, tx_map, new_unused_map, unverified_map}

      block.block_number == chain.latest_block_number + 1 ->
        #        unused_map |> Map.keys() |> Enum.count() |> IO.puts()
        #            tx_map |> Map.keys() |> Enum.count() |> IO.puts()
        #            chain.block_map |> Map.keys() |> Enum.count() |> IO.puts()
        #        IO.puts ("during")
        updated_map = chain.block_map |> Map.update(block.block_number, [block], &[block | &1])

        {updated_map, new_tx_map, new_unused_map} =
          delete_unwanted_branches(updated_map, block.block_number, tx_map, unused_map)

        chain =
          chain
          |> Map.put(:block_map, updated_map)
          |> Map.put(:latest_block_number, block.block_number)

        new_unused_map = lock_transactions(tl(block.transactions), new_unused_map)

        tenth_block = chain |> Map.get(:block_map) |> Map.get(block.block_number - 10)

        if(tenth_block == nil) do
          {chain, new_tx_map, new_unused_map, unverified_map}
        else
          tenth_block = hd(tenth_block)

          {new_uv_map, new_unused_map, new_tx_map} =
            move_transactions(
              unverified_map,
              new_unused_map,
              new_tx_map,
              tl(tenth_block.transactions)
            )

          #           new_unused_map |> IO.inspect(limit: :infinity)
          #            new_tx_map |> Map.keys() |> Enum.count() |> IO.puts()
          #            chain.block_map |> Map.keys() |> Enum.count() |> IO.puts()
          # IO.puts "adding the following transaction"
          #   IO.inspect(hd(tenth_block.transactions), limit: :infinity)
          new_unused_map = new_unused_map |> Map.put(hd(tenth_block.transactions).txid, 90)
          new_unused_map = decrement_all_unspent(Map.keys(new_unused_map), new_unused_map)

          new_tx_map =
            new_tx_map |> Map.put(hd(tenth_block.transactions).txid, hd(tenth_block.transactions))

          #          new_unused_map |> Map.keys() |> Enum.count() |> IO.puts()
          #         new_tx_map |> Map.keys() |> Enum.count() |> IO.puts()
          #        chain.block_map |> Map.keys() |> Enum.count() |> IO.puts()

          #        IO.inspect(new_tx_map)
          #        IO.inspect(new_unused_map)

          {chain, new_tx_map, new_unused_map, new_uv_map}
        end

      true ->
 #       IO.puts("this should not happen!!!!!!!!!!!!!!!!!!!!!")
        {chain, tx_map, unused_map, unverified_map}
    end
  end

  defp already_got_this_block?(block, chain) do
    block_list = chain.block_map |> Map.get(block.block_number, [])

    block_list =
      block_list
      |> Enum.filter(fn x -> x.block_header.block_hash == block.block_header.block_hash end)

    block_list != []
  end

  ############################################################################

  def verify_integrity_of_tx(
        curr_tx_check,
        other_tx_list,
        curr_amount,
        total_amount,
        tx_map,
        unused_tx_list
      )
      when other_tx_list == [] do
    flag = Map.get(unused_tx_list, curr_tx_check.txid)

    if flag == -1 do
      transaction = Map.get(tx_map, curr_tx_check.txid, nil)

      if transaction == nil do
   #     IO.puts("transaction not found")
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
      #      IO.puts("flag is #{flag}")
      false
    end
  end

  def verify_integrity_of_tx(
        curr_tx_check,
        other_tx_list,
        curr_amount,
        total_amount,
        tx_map,
        unused_tx_list
      ) do
    flag = Map.get(unused_tx_list, curr_tx_check.txid)

    if flag == -1 do
      transaction = Map.get(tx_map, curr_tx_check.txid, nil)

      if transaction == nil do
    #    IO.puts("transaction not found")
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
      #     IO.puts("flllllag is #{flag}")
      false
    end
  end

  def handle_cast({:tx_happened, transaction}, mint_state) do
    old_uv_tx = mint_state.unverified_transaction
    old_tx_map = mint_state.mint_tx_map

    # verify Transaction before adding
    sign = transaction.signature
    transaction = transaction |> Map.put(:signature, nil)

    authentic =
      Crypto.CryptoModule.verify_transaction_sign(transaction.full_public_key, transaction, sign)

    new_mint_state =
      if(authentic) do
        new_uv_tx = Map.put(old_uv_tx, transaction.txid, -1)
        new_tx_map = Map.put(old_tx_map, transaction.txid, transaction)

        mint_state =
          mint_state
          |> Map.update!(:unverified_transaction, fn _x -> new_uv_tx end)
          |> Map.update!(:mint_tx_map, fn _x -> new_tx_map end)

        #        IO.puts("Tx happened")
        #        IO.inspect(transaction.txid)

        mint_state
      else
        mint_state
      end

    {:noreply, new_mint_state}
  end

  def handle_cast({:block_generated, block}, mint_state) do
    # TODO: check if you already have that block, if so ignore this message, else do the following and broadcast this message

    if(already_got_this_block?(block, mint_state.mint_blockchain)) do
      #      IO.puts("already got this block")
      {:noreply, mint_state}
    else
      valid =
        verify_block(
          Map.get(
            mint_state.mint_blockchain.block_map,
            block.block_number - 1
          ),
          block
        )

      {new_block_chain, new_tx_map, new_unused, new_unverified} =
        if(valid == :valid) do
          add_block_to_chain(
            mint_state.mint_blockchain,
            block,
            mint_state.mint_tx_map,
            mint_state.unused_transaction,
            mint_state.unverified_transaction
          )
        else
    #      IO.puts("invalid block")

          {mint_state.mint_blockchain, mint_state.mint_tx_map, mint_state.unused_transaction,
           mint_state.unverified_transaction}
        end

      mint_state =
        mint_state
        |> Map.put(:mint_blockchain, new_block_chain)
        |> Map.put(:mint_tx_map, new_tx_map)
        |> Map.put(:unused_transaction, new_unused)
        |> Map.put(:unverified_transaction, new_unverified)

      #    IO.inspect(mint_state.unused_transaction)
      #    IO.inspect(mint_state.mint_tx_map)

      {:noreply, mint_state}
    end
  end

  def handle_call({:print_bro}, _from, state) do
    a = state.unused_transaction |> Map.keys() |> Enum.count()
    b = state.unverified_transaction |> Map.keys() |> Enum.count()
    c = state.mint_tx_map |> Map.keys() |> Enum.count()
    d = state.mint_blockchain.block_map |> Map.keys() |> Enum.count()
    e = state.unused_transaction |> Map.values() |> Enum.count(fn x -> x == -1 end)

    {:reply, {a, b, c, d, e}, state}
  end

  def handle_call({:verify_unspent_tx, tx_input_list, amount}, _from, mint_state) do
    [head | tail] = tx_input_list
    curr_amount = 0
    tx_map = mint_state.mint_tx_map
    unused_tx_list = mint_state.unused_transaction

    flag = verify_integrity_of_tx(head, tail, curr_amount, amount, tx_map, unused_tx_list)

    {:reply, flag, mint_state}
  end

  def handle_call({:get_blockchain}, _from, mint_state) do
    {:reply, mint_state.mint_blockchain, mint_state}
  end
end
