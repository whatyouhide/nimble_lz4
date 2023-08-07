# Release

This information is only useful for maintainers of this library, not for its
users.

To **release** a new version of this library:

  1. Make your changes (duh!).

  1. Update the version in [`mix.exs`](./mix.exs) and update the
     [changelog](./CHANGELOG.md) file.

  1. Release a *new tag*:

     ```shell
     git tag -a vx.x.x -m "Release vx.x.x"
     ```

  1. Push the tag to GitHub: `git push --tags`.

  1. Wait for CI to build all NIFs (with the new version).

  1. Run the "download" to download a file that must be included in the Hex
     package:

     ```shell
     mix rustler_precompiled.download NimbleLZ4 --all --print
     ```

  1. Release the package on Hex: `mix hex.publish`.
