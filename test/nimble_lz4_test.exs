defmodule NimbleLZ4Test do
  use ExUnit.Case, async: true
  use ExUnitProperties

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
end
