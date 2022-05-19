defmodule NimbleLZ4 do
  @moduledoc """
  TODO
  """

  use Rustler, otp_app: :nimble_lz4, crate: "nimblelz4"

  @spec compress(binary()) :: binary()
  def compress(_binary) do
    :erlang.nif_error(:nif_not_loaded)
  end

  @spec decompress(binary(), non_neg_integer()) :: {:ok, binary()} | {:error, term()}
  def decompress(_binary, _uncompressed_size) do
    :erlang.nif_error(:nif_not_loaded)
  end
end
