// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script } from "forge-std/Script.sol";
import { BatchInvoker } from "../src/BatchInvoker.sol";

contract Deploy is Script {
    // deploy:
    // ./bin/forge script Deploy --sig "deploy()" --rpc-url $RPC_URL  --private-key $PRIVATE_KEY --broadcast
    function deploy() public {
        vm.broadcast();
        new BatchInvoker();
    }
}
