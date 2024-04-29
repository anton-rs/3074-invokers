# EIP-3074 Invokers

Generalized [EIP-3074](https://eips.ethereum.org/EIPS/eip-3074) Invokers. 

- `BaseInvoker` - Invoker template for building arbitrary Invoker logic.
- `BatchInvoker` - Invoker with batch transaction support.

> [!WARNING] 
> WIP. Very experimental, not audited, use with caution.

## Patches

This repository contains patches (h/t @clabby) of the following repositories to support EIP-3074 opcodes:

- [`revm`](https://github.com/jxom/revm/tree/jxom/eip-3074)
- [`foundry`](https://github.com/jxom/foundry/tree/jxom/eip-3074)
- [`solc`](https://github.com/clabby/solidity/tree/cl/eip-3074)

## Installation

```
git submodule update --init --recursive && make
```

## Building Contracts

```
make build
```

## Running Tests

```
make test
```

## Local Devnet Deployment

### Launch Anvil

```
make anvil-prague
```

### Deploy invoker
```
./bin/forge script Deploy --sig "deploy()" --rpc-url $RPC_URL --private-key $EXECUTOR_PRIVATE_KEY --broadcast
```

### Test invoker
Get the byte-encoded calls you want to execute. This example shows simply sending 1 ETH to 0xDeaDbeef.
```
./bin/forge script Executor --sig "encodeCalls(bytes,address,uint256,bytes)" --rpc-url $RPC_URL --broadcast 0x 0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF 1ether 0x
```

Copy the output from `encodeCalls` above into `<transaction-bytes>`.
```
./bin/forge script Executor --sig "signAndExecute(address,bytes)" $INVOKER_ADDRESS <transactions-bytes> --rpc-url $RPC_URL --private-key $EXECUTOR_PRIVATE_KEY --broadcast
```

Check on the execution results, it should output `1000000000000000000`.
```
./bin/cast balance 0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF
```

