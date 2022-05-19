small_input = :crypto.strong_rand_bytes(5)
medium_input = :crypto.strong_rand_bytes(256)
large_input = :crypto.strong_rand_bytes(1024 * 1024)

Benchee.run(%{
  "decompress_small_input" => fn -> NimbleLZ4.decompress(small_input, 5) end,
  "decompress_medium_input" => fn -> NimbleLZ4.decompress(medium_input, 256) end,
  "decompress_large_input" => fn -> NimbleLZ4.decompress(large_input, 1024 * 1024) end,
})
