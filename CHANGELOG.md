# Changelog

## v1.1.0

  * Add `NimbleLZ4.compress_frame/1` and `NimbleLZ4.decompress_frame/1` to use with the [LZ4 frame format](https://github.com/lz4/lz4/blob/dev/doc/lz4_Frame_format.md).

## v1.0.0

This is just the 1.0 release, no changes! Yay.

## v0.1.4

  * Use DirtyCPU schedulers for NIFs. See the excellent explanation in [#7](https://github.com/whatyouhide/nimble_lz4/pull/7).

## v0.1.3

⚠️ This release has effectively no differences from v0.1.2. ⚠️

  * Modernize Rustler dependencies. This should have no effect on end users
    of this library.

## v0.1.2

  * Also build for the `aarch64-unknown-linux-musl` target.

## v0.1.1

⚠️ This release has effectively no differences from v0.1.0. ⚠️

## v0.1.0

First release.
