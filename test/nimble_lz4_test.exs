defmodule NimbleLZ4Test do
  use ExUnit.Case, async: true
  use ExUnitProperties

  property "compress + uncompress are circular" do
    check all(binary <- binary()) do
      assert {:ok, ^binary} =
               binary
               |> NimbleLZ4.compress()
               |> NimbleLZ4.decompress(byte_size(binary))
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
