# NimbleLZ4

> [LZ4][lz4] compression library for Elixir that uses Rust NIFs.

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

## Usage

You can compress and decompress data.

```elixir
iex> uncompressed = :crypto.strong_rand_bytes(10)
iex> compressed = NimbleLZ4.compress(uncomppressed)
iex> uncompressed == NimbleLZ4.decompress(compressed, _uncompressed_size = 10)
true
```

[lz4]: https://github.com/lz4/lz4
