defmodule NimbleLZ4 do
  @moduledoc """
  [LZ4](https://github.com/lz4/lz4) compression and decompression.

  This functionality is built on top of native (Rust) NIFs. There is no
  streaming functionality, everything is done in memory.

  ## Uncompressed Size

  `decompress/2` takes the original uncompressed size as a parameter. For this
  reason, it's common to store compressed binaries *prefixed by their uncompressed
  length*. For example, you could store the compressed binary as:

      my_binary = <<...>>
      store(<<byte_size(my_binary)::32>> <> NimbleLZ4.compress(my_binary))

  When decompressing, you can extract the uncompressed length:

      <<uncompressed_size::32, compressed_binary::binary>> = retrieve_binary()
      uncompressed_binary = NimbleLZ4.decompress(compressed_binary, uncompressed_size)

  """

  use Rustler, otp_app: :nimble_lz4, crate: "nimblelz4"

  @doc """
  Compresses the given binary.
  """
  @doc since: "0.1.0"
  @spec compress(binary()) :: binary()
  def compress(_binary) do
    :erlang.nif_error(:nif_not_loaded)
  end

  @doc """
  Decompresses the given binary using the size of the uncompressed binary.
  """
  @spec decompress(binary(), non_neg_integer()) :: {:ok, binary()} | {:error, term()}
  def decompress(_binary, _uncompressed_size) do
    :erlang.nif_error(:nif_not_loaded)
  end
end
