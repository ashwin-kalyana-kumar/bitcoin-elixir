defmodule Crypto.CryptoModule do
  @moduledoc """
    The crypto module for the bitcoin algorithm. This module takes care
    of all the crypto operations. Uses EC Diffie Hellman, SHA-256 and EC DSA.
    Uses P160R1 Brainpool Elliptic curve for all operations.
  """

  defp get_input_txn_bitstr(nil) do
    ""
  end

  defp get_input_txn_bitstr([first | rest]) when rest == [] do
    first.txid <> first.public_key_hash
  end

  defp get_input_txn_bitstr([first | rest]) do
    first.txid <> first.public_key_hash <> get_input_txn_bitstr(rest)
  end

  defp get_output_txn_bitstr(output) do
    out = :binary.encode_unsigned(output.amount) <> output.pub_key_script

    out1 =
      if(output.got_back_amount == nil) do
        out
      else
        out <> :binary.encode_unsigned(output.got_back_amount)
      end

    out2 =
      if(output.sender_pub_key_script == nil) do
        out1
      else
        out1 <> output.sender_pub_key_script
      end

    out2
  end

  defp get_transaction_binary(transaction) do
    :binary.encode_unsigned(transaction.unique_id) <>
      transaction.full_public_key <>
      get_input_txn_bitstr(transaction.transaction_input) <>
      get_output_txn_bitstr(transaction.transaction_output)
  end

  defp get_transaction_binaries_of_block([first | rest]) when rest == [] do
    get_transaction_binary(first)
  end

  defp get_transaction_binaries_of_block([first | rest]) do
    get_transaction_binary(first) <> get_transaction_binaries_of_block(rest)
  end

  defp get_block_binary(block) do
    :binary.encode_unsigned(block.block_number) <>
      if(block.block_header.previous_block_hash == nil) do
        ""
      else
        block.block_header.previous_block_hash
      end <>
      :binary.encode_unsigned(block.block_header.nonce) <>
      block.block_header.merkle_root <>
      :binary.encode_unsigned(block.block_header.timestamp) <>
      get_transaction_binaries_of_block(block.transactions)
  end

  def get_key_pair() do
    # {public_key, private_key}
    :crypto.generate_key(:ecdh, :brainpoolP512r1)
  end

  def hash_transaction(transaction) do
    hash(get_transaction_binary(transaction))
  end

  def hash_block(block) do
    hash(get_block_binary(block))
  end

  def hash_key(key) do
    hash(key)
  end

  def hash_binary(value) do
    hash(value)
  end

  defp hash(data) do
    # digest
    :crypto.hash(:sha512, data)
  end

  def sign_transaction(key, transaction) do
    message = transaction.txid <> get_transaction_binary(transaction)
    #    IO.puts("signed message")
    #    IO.inspect(message, limit: :infinity)
    digital_sign(key, message)
  end

  def sign_message(key, message) do
    digital_sign(key, message)
  end

  defp digital_sign(key, message) do
    # signature
    signature = :crypto.sign(:ecdsa, :sha512, message, [key, :brainpoolP512r1])
    #  IO.puts("signing private")
    #  IO.inspect(key, limit: :infinity)
    signature
  end

  def verify_message(key, message, sign) do
    verify_sign(key, message, sign)
  end

  def verify_transaction_sign(key, transaction, sign) do
    message = transaction.txid <> get_transaction_binary(transaction)
    #    IO.puts("verifying message")
    #    IO.inspect(message, limit: :infinity)
    #    IO.puts("verifying   public!")
    #    IO.inspect(key, limit: :infinity)

    verify_sign(key, message, sign)
  end

  defp verify_sign(key, message, sign) do
    # result
    result = :crypto.verify(:ecdsa, :sha512, message, sign, [key, :brainpoolP512r1])
    ##    IO.inspect(result)
    result
  end
end
