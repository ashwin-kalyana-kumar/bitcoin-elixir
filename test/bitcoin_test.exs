defmodule BitcoinTest do
  use ExUnit.Case
  doctest Bitcoin

  test "digitally sign and verify" do
    {public, private} = Crypto.CryptoModule.get_key_pair()
    assert is_binary(public) == true
    assert is_binary(private) == true
    message = "hello world"
    signature = Crypto.CryptoModule.digital_sign(private, message)
    assert Crypto.CryptoModule.verify_sign(public, message, signature) == true
  end
end
