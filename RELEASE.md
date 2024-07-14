# Release

This information is only useful for maintainers of this library, not for its
users.

To **release** a new version of this library:

  1. Make your changes (duh!).

  1. Update the version in [`mix.exs`](./mix.exs) and update the
     [changelog](./CHANGELOG.md) file.

  1. Commit.

  1. Release a *new tag*:

     ```shell
     git tag -a vx.x.x -m "Release vx.x.x"
     ```

  1. Push the tag to GitHub: `git push --tags`.

  1. Wait for CI to build all NIFs (with the new version).

  1. Clean Rustler caches. If you don't do this, you can get issues with wrong
     versions trying to be downloaded. To clean caches, find where RustlerPrecompiled stores caches and wipe the directory. I usually do:

     ```shell
     mix run -e ':filename.basedir(:user_cache, "rustler_precompiled")'
     ```

      with `:filename.basedir(:user_cache, "rustler_precompiled")` and wipe the directory.

  1. After wiping the caches, run this to get a local checksum file:

     ```shell
     mix rustler_precompiled.download NimbleLZ4 --only-local
     ```

  1. Run the "download" to download a file that must be included in the Hex
     package:

     ```shell
     mix rustler_precompiled.download NimbleLZ4 --all --print
     ```

  1. Release the package on Hex: `mix hex.publish`.
