// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.13;

import { Auth } from "../src/Auth.sol";
import { BaseInvoker } from "../src/BaseInvoker.sol";
import { BatchInvoker } from "../src/BatchInvoker.sol";
import { vToYParity, packCalls } from "../test/utils.sol";
import { Script } from "forge-std/Script.sol";
import { Test } from "forge-std/Test.sol";

contract Executor is Script, Test {
    uint256 apk = vm.envUint("AUTHORITY_PRIVATE_KEY");
    uint256 epk = vm.envUint("EXECUTOR_PRIVATE_KEY");

    // script that signs auth message and calls `execute` on invoker
    function signAndExecute(address invoker, bytes memory execData) public {
        // construct the digest from execData
        bytes32 digest = BaseInvoker(invoker).getDigest(execData, vm.getNonce(vm.addr(apk)));
        // sign the digest
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(apk, digest);
        // broadcast execute transaction
        vm.startBroadcast(epk);
        BaseInvoker(invoker).execute(
            execData, Auth.Signature({ signer: vm.addr(apk), yParity: vToYParity(v), r: r, s: s })
        );
        vm.stopBroadcast();
    }

    // script that does one arbitrary call via a BatchInvoker
    function call(address invoker, address recipient, uint256 value, bytes memory data) public {
        // construct batch execData
        bytes memory calls = packCalls("", recipient, value, data);
        uint256 nonce = BatchInvoker(invoker).nextNonce(vm.addr(apk));
        bytes memory execData = abi.encode(nonce, calls);

        // generic script for sign & execute for any invoker
        signAndExecute(invoker, execData);
    }

    // script that just sends eth
    function sendEth(address invoker, address recipient, uint256 value) public {
        uint256 balanceBefore = recipient.balance;
        call(invoker, recipient, value, "");
        assertEq(recipient.balance, balanceBefore + value);
    }
}
