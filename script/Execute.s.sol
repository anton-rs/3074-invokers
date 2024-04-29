// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.13;

import { Auth } from "../src/Auth.sol";
import { BatchInvoker } from "../src/BatchInvoker.sol";
import { vToYParity } from "../test/utils.sol";
import { Script } from "forge-std/Script.sol";

contract Executor is Script {
    uint256 apk = vm.envUint("AUTHORITY_PRIVATE_KEY");
    uint256 epk = vm.envUint("EXECUTOR_PRIVATE_KEY");

    function signAndExecute(address invoker, bytes memory calls) public {
        // get authority's next nonce for `invoker`
        uint256 nonce = BatchInvoker(invoker).nextNonce(vm.addr(apk));

        // construct the digest from execData
        bytes memory execData = abi.encode(nonce, calls);
        bytes32 digest = BatchInvoker(invoker).getDigest(execData, vm.getNonce(vm.addr(apk)));
        // sign the digest
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(apk, digest);
        // broadcast execute transaction
        vm.startBroadcast(epk);
        BatchInvoker(invoker).execute(
            execData, Auth.Signature({ signer: vm.addr(apk), yParity: vToYParity(v), r: r, s: s })
        );
        vm.stopBroadcast();
    }

    function encodeCalls(bytes memory prevCalls, address to, uint256 value, bytes memory data) public pure returns (bytes memory calls) {
        return abi.encodePacked(prevCalls, uint8(2), to, value, data.length, data);
    }
}
