# NimbleLZ4 🗜️

> [LZ4] compression library for Elixir that uses Rust NIFs.

## Installation

Add this to your dependencies in `mix.exs`.

```elixir
defp deps do
  [
    # ...,
    {:nimble_lz4, "~> 0.1.0"}
  ]
end
```

NimbleLZ4 requires OTP 23+ and Elixir 1.11+.

### Native Code

NimbleLZ4 uses [RustlerPrecompiled] to build precompiled version of the
necessary Rust NIFs bindings for a variety of platforms, NIF versions, and
operating systems. RustlerPrecompiled should automatically download the correct
version of the bindings when compiling NimbleLZ4 as a dependency of your
application.

You can **force compilation** of the native code by setting the
`NIMBLELZ4_FORCE_BUILD` environment variable to `true`:

```shell
NIMBLELZ4_FORCE_BUILD=true mix deps.compile
```

## Usage

You can compress and decompress data.

[Block format](https://github.com/lz4/lz4/blob/dev/doc/lz4_Block_format.md):

```elixir
iex> uncompressed = :crypto.strong_rand_bytes(10)
iex> compressed = NimbleLZ4.compress(uncompressed)
iex> {:ok, ^uncompressed} = NimbleLZ4.decompress(compressed, _uncompressed_size = 10)
true
```

[Frame format](https://github.com/lz4/lz4/blob/dev/doc/lz4_Frame_format.md) ([self-contained](https://android.googlesource.com/platform/external/lz4/+/HEAD/doc/lz4_Block_format.md#metadata)):

```elixir
iex> uncompressed = :crypto.strong_rand_bytes(10_000)
iex> compressed = NimbleLZ4.compress_frame(uncompressed)
iex> {:ok, ^uncompressed} = NimbleLZ4.decompress_frame(compressed)
true
```

### Streaming

For large payloads or data that arrives incrementally, you can compress and
decompress lazily without holding everything in memory. `compress_stream/1` and
`decompress_stream/1` turn an enumerable of `iodata` chunks into a lazy stream of
binary chunks (using the LZ4 frame format):

```elixir
# Compress a large file chunk-by-chunk.
"large_file"
|> File.stream!(2048, [])
|> NimbleLZ4.compress_stream()
|> Stream.into(File.stream!("large_file.lz4"))
|> Stream.run()

# And decompress it back.
"large_file.lz4"
|> File.stream!(2048, [])
|> NimbleLZ4.decompress_stream()
|> Enum.into("")
```

There's also a lower-level resource-based API
(`compress_stream_new/0`, `compress_stream_update/2`, `compress_stream_finish/1`
and their `decompress_*` counterparts) for finer-grained control.

[LZ4]: https://github.com/lz4/lz4
[RustlerPrecompiled]: https://github.com/philss/rustler_precompiled
