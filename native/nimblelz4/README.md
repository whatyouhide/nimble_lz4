# NIF for Elixir.NimbleLZ4

## To build the NIF module:

- Your NIF will now build along with your project.

## To load the NIF:

```elixir
defmodule NimbleLZ4 do
    use Rustler, otp_app: :nimble_lz4, crate: "nimblelz4"

    # When your NIF is loaded, it will override this function.
    def add(_a, _b), do: :erlang.nif_error(:nif_not_loaded)
end
```

## Examples

[This](https://github.com/hansihe/NifIo) is a complete example of a NIF written in Rust.
