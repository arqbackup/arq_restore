# Build Instructions for `arq_restore` with Modern Tools

This document describes how to build `arq_restore`, verified with [anthonywu's](https://github.com/anthonywu) setup:

- macOS Sequoia 15.5
- Apple Silicon M1
- Xcode 16.4
- OpenSSL 3.x installed via `nix-env -iA nixpkgs.openssl`
- on date: 2025-08-01

## Fixes Applied

The commit prior to the 2025-08-01 build fix was:

```
commit d4a3d0e14c51695fb0e38c78804859a856eca3bc (HEAD -> master, up/master, up/HEAD)
Author: Stefan Reitshamer <stefan@reitshamer.com>
Date:   Mon Dec 14 17:25:04 2020 -0500
```

The following fixes were applied to make the code compile with modern tools, almost 5 years later.

### 1. C Language Compatibility (lz4.c)
- Fixed function prototypes that were missing `void` parameter lists
- Changed `int LZ4_sizeofState()` to `int LZ4_sizeofState(void)`
- Changed `int LZ4_sizeofStreamState()` to `int LZ4_sizeofStreamState(void)`

### 2. HTTP Header Conflicts (HTTP.h)
- Added header guards to prevent macro redefinition errors
- Wrapped HTTP status code definitions with `#ifndef` checks

### 3. OpenSSL 3.x API Updates (OpenSSLCryptoKey.m)
- Changed `EVP_CIPHER_CTX` from stack allocation to heap allocation
- Replaced `EVP_CIPHER_CTX_init()` with `EVP_CIPHER_CTX_new()`
- Replaced `EVP_CIPHER_CTX_cleanup()` with `EVP_CIPHER_CTX_free()`
- Updated all references from `&cipherContext` to `cipherContext` (pointer)

## Building

The `/nix/store/...` paths are for example only.

These paths will be different depending on which system/day/version your dependencies come from.

You also may install `openssl` via different package managers. It's up to you to tweak the recipe here to work for you.

In my case, I build for arm64 architecture:

```bash
xcodebuild build -configuration Release \
  ARCHS=arm64 \
  VALID_ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=NO \
  HEADER_SEARCH_PATHS='$(inherited) /nix/store/vg95s0pj6mni9xrcmsnp2rg44kqpxyic-openssl-3.0.16-dev/include' \
  LIBRARY_SEARCH_PATHS='$(inherited) /nix/store/8gl0j1qfbn0jlr1d67fr2pkk8gpxk43b-openssl-3.0.16/lib'
```

Note: The exact nix store paths may vary. Find your OpenSSL paths with:
```bash
find /nix/store -name "openssl" -type d -path "*include*" | grep -E "openssl-3.*include"
find /nix/store -name "libcrypto*.dylib" -o -name "libssl*.dylib" | grep -E "openssl-3"
```

## Output

The built executable will be at: `build/Release/arq_restore`

## Testing

Test the executable:

```bash
./build/Release/arq_restore
```

This should display the usage help:

```
Usage:
	arq_restore [-l loglevel] listtargets
	arq_restore [-l loglevel] addtarget <nickname> aws <access_key>
	arq_restore [-l loglevel] addtarget <nickname> local <path>
	arq_restore [-l loglevel] deletetarget <nickname>

	arq_restore [-l loglevel] listcomputers <target_nickname>
	arq_restore [-l loglevel] listfolders <target_nickname> <computer_uuid>
	arq_restore [-l loglevel] printplist <target_nickname> <computer_uuid> <folder_uuid>
	arq_restore [-l loglevel] listtree <target_nickname> <computer_uuid> <folder_uuid>
	arq_restore [-l loglevel] restore <target_nickname> <computer_uuid> <folder_uuid> [relative_path]
	arq_restore [-l loglevel] clearcache <target_nickname>

log levels: none, error, warn, info, and debug
log output: ~/Library/Logs/arq_restorer
```
