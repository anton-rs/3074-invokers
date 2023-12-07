// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Test, console2 } from "forge-std/Test.sol";
import { VmSafe } from "forge-std/Vm.sol";
import { BatchInvoker } from "../src/BatchInvoker.sol";
import { BaseInvoker } from "../src/BaseInvoker.sol";

contract Callee {
    error UnexpectedSender(address expected, address actual);

    function expectSender(address expected) public payable {
        if (msg.sender != expected) revert UnexpectedSender(expected, msg.sender);
    }
}

contract BatchInvokerTest is Test {
    Callee public callee;
    BatchInvoker public invoker;
    VmSafe.Wallet public authority;

    uint8 AUTHCALL_IDENTIFIER = 2;

    uint256 nonce = 0;
    uint256 value = 0;

    function setUp() public {
        invoker = new BatchInvoker();
        callee = new Callee();
        authority = vm.createWallet("authority");
        vm.label(address(invoker), "invoker");
        vm.label(address(callee), "callee");
        vm.label(authority.addr, "authority");
    }

    function constructAndSignTransaction() internal view returns (bytes memory authData, bytes memory execData) {
        bytes memory data = abi.encodeWithSelector(Callee.expectSender.selector, address(authority.addr));
        bytes memory transactions = abi.encodePacked(AUTHCALL_IDENTIFIER, address(callee), value, data.length, data);
        execData = abi.encodePacked(nonce, transactions.length, transactions);
        // construct batch digest & sign
        bytes32 digest = invoker.getDigest(execData);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(authority.privateKey, digest);
        authData = abi.encodePacked(authority.addr, v, r, s);
    }

    function test_authCall() public {
        vm.pauseGasMetering();
        (bytes memory authData, bytes memory execData) = constructAndSignTransaction();
        vm.resumeGasMetering();
        // this will call Callee.expectSender(authority)
        invoker.execute(authData, execData);
    }

    // invalid nonce fails
    function test_invalidNonce() public {
        vm.pauseGasMetering();
        // 1 is invalid starting nonce
        nonce = 1;
        (bytes memory authData, bytes memory execData) = constructAndSignTransaction();
        vm.resumeGasMetering();
        vm.expectRevert(abi.encodeWithSelector(BatchInvoker.InvalidNonce.selector, authority.addr, 1));
        invoker.execute(authData, execData);
    }

    function test_authCallWithValue() public {
        vm.pauseGasMetering();
        value = 1 ether;
        (bytes memory authData, bytes memory execData) = constructAndSignTransaction();
        vm.resumeGasMetering();
        // this will call Callee.expectSender(authority)
        invoker.execute{ value: 1 ether }(authData, execData);
    }

    // fails if too little value to pass to sub-call
    function test_tooLittleValue() public {
        vm.pauseGasMetering();
        value = 1 ether;
        (bytes memory authData, bytes memory execData) = constructAndSignTransaction();
        vm.resumeGasMetering();
        vm.expectRevert();
        invoker.execute{ value: 0.5 ether }(authData, execData);
    }

    // fails if too much value to pass to sub-call
    function test_tooMuchValue() public {
        vm.pauseGasMetering();
        value = 1 ether;
        (bytes memory authData, bytes memory execData) = constructAndSignTransaction();
        vm.expectRevert(abi.encodeWithSelector(BaseInvoker.ExtraValue.selector));
        vm.resumeGasMetering();
        invoker.execute{ value: 2 ether }(authData, execData);
    }

    // TODO: if subcall reverts, it reverts with the right return data (bubbles up the error)
}
