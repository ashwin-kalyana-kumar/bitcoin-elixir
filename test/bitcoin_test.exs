defmodule BitcoinTest do
  use ExUnit.Case
  doctest Bitcoin

  """
  test "digitally sign and verify" do
    {public, private} = Crypto.CryptoModule.get_key_pair()
    assert is_binary(public) == true
    assert is_binary(private) == true
    message = %{a1: "a", a2: "b"}
    signature = Crypto.CryptoModule.digital_sign(private, message)
    assert Crypto.CryptoModule.verify_sign(public, message, signature) == true
  end

  """

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
end
