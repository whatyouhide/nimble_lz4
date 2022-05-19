small_input = :crypto.strong_rand_bytes(5)
medium_input = :crypto.strong_rand_bytes(256)
large_input = :crypto.strong_rand_bytes(1024 * 1024)

Benchee.run(%{
  "compress_small_input" => fn -> NimbleLZ4.compress(small_input) end,
  "compress_medium_input" => fn -> NimbleLZ4.compress(medium_input) end,
  "compress_large_input" => fn -> NimbleLZ4.compress(large_input) end,
})
