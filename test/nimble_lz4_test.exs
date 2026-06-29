defmodule NimbleLZ4Test do
  use ExUnit.Case, async: true
  use ExUnitProperties

  doctest NimbleLZ4

  property "compress + uncompress are circular" do
    check all binary <- binary() do
      assert {:ok, ^binary} =
               binary
               |> NimbleLZ4.compress()
               |> NimbleLZ4.decompress(byte_size(binary))
    end
  end

  property "compress + uncompress are circular with iodata as input" do
    check all iodata <- iodata() do
      assert iodata
             |> NimbleLZ4.compress()
             |> NimbleLZ4.decompress(IO.iodata_length(iodata)) ==
               {:ok, IO.iodata_to_binary(iodata)}
    end
  end

  property "compress_frame + uncompress_frame are circular" do
    check all binary <- binary() do
      assert {:ok, ^binary} =
               binary
               |> NimbleLZ4.compress_frame()
               |> NimbleLZ4.decompress_frame()
    end
  end

  property "compress_frame + uncompress_frame are circular with iodata as input" do
    check all iodata <- iodata() do
      assert iodata
             |> NimbleLZ4.compress_frame()
             |> NimbleLZ4.decompress_frame() == {:ok, IO.iodata_to_binary(iodata)}
    end
  end

  describe "compress/1" do
    test "with binaries" do
      assert NimbleLZ4.compress("foo") == "0foo"
    end

    test "with iodata" do
      assert NimbleLZ4.compress([]) == "\0"
      assert NimbleLZ4.compress([?f, [[[?o]]], "o"]) == "0foo"
    end
  end

  describe "compress_frame/1" do
    test "with binaries" do
      assert NimbleLZ4.compress_frame("foo") == "\x04\"M\x18`@\x82\x03\0\0\x80foo\0\0\0\0"
    end

    test "with iodata" do
      assert NimbleLZ4.compress_frame([]) == "\x04\"M\x18`@\x82\0\0\0\0"

      assert NimbleLZ4.compress_frame([?f, [[[?o]]], "o"]) ==
               "\x04\"M\x18`@\x82\x03\0\0\x80foo\0\0\0\0"
    end
  end

  describe "decompress/2" do
    test "with bad arguments" do
      assert_raise ArgumentError, fn -> NimbleLZ4.decompress(:banana, :apple) end
    end

    test "with the wrong uncompressed size" do
      assert {:error, message} = NimbleLZ4.decompress(NimbleLZ4.compress("foo"), 2)

      assert message ==
               "provided output is too small for the decompressed data, actual 2, expected 3"
    end
  end

  describe "decompress_frame/1" do
    test "with bad arguments" do
      assert_raise ArgumentError, fn -> NimbleLZ4.decompress_frame(:banana) end
    end

    test "decompresses correctly" do
      assert {:ok, "foo"} = NimbleLZ4.decompress_frame("\x04\"M\x18`@\x82\x03\0\0\x80foo\0\0\0\0")
    end
  end

  describe "streaming" do
    property "compress_stream + decompress_stream are circular" do
      check all chunks <- list_of(binary()) do
        original = IO.iodata_to_binary(chunks)

        roundtripped =
          chunks
          |> NimbleLZ4.compress_stream()
          |> NimbleLZ4.decompress_stream()
          |> Enum.into("")

        assert roundtripped == original
      end
    end

    property "streamed compression is readable by the one-shot frame decompressor" do
      check all chunks <- list_of(binary()) do
        original = IO.iodata_to_binary(chunks)

        compressed =
          chunks
          |> NimbleLZ4.compress_stream()
          |> Enum.into("")

        assert {:ok, ^original} = NimbleLZ4.decompress_frame(compressed)
      end
    end

    property "one-shot compressed frame is readable by the streaming decompressor" do
      check all binary <- binary(), chunk_size <- integer(1..32) do
        compressed = NimbleLZ4.compress_frame(binary)

        decompressed =
          compressed
          |> chunk_binary(chunk_size)
          |> NimbleLZ4.decompress_stream()
          |> Enum.into("")

        assert decompressed == binary
      end
    end

    test "round-trips a large payload spanning many frame blocks" do
      original = :crypto.strong_rand_bytes(5_000_000)

      roundtripped =
        original
        |> chunk_binary(4096)
        |> NimbleLZ4.compress_stream()
        |> NimbleLZ4.decompress_stream()
        |> Enum.into("")

      assert roundtripped == original
    end

    test "compress_stream/1 accepts iodata chunks" do
      compressed =
        [[?f], "o", [[?o]]]
        |> NimbleLZ4.compress_stream()
        |> Enum.into("")

      assert {:ok, "foo"} = NimbleLZ4.decompress_frame(compressed)
    end

    test "low-level compressor API works across many updates" do
      compressor = NimbleLZ4.compress_stream_new()

      compressed =
        for i <- 1..1000, into: "" do
          NimbleLZ4.compress_stream_update(compressor, "chunk #{i} ")
        end

      compressed = compressed <> NimbleLZ4.compress_stream_finish(compressor)

      expected = for i <- 1..1000, into: "", do: "chunk #{i} "
      assert {:ok, ^expected} = NimbleLZ4.decompress_frame(compressed)
    end

    test "low-level decompressor API works across many updates" do
      expected = for i <- 1..1000, into: "", do: "chunk #{i} "
      compressed = NimbleLZ4.compress_frame(expected)

      decompressor = NimbleLZ4.decompress_stream_new()

      decompressed =
        compressed
        |> chunk_binary(7)
        |> Enum.reduce("", fn chunk, acc ->
          assert {:ok, data} = NimbleLZ4.decompress_stream_update(decompressor, chunk)
          acc <> data
        end)

      assert {:ok, tail} = NimbleLZ4.decompress_stream_finish(decompressor)
      assert decompressed <> tail == expected
    end

    test "decompress_stream/1 raises on invalid data" do
      assert_raise RuntimeError, ~r/failed to decompress LZ4 stream/, fn ->
        ["not a valid lz4 frame at all"]
        |> NimbleLZ4.decompress_stream()
        |> Enum.into("")
      end
    end

    test "decompress_stream_finish/1 returns an error on a truncated frame" do
      compressed = NimbleLZ4.compress_frame(:crypto.strong_rand_bytes(10_000))
      truncated = binary_part(compressed, 0, div(byte_size(compressed), 2))

      decompressor = NimbleLZ4.decompress_stream_new()
      assert {:ok, _} = NimbleLZ4.decompress_stream_update(decompressor, truncated)
      assert {:error, _reason} = NimbleLZ4.decompress_stream_finish(decompressor)
    end
  end

  defp chunk_binary(binary, _size) when byte_size(binary) == 0, do: []

  defp chunk_binary(binary, size) when byte_size(binary) <= size, do: [binary]

  defp chunk_binary(binary, size) do
    <<chunk::binary-size(^size), rest::binary>> = binary
    [chunk | chunk_binary(rest, size)]
  end
end
