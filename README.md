# Glibc 2.17 on Modern Nixpkgs

[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Built with Nix](https://img.shields.io/badge/built%20with-Nix-5277C3.svg?logo=nixos&style=flat-square)](https://nixos.org)

> A Nix flake that provides a reproducible development environment with **glibc 2.17**, built against a modern, up-to-date Nixpkgs. This enables running legacy binaries and building software that requires compatibility with older Linux distributions (CentOS 7, RHEL 7, etc.).

## 📖 Overview

This project provides a Nix flake to build and use a development environment based on GNU C Library (glibc) version 2.17. This is particularly useful for:

*   **Creating Highly Portable Binaries**: Glibc has excellent forward compatibility due to symbol versioning. A binary compiled and linked against an old version of `glibc` (like 2.17) will run on almost any modern Linux system, as newer systems provide the required symbols. The reverse is not true. This is the core principle behind projects like **manylinux** (for Python wheels) and **HolyBuildBox**. This flake provides a convenient, Nix-native way to produce such portable software.

*   **Binary Exploitation (Pwn)**: Many CTF challenges and pwn exercises are based on older systems with specific glibc versions like 2.17, which have well-known vulnerabilities and memory layouts.

*   **Reverse Engineering**: Analyzing binaries that were compiled on older Linux distributions (like Ubuntu 14.04).

*   **Legacy Software**: Running or developing for proprietary or legacy applications that are dynamically linked against this specific glibc version and cannot be recompiled.

The main challenge is that building such an old library with a modern toolchain (like GCC 14) is non-trivial. This flake solves that problem.

## Features

- Builds glibc 2.17 with modern GCC 14.x toolchain
- Provides a complete stdenv with glibc 2.17
- Includes locale packages (`glibcLocales` and `glibcLocalesUtf8`)
- Compatible with nixpkgs-unstable (2025)
- Supports x86_64-linux systems
- Creates highly portable binaries that run on Linux systems from 2012 onwards

## ✨ What's New in this Fork?

This repository is a fork and significant renovation of [midchildan/glibc-2-17-flake](https://github.com/midchildan/glibc-2-17-flake). While the original project provided the foundational work, it was pinned to a `nixpkgs` revision from early 2023. This fork modernizes the entire stack:

*   **Up-to-date Nixpkgs**: The `flake.lock` has been updated to a recent `nixpkgs-unstable` revision, bringing in the latest security patches, bug fixes, and package versions from the Nix ecosystem.
*   **Modern Toolchain**: The underlying build environment has been upgraded from GCC 12.3.0 to **GCC 14.x**, along with updated versions of Binutils and other core dependencies.
*   **Comprehensive Fixes**: The upgrade to a modern toolchain introduced numerous build failures. This fork addresses them by:
    *   Patching `glibc-2.17` to be compatible with newer compiler features and stricter error checking.
    *   Adjusting build scripts and environment flags (`-Wno-error=...`).
    *   Resolving symbol versioning issues (`fix-symver.patch`).
    *   Ensuring the custom `stdenv` builds correctly from the ground up.

Essentially, this fork maintains the original goal but ensures its long-term viability and compatibility with the modern Nix ecosystem.

## 🚀 Usage

First, ensure you have Nix installed with flakes enabled. See the [official guide](https://nixos.org/download.html) for instructions.

### Development Shell

This is the primary use case. To enter a shell with `glibc-2.17` available in the environment, along with a compatible C compiler and other development tools, run:

```bash
nix develop
```

Inside this shell, you can compile and run programs that target `glibc-2.17`:

```bash
# Check glibc version
ldd --version

# Compile a simple C program
gcc my_program.c -o my_program

# The resulting binary will be linked against glibc 2.17
# and will be portable to most modern Linux systems.
ldd ./my_program
```

### Running a Single Command

To run a specific command or an existing binary within the `glibc-2.17` environment without permanently entering a shell:

```bash
# Run a specific tool from the environment
nix shell .#glibc_2_17 --command ldd --version

# Execute a pre-compiled legacy binary
nix shell .#glibc_2_17 --command ./path/to/my_legacy_binary
```
> Note: The default package is a debug build. To get access to the actual `glibc` package, use `.#glibc_2_17`.

### Using in another Flake

You can integrate this flake as an input to your own project to create custom development environments or packages. `legacyPackages` provides a complete `pkgs` set built with the `glibc-2.17` toolchain.

```nix
# your-flake.nix
{
  description = "My project using old glibc";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    glibc-2-17-flake.url = "github:dmitry-j-mikhin/glibc-2-17-flake";
  };

  outputs = { self, nixpkgs, glibc-2-17-flake, ... }:
    let
      system = "x86_64-linux";
      # Get the pkgs set built with glibc 2.17
      pkgs = glibc-2-17-flake.legacyPackages.${system};
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        # You can now use packages from this specific pkgs set
        packages = [
          pkgs.gdb
          pkgs.python3
          # Your package here, which will be built with the old glibc
          # (pkgs.callPackage ./my-package.nix {})
        ];
      };
    };
}
```

### Creating Portable Binaries

When you build software with this flake, the resulting binaries will be compatible with virtually any Linux distribution released since 2012, making it ideal for:

- Distributing commercial software
- Creating AppImages or other portable formats
- Building tools for diverse Linux environments
- CI/CD pipelines that need to support older systems


## 🛠️ How It Works

The magic behind this flake involves several key Nix techniques:

1.  **Fetching Old Derivations**: The original derivation for `glibc-2.17` and its patches are sourced from a historical version of Nixpkgs (specifically, commit `fd7bc4ebf...`).
2.  **Stdenv Replacement**: The core of the solution is `replaceStdenv`. We instruct Nixpkgs to build a new standard environment from scratch. During this process, we substitute the default `glibc` with our custom-built `glibc-2.17`.
3.  **GCC Recompilation**: To ensure binary compatibility and correct header paths, the C compiler (`gcc`) itself is rebuilt against our `glibc-2.17`. This prevents conflicts and ensures that `libstdc++` and other runtime libraries are compatible.
4.  **Backporting Patches**: The `glibc-2.17` source code requires patching to compile with modern compilers. This flake applies patches from newer `glibc` versions and custom fixes to address issues like outdated configure scripts and new compiler warnings that are treated as errors.

## Similar Projects & Alternatives

### Portable Linux Build Environments

- **[manylinux](https://github.com/pypa/manylinux)** - Python's standard for portable Linux wheels, uses CentOS 7 (glibc 2.17) for manylinux2014
- **[Holy Build Box](https://github.com/phusion/holy-build-box)** - Docker environment for building portable Linux binaries, based on CentOS 7
- **[AppImage](https://appimage.org/)** - Recommends building against the oldest still-supported LTS distributions
- **[Zig CC](https://andrewkelley.me/post/zig-cc-powerful-drop-in-replacement-gcc-clang.html)** - Can target specific glibc versions
- **[cosmopolitan](https://github.com/jart/cosmopolitan)** - Actually Portable Executable format

### Nix-specific Solutions

- [nix-community/nix-environments](https://github.com/nix-community/nix-environments) - Collection of development environments
- [NixOS/patchelf](https://github.com/NixOS/patchelf) - The essential tool for modifying the dynamic linker and library paths of ELF binaries.
- [nix-portable](https://github.com/DavHau/nix-portable) - Nix for systems with older glibc

## License

MIT License - see [LICENSE](LICENSE) file for details.

Original work Copyright (c) 2023 midchildan

Fork modifications Copyright (c) 2025 dmitry-j-mikhin

## Acknowledgments

- Thanks to [midchildan](https://github.com/midchildan) for the original glibc-2.17-flake project
- The NixOS/nixpkgs community for maintaining historical package versions
- Contributors who provided patches for glibc compatibility
- The manylinux and Holy Build Box projects for establishing best practices in portable Linux binary distribution

## Contributing

Issues and pull requests are welcome! Please report any compatibility problems or build failures you encounter.
