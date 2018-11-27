defmodule BitcoinTest do
  use ExUnit.Case
  doctest Bitcoin

  test "public and private key generation" do
    {public, private} = Crypto.CryptoModule.get_key_pair()
    assert is_binary(public) == true
    assert is_binary(private) == true
  end

  test "digitally sign and verify" do
    {public, private} = Crypto.CryptoModule.get_key_pair()
    assert is_binary(public) == true
    assert is_binary(private) == true
    message = "hello world!"
    signature = Crypto.CryptoModule.sign_message(private, message)
    assert Crypto.CryptoModule.verify_message(public, message, signature) == true
  end

  test "create and verify transaction" do
    {public, private} = Crypto.CryptoModule.get_key_pair()
    {public1, private1} = Crypto.CryptoModule.get_key_pair()
    pubkey_hash = Crypto.CryptoModule.hash_key(public)
    pubkey_hash1 = Crypto.CryptoModule.hash_key(public1)

    input_txn1 =
      User.BlockGenerator.generate_coinbase_transaction(50, private, public, pubkey_hash)

    transaction =
      User.BitcoinUser.build_transaction(
        [input_txn1],
        20,
        pubkey_hash1,
        30,
        pubkey_hash,
        public,
        private
      )

    assert User.BitcoinUser.check_authenticity_of_txn(transaction) == :authentic
  end

  test "create and verify block" do
    {public, private} = Crypto.CryptoModule.get_key_pair()
    public_key_hash = Crypto.CryptoModule.hash_key(public)

    block =
      User.BlockGenerator.generate_next_block(
        1,
        [],
        50,
        nil,
        public,
        private,
        public_key_hash,
        10,
        nil,
        nil,
        nil
      )

    assert(User.BitcoinUser.verify_block([], block) == :valid)
  end

  test "create and verify block with transaction" do
    {public, private} = Crypto.CryptoModule.get_key_pair()
    {public1, private1} = Crypto.CryptoModule.get_key_pair()
    pubkey_hash = Crypto.CryptoModule.hash_key(public)
    pubkey_hash1 = Crypto.CryptoModule.hash_key(public1)

    input_txn1 =
      User.BlockGenerator.generate_coinbase_transaction(50, private, public, pubkey_hash)

    transaction =
      User.BitcoinUser.build_transaction(
        [input_txn1],
        20,
        pubkey_hash1,
        30,
        pubkey_hash,
        public,
        private
      )

    assert User.BitcoinUser.check_authenticity_of_txn(transaction) == :authentic

    block =
      User.BlockGenerator.generate_next_block(
        1,
        [transaction],
        50,
        nil,
        public,
        private,
        pubkey_hash,
        10,
        nil,
        nil,
        nil
      )

    assert(User.BitcoinUser.verify_block([], block) == :valid)
  end

  test "entire thing" do
    MintProcessor.MintSupervisor.start_link(nil)
    {_, mint_pid} = MintProcessor.MintSupervisor.start_child()
    User.BitcoinSupervisor.start_link(nil)
    User.BitcoinSupervisor.start_child(15, mint_pid, 15, %{})
    spec_list = DynamicSupervisor.which_children(:user_super)
    IO.inspect(spec_list)
    Bitcoin.start_node_mining(spec_list, mint_pid)
    Bitcoin.wait_indef()
    {unused_txn, unv_txn, all_txn, chain, spendable} = GenServer.call(mint_pid, {:print_bro})
    child_pid = User.BitcoinSupervisor.add_new_node(mint_pid)

    Bitcoin.keep_requesting(child_pid, 5, spec_list)
    Bitcoin.wait_indef2()

    balance = GenServer.call(child_pid, {:print_wallet})
    assert balance == 25
    {unused_txn, unv_txn, all_txn, chain, spendable} = GenServer.call(mint_pid, {:print_bro})
    assert spendable < unused_txn
    assert unv_txn == 0
    assert unused_txn < chain

    Bitcoin.keep_requesting(child_pid, 5, spec_list)
    Bitcoin.wait_indef2()
    balance = GenServer.call(child_pid, {:print_wallet})
    assert balance == 50
    {unused_txn, unv_txn, all_txn, chain, spendable} = GenServer.call(mint_pid, {:print_bro})
    assert spendable < unused_txn
    assert unv_txn == 0
    assert unused_txn < chain
    Bitcoin.keep_requesting(child_pid, 5, spec_list)
    Bitcoin.wait_indef2()
    balance = GenServer.call(child_pid, {:print_wallet})
    assert balance == 75
    {unused_txn, unv_txn, all_txn, chain, spendable} = GenServer.call(mint_pid, {:print_bro})
    assert spendable < unused_txn
    assert unv_txn == 0
    assert unused_txn < chain
    balance = GenServer.call(child_pid, {:print_wallet})
    assert balance == 75
    Bitcoin.keep_requesting(child_pid, 5, spec_list)
    Bitcoin.wait_indef3()
    {unused_txn, unv_txn, all_txn, chain, spendable} = GenServer.call(mint_pid, {:print_bro})
    assert spendable < unused_txn
    assert unv_txn == 0
    assert unused_txn < chain
    balance = GenServer.call(child_pid, {:print_wallet})
    assert balance == 100
  end
end
