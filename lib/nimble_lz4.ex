defmodule NimbleLZ4 do
  @moduledoc """
  [LZ4](https://github.com/lz4/lz4) compression and decompression.

  This functionality is built on top of native (Rust) NIFs.

  ## One-shot vs Streaming

  For small payloads that fit comfortably in memory, use the one-shot functions
  (`compress/1`, `decompress/2`, `compress_frame/1`, `decompress_frame/1`), which
  compress or decompress a whole binary at once.

  For large payloads, or data that arrives incrementally (such as a file being
  read in chunks or a network stream), use the **streaming API**. It uses the
  [LZ4 frame format](https://github.com/lz4/lz4/blob/dev/doc/lz4_Frame_format.md)
  and keeps memory usage bounded regardless of the total size of the data.

  The easiest way to use it is through `compress_stream/1` and
  `decompress_stream/1`, which turn an enumerable of `t:iodata/0` chunks into a
  lazy stream of binary chunks:

      "large_file"
      |> File.stream!(2048, [])
      |> NimbleLZ4.compress_stream()
      |> Stream.into(File.stream!("large_file.lz4"))
      |> Stream.run()

  And to decompress it back:

      "large_file.lz4"
      |> File.stream!(2048, [])
      |> NimbleLZ4.decompress_stream()
      |> Enum.into("")

  If you need finer-grained control over the lifecycle of a stream (for example,
  to interleave compression with other work), use the lower-level
  `compress_stream_new/0`, `compress_stream_update/2`, and
  `compress_stream_finish/1` functions (and their `decompress_*` counterparts).

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

  version = Mix.Project.config()[:version]

  use RustlerPrecompiled,
    otp_app: :nimble_lz4,
    crate: "nimblelz4",
    base_url: "https://github.com/whatyouhide/nimble_lz4/releases/download/v#{version}",
    force_build: System.get_env("NIMBLELZ4_FORCE_BUILD") == "true",
    version: version

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

  @doc """
  Compresses the given binary using the [LZ4 frame
  format](https://github.com/lz4/lz4/blob/dev/doc/lz4_Frame_format.md) into a frame.
  """
  @doc since: "1.1.0"
  @spec compress_frame(binary()) :: binary()
  def compress_frame(_binary) do
    :erlang.nif_error(:nif_not_loaded)
  end

  @doc """
  Decompresses the given frame binary using the [LZ4 frame
  format](https://github.com/lz4/lz4/blob/dev/doc/lz4_Frame_format.md).
  """
  @doc since: "1.1.0"
  @spec decompress_frame(binary()) :: {:ok, binary()} | {:error, term()}
  def decompress_frame(_binary) do
    :erlang.nif_error(:nif_not_loaded)
  end

  @typedoc """
  An opaque handle to a streaming compressor, created by `compress_stream_new/0`.
  """
  @typedoc since: "1.2.0"
  @opaque compressor() :: reference()

  @typedoc """
  An opaque handle to a streaming decompressor, created by
  `decompress_stream_new/0`.
  """
  @typedoc since: "1.2.0"
  @opaque decompressor() :: reference()

  @doc """
  Lazily compresses an enumerable of `t:iodata/0` chunks into a stream of
  compressed binary chunks.

  The resulting stream produces a single [LZ4
  frame](https://github.com/lz4/lz4/blob/dev/doc/lz4_Frame_format.md). Memory
  usage stays bounded regardless of the total size of the input, which makes
  this suitable for compressing large files or network streams.

  Some emitted chunks may be empty binaries: LZ4 buffers data internally and
  only emits a compressed block once it has accumulated enough input.

  ## Examples

      iex> chunks = ["hello ", "world"]
      iex> compressed = chunks |> NimbleLZ4.compress_stream() |> Enum.into("")
      iex> NimbleLZ4.decompress_frame(compressed)
      {:ok, "hello world"}

  """
  @doc since: "1.2.0"
  @spec compress_stream(Enumerable.t()) :: Enumerable.t()
  def compress_stream(enumerable) do
    Stream.transform(
      enumerable,
      fn -> compress_stream_new() end,
      fn chunk, compressor -> {[compress_stream_update(compressor, chunk)], compressor} end,
      fn compressor -> {[compress_stream_finish(compressor)], compressor} end,
      fn _compressor -> :ok end
    )
  end

  @doc """
  Lazily decompresses an enumerable of `t:iodata/0` chunks (a single LZ4 frame,
  possibly split across chunks) into a stream of decompressed binary chunks.

  This is the counterpart of `compress_stream/1`. The chunks of the input
  enumerable don't need to align with the frame's internal block boundaries: you
  can feed the frame in arbitrarily-sized pieces.

  Raises a `RuntimeError` if the data is not a valid LZ4 frame.

  ## Examples

      iex> compressed = NimbleLZ4.compress_frame("hello world")
      iex> [compressed] |> NimbleLZ4.decompress_stream() |> Enum.into("")
      "hello world"

  """
  @doc since: "1.2.0"
  @spec decompress_stream(Enumerable.t()) :: Enumerable.t()
  def decompress_stream(enumerable) do
    Stream.transform(
      enumerable,
      fn -> decompress_stream_new() end,
      fn chunk, decompressor ->
        {[unwrap_decompressed(decompress_stream_update(decompressor, chunk))], decompressor}
      end,
      fn decompressor ->
        {[unwrap_decompressed(decompress_stream_finish(decompressor))], decompressor}
      end,
      fn _decompressor -> :ok end
    )
  end

  defp unwrap_decompressed({:ok, binary}), do: binary

  defp unwrap_decompressed({:error, reason}) do
    raise "failed to decompress LZ4 stream: #{reason}"
  end

  @doc """
  Creates a new streaming compressor.

  Returns an opaque handle to be used with `compress_stream_update/2` and
  `compress_stream_finish/1`. The handle is backed by a native resource that is
  automatically cleaned up when it is garbage-collected, so it is safe to
  discard a compressor without calling `compress_stream_finish/1` (although doing
  so means the produced frame will be incomplete).

  See `compress_stream/1` for a higher-level API.
  """
  @doc since: "1.2.0"
  @spec compress_stream_new() :: compressor()
  def compress_stream_new do
    :erlang.nif_error(:nif_not_loaded)
  end

  @doc """
  Feeds a chunk of `t:iodata/0` into a streaming compressor.

  Returns a binary with the compressed data produced so far. This may be an
  empty binary if LZ4 has buffered the input internally without emitting a
  complete block yet.
  """
  @doc since: "1.2.0"
  @spec compress_stream_update(compressor(), iodata()) :: binary()
  def compress_stream_update(_compressor, _iodata) do
    :erlang.nif_error(:nif_not_loaded)
  end

  @doc """
  Finalizes a streaming compressor.

  Flushes any remaining buffered data and writes the frame's end marker,
  returning the final binary chunk. After this call the compressor must not be
  used again.
  """
  @doc since: "1.2.0"
  @spec compress_stream_finish(compressor()) :: binary()
  def compress_stream_finish(_compressor) do
    :erlang.nif_error(:nif_not_loaded)
  end

  @doc """
  Creates a new streaming decompressor.

  Returns an opaque handle to be used with `decompress_stream_update/2` and
  `decompress_stream_finish/1`. The handle is backed by a native resource that
  is automatically cleaned up when it is garbage-collected.

  See `decompress_stream/1` for a higher-level API.
  """
  @doc since: "1.2.0"
  @spec decompress_stream_new() :: decompressor()
  def decompress_stream_new do
    :erlang.nif_error(:nif_not_loaded)
  end

  @doc """
  Feeds a chunk of compressed `t:iodata/0` into a streaming decompressor.

  Returns `{:ok, binary}` with the decompressed data available so far, which may
  be an empty binary if the decompressor needs more input before it can emit the
  next block. Returns `{:error, reason}` if the data is not a valid LZ4 frame.
  """
  @doc since: "1.2.0"
  @spec decompress_stream_update(decompressor(), iodata()) ::
          {:ok, binary()} | {:error, term()}
  def decompress_stream_update(_decompressor, _iodata) do
    :erlang.nif_error(:nif_not_loaded)
  end

  @doc """
  Finalizes a streaming decompressor.

  Signals that no more input is coming and returns `{:ok, binary}` with any
  remaining decompressed data. Returns `{:error, reason}` if the frame was
  incomplete or otherwise invalid. After this call the decompressor must not be
  used again.
  """
  @doc since: "1.2.0"
  @spec decompress_stream_finish(decompressor()) :: {:ok, binary()} | {:error, term()}
  def decompress_stream_finish(_decompressor) do
    :erlang.nif_error(:nif_not_loaded)
  end
end
