// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.13;

import { Auth } from "../src/Auth.sol";
import { BaseInvoker } from "../src/BaseInvoker.sol";
import { vToYParity } from "../test/utils.sol";
import { Script } from "forge-std/Script.sol";

contract Executor is Script {
    uint256 pk = vm.envUint("PRIVATE_KEY");

    function signAndExecute(address invoker, bytes memory execData) public {
        // construct the digest from execData
        bytes32 digest = BaseInvoker(invoker).getDigest(execData, vm.getNonce(vm.addr(pk)));
        // sign the digest
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        // broadcast execute transaction
        vm.startBroadcast();
        BaseInvoker(invoker).execute(
            execData, Auth.Signature({ signer: vm.addr(pk), yParity: vToYParity(v), r: r, s: s })
        );
        vm.stopBroadcast();
    }
}
