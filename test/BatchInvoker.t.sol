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

    function constructAndSignTransaction()
        internal
        view
        returns (uint8 v, bytes32 r, bytes32 s, bytes memory execData)
    {
        bytes memory data = abi.encodeWithSelector(Callee.expectSender.selector, address(authority.addr));
        bytes memory transactions = abi.encodePacked(AUTHCALL_IDENTIFIER, address(callee), value, data.length, data);
        execData = abi.encode(nonce, transactions);
        // construct batch digest & sign
        bytes32 digest = invoker.getDigest(execData);
        (v, r, s) = vm.sign(authority.privateKey, digest);
    }

    function test_authCall() public {
        vm.pauseGasMetering();
        (uint8 v, bytes32 r, bytes32 s, bytes memory execData) = constructAndSignTransaction();
        address authrty = authority.addr;
        vm.resumeGasMetering();
        // this will call Callee.expectSender(authority)
        invoker.execute(authrty, v, r, s, execData);
    }

    // invalid nonce fails
    function test_invalidNonce() public {
        vm.pauseGasMetering();
        // 1 is invalid starting nonce
        nonce = 1;
        (uint8 v, bytes32 r, bytes32 s, bytes memory execData) = constructAndSignTransaction();
        address authrty = authority.addr;
        vm.expectRevert(abi.encodeWithSelector(BatchInvoker.InvalidNonce.selector, authority.addr, 1));
        vm.resumeGasMetering();
        invoker.execute(authrty, v, r, s, execData);
    }

    function test_authCallWithValue() public {
        vm.pauseGasMetering();
        value = 1 ether;
        (uint8 v, bytes32 r, bytes32 s, bytes memory execData) = constructAndSignTransaction();
        address authrty = authority.addr;
        vm.resumeGasMetering();
        // this will call Callee.expectSender(authority)
        invoker.execute{ value: 1 ether }(authrty, v, r, s, execData);
    }

    // fails if too little value to pass to sub-call
    function test_tooLittleValue() public {
        vm.pauseGasMetering();
        value = 1 ether;
        (uint8 v, bytes32 r, bytes32 s, bytes memory execData) = constructAndSignTransaction();
        address authrty = authority.addr;
        vm.expectRevert();
        vm.resumeGasMetering();
        invoker.execute{ value: 0.5 ether }(authrty, v, r, s, execData);
    }

    // fails if too much value to pass to sub-call
    function test_tooMuchValue() public {
        vm.pauseGasMetering();
        value = 1 ether;
        (uint8 v, bytes32 r, bytes32 s, bytes memory execData) = constructAndSignTransaction();
        address authrty = authority.addr;
        vm.expectRevert(abi.encodeWithSelector(BaseInvoker.ExtraValue.selector));
        vm.resumeGasMetering();
        invoker.execute{ value: 2 ether }(authrty, v, r, s, execData);
    }

    // TODO: if subcall reverts, it reverts with the right return data (bubbles up the error)
}
