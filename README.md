# `eip-3074-foundry`

This repository contains a patched version of [`foundry`][foundry], integrated with a fork of [`revm`][revm] / [`ethers-rs`][ethers-rs], that supports
the [EIP-3074][eip-3074] opcodes (`AUTH` & `AUTHCALL`).

## Patches

- `revm` patch: https://github.com/clabby/revm/pull/1
- `ethers-rs` patch: https://github.com/clabby/ethers-rs/tree/cl/call-type-3074
- `foundry` patch: https://github.com/clabby/foundry/tree/cl/eip-3074

## Usage

**Building `forge`**

First, build the patched version of `foundry`:

```sh
git submodule update --init --recursive && make build-forge-patch
```

This command will place the patched `forge` binary in `bin/forge`.

**Installing `huffc`**

```sh
make install-huff
```

**Running Examples**

To run the examples, interact with the patched `forge` binary as normal. There is a special override for the `Prague` hardfork within the `foundry.toml` which
will enable the `AUTH` & `AUTHCALL` opcodes.

[foundry]: https://github.com/foundry-rs/foundry
[revm]: https://github.com/bluealloy/revm
[ethers-rs]: https://github.com/gakonst/ethers-rs
[eip-3074]: https://eips.ethereum.org/EIPS/eip-3074
