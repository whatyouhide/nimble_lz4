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

  describe "compress/1" do
    test "with binaries" do
      assert NimbleLZ4.compress("foo") == "0foo"
    end

    test "with iodata" do
      assert NimbleLZ4.compress([]) == "\0"
      assert NimbleLZ4.compress([?f, [[[?o]]], "o"]) == "0foo"
    end
  end

  describe "decompress/2" do
    test "with bad arguments" do
      assert_raise ArgumentError, fn -> NimbleLZ4.decompress(:banana, :apple) end
    end

    test "with the wrong uncompressed size" do
      assert {:error, message} = NimbleLZ4.decompress(NimbleLZ4.compress("foo"), 6)
      assert message == "the expected decompressed size differs, actual 3, expected 6"
    end
  end
end
