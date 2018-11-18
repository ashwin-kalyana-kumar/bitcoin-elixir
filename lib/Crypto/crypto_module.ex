defmodule Crypto.CryptoModule do
  @moduledoc """
    The crypto module for the bitcoin algorithm. This module takes care
    of all the crypto operations. Uses EC Diffie Hellman, SHA-256 and EC DSA.
    Uses P160R1 Brainpool Elliptic curve for all operations.
  """

  def get_key_pair() do
    {public_key, private_key} = :crypto.generate_key(:ecdh, :brainpoolP160r1)
  end

  def hash(data) do
    digest = :crypto.hash(:sha256, data)
  end

  def digital_sign(key, message) do
    signature = :crypto.sign(:ecdsa, :sha256, message, [key, :brainpoolP160r1])
  end

  def verify_sign(key, message, sign) do
    result = :crypto.verify(:ecdsa, :sha256, message, sign, [key, :brainpoolP160r1])
  end
end
