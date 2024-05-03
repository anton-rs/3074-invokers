# EIP-3074 Invokers

Generalized [EIP-3074](https://eips.ethereum.org/EIPS/eip-3074) Invokers. 

- `BaseInvoker` - Invoker template for building arbitrary Invoker logic.
- `BatchInvoker` - Invoker with batch transaction support.

> [!WARNING] 
> WIP. Very experimental, not audited, use with caution.

## Development

Developing with these contracts currently requires [`foundry-alphanet`](https://github.com/paradigmxyz/foundry-alphanet) – a repository containing patches for [Foundry](https://github.com/foundry-rs/foundry) to support EIP-3074 opcodes.

We have abstracted `foundry-alphanet` docker image execution into a set of Makefile scripts listed below.

### Installation

First, we will need to set up the submodules for the repository.

```shell
make install
```

### Building Contracts

We can build the contracts using `forge build` via `foundry-alphanet`:

```shell
make cmd="forge build"
```

### Running Tests

We can run tests using `forge test` via `foundry-alphanet`:

```shell
make cmd="forge test"
```

### Launch a Local Network

We can launch an Anvil instance using `anvil` via `foundry-alphanet`:

```shell
make cmd="anvil"
```

### Deploying Invoker Contracts

Below, we will deploy the `BatchInvoker` contract to a local Anvil network.

#### 1. Launch Anvil

First, we will need to launch an Anvil instance. If you are deploying to a launched network, you can skip this step.

```shell
make cmd="anvil"
```

#### 2. Deploy Invoker

Deploy the `BatchInvoker` contract to the network.

```shell
make cmd="forge script Deploy --sig 'deploy()' --rpc-url $RPC_URL --private-key $EXECUTOR_PRIVATE_KEY --broadcast"
```

**Note:** if the `$RPC_URL` you're pointing to is on host, you should use http://host.docker.internal:8545 instead of http://localhost:8545. See Docker's networking docs [here](https://docs.docker.com/desktop/networking/#i-want-to-connect-from-a-container-to-a-service-on-the-host).

#### 3. Test Invoker

We can test the `BatchInvoker` by sending a transaction via the contract.

```shell
make cmd="forge script Executor --sig 'sendEth(address,address,uint256)' $INVOKER_ADDRESS 0x3074ca113074ca113074ca113074ca113074ca11 0.01ether --rpc-url $RPC_URL --broadcast"
```

## 3074-Compatible Networks

### Otim Hosted Devnet

Powered by [Reth AlphaNet](https://github.com/paradigmxyz/alphanet), check out Otim's [3074 devnet docs](https://docs.otim.xyz) for detailed information on how to set up the network, get devnet ETH, use the deployed `BatchInvoker`, and more.

