# `eip-3074-foundry`

This repository contains patched versions of [`foundry`][foundry] & [the `solidity` compiler][solc], integrated with patches to [`revm`][revm] / [`ethers-rs`][ethers-rs], that support
the [EIP-3074][eip-3074] opcodes (`AUTH` & `AUTHCALL`).

## Patches

> **NOTE**:
> These are *patches*, don't spin up a production system with these and expect security.

- `revm` patch: https://github.com/clabby/revm/pull/1
    - See review comments. Incomplete atm, but functionally works as expected.
- `ethers-rs` patch: https://github.com/clabby/ethers-rs/tree/cl/call-type-3074
- `foundry` patch: https://github.com/clabby/foundry/tree/cl/eip-3074
- `solc` patch: https://github.com/clabby/solidity/tree/cl/eip-3074
- `reth` patch: https://github.com/paradigmxyz/reth/tree/cl/eip-3074

## Usage

**Building `forge`**

First, build the patched version of `foundry` (this will take a while):

```sh
git submodule update --init --recursive && \
    make build-forge-patch
```

This command will place the patched `forge` binary in `bin/forge`.

**Building `solc`**

Next, build the patched version of `solc` (this will also take a while):

```
make build-solc-patch
```

This patch supports the following semantics:
```solidity
function example() public {
    // AUTHCALL by `address` member access
    address(0xbeefbabe).authcall(hex"...");

    assembly {
        // AUTH
        let authSuccess := auth(<authorized>, <args_offset_mem>, <args_length>)

        // AUTHCALL
        let authCallSuccess := authcall(
            <gas>,
            <to_addr>,
            <value>, // NOTE: This is currently sent from the Invoker contract, NOT the `authorized` account.
            <valueExt>, // Must always be `0` per the current 3074 spec, reserved for future use.
            <args_offset_mem>,
            <args_length>,
            <ret_offset_mem>,
            <ret_length>
        )
    }
}
```

**Installing `huffc`**

The [`huff`][huff-rs] version of the `EIP-3074` invoker requires `huffc` to be installed.

```sh
make install-huff
```

**Running Examples**

To run the examples, interact with the patched `forge` binary as normal. Try the existing tests by running `bin/forge test`.

There is a special override for the `Prague` hardfork within the `foundry.toml` which will enable the `AUTH` & `AUTHCALL` opcodes, and the `foundry.toml` specifies the patched `solc` binary as the compiler.

[foundry]: https://github.com/foundry-rs/foundry
[revm]: https://github.com/bluealloy/revm
[ethers-rs]: https://github.com/gakonst/ethers-rs
[eip-3074]: https://eips.ethereum.org/EIPS/eip-3074
[solc]: https://github.com/ethereum/solidity
[huff-rs]: https://github.com/huff-language/huff-rs

## EIP-3074 References

- https://eips.ethereum.org/EIPS/eip-3074
- https://hackmd.io/@matt/note-on-3074
- https://github.com/clabby/eip-3074-foundry
- https://ethresear.ch/t/a-brief-note-on-the-future-of-accounts/12395
