// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Test, console2 } from "forge-std/Test.sol";
import { VmSafe } from "forge-std/Vm.sol";
import { SingleInvoker } from "../src/SingleInvoker.sol";
import { MockSomeContractToBeCalled } from "./mocks/MockSomeContractToBeCalled.sol";

contract SingleInvokerTest is Test {
    uint256 public nonce;
    uint256 public value;
    uint256 public gas;

    SingleInvoker public invoker;
    VmSafe.Wallet public authority;
    MockSomeContractToBeCalled public someContract;

    function setUp() public {
        nonce = 0;
        value = 0;
        gas = 1 ether;

        invoker = new SingleInvoker();
        authority = vm.createWallet("authority");
        someContract = new MockSomeContractToBeCalled();

        vm.label(address(invoker), "invoker");
        vm.label(authority.addr, "authority");
        vm.label(address(someContract), "someContract");
    }

    // prepare commit for signing
    function constructAndSignTransaction(bytes memory data)
        internal
        view
        returns (uint8 v, bytes32 r, bytes32 s, bytes memory execData)
    {
        execData = abi.encode(nonce, gas, value, address(someContract), data);
        // construct batch digest & sign
        bytes32 digest = invoker.getDigest(execData);
        (v, r, s) = vm.sign(authority.privateKey, digest);
    }

    // single success authcall gas comparison test versus BatchInvoker
    function test_authCallSuccess() public {
        vm.pauseGasMetering();
        bytes memory data = abi.encodeWithSelector(someContract.twoPlusTwoEquals.selector, 4);
        (uint8 v, bytes32 r, bytes32 s, bytes memory execData) = constructAndSignTransaction(data);

        vm.resumeGasMetering();
        invoker.execute(authority.addr, v, r, s, execData);

        assertTrue(someContract.correctAnswers() == 1);
    }

    // single reverted authcall gas comparison test versus BatchInvoker
    function test_authCallFail_SumIncorrect() public {
        vm.pauseGasMetering();
        bytes memory data = abi.encodeWithSelector(someContract.twoPlusTwoEquals.selector, 5);
        (uint8 v, bytes32 r, bytes32 s, bytes memory execData) = constructAndSignTransaction(data);

        vm.expectRevert(MockSomeContractToBeCalled.SumIncorrect.selector);
        vm.resumeGasMetering();
        invoker.execute(authority.addr, v, r, s, execData);
    }
}
