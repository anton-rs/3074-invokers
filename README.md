# EIP-3074 Invokers

Generalized [EIP-3074](https://eips.ethereum.org/EIPS/eip-3074) Invokers. 

- `BaseInvoker` - Invoker template for building arbitrary Invoker logic.
- `BatchInvoker` - Invoker with batch transaction support.

> [!WARNING] 
> WIP. Very experimental, not audited, use with caution.

## Patches

This repository contains patches (h/t @clabby) of the following repositories to support EIP-3074 opcodes:

- [`revm`](https://github.com/wevm/revm/tree/jxom/eip-3074)
- [`foundry`](https://github.com/wevm/foundry/tree/jxom/eip-3074)
- [`solc`](https://github.com/clabby/solidity/tree/cl/eip-3074)

## Installation

```shell
git submodule update --init --recursive && make
```

## Building Contracts

```shell
make build
```

## Running Tests

```shell
make test
```

## Local Devnet Deployment

### Launch Anvil

```shell
make anvil-prague
```

### Deploy invoker

```shell
./bin/forge script Deploy --sig "deploy()" --rpc-url $RPC_URL --private-key $EXECUTOR_PRIVATE_KEY --broadcast
```

### Test invoker

Send eth

```shell
bin/forge script Executor --sig "sendEth(address,address,uint256)" $INVOKER_ADDRESS 0x3074ca113074ca113074ca113074ca113074ca11 0.01ether --rpc-url $RPC_URL --broadcast
```

## 3074-Compatible Networks

### Otim Hosted Devnet

Powered by [Reth AlphaNet](https://github.com/paradigmxyz/alphanet), check out Otim's [3074 devnet docs](https://docs.otim.xyz) for detailed information on how to set up the network, get devnet ETH, use the deployed `BatchInvoker`, and more.

