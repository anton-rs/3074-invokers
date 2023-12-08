// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Test, console2 } from "forge-std/Test.sol";
import { VmSafe } from "forge-std/Vm.sol";
import { BatchInvoker } from "../src/BatchInvoker.sol";

contract Callee {
    error UnexpectedSender(address expected, address actual);

    function expectSender(address expected) public payable {
        if (msg.sender != expected) revert UnexpectedSender(expected, msg.sender);
    }
}

contract BatchInvokerTest is Test {
    Callee public callee;
    BatchInvoker public invoker;
    uint256 nonce = 0;
    VmSafe.Wallet public authority;

    function setUp() public {
        invoker = new BatchInvoker();
        callee = new Callee();
        authority = vm.createWallet("authority");
        vm.label(address(invoker), "invoker");
        vm.label(address(callee), "callee");
        vm.label(authority.addr, "authority");
    }

    function constructAndSignTransaction(uint256 value)
        internal
        view
        returns (uint8 v, bytes32 r, bytes32 s, bytes memory transactions)
    {
        bytes memory data = abi.encodeWithSelector(Callee.expectSender.selector, address(authority.addr));
        uint8 identifier = 2;
        transactions = abi.encodePacked(identifier, address(callee), value, data.length, data);
        // construct batch digest & sign
        bytes32 digest = invoker.getDigest(nonce, transactions);
        (v, r, s) = vm.sign(authority.privateKey, digest);
    }

    function test_authCall() public {
        vm.pauseGasMetering();
        (uint8 v, bytes32 r, bytes32 s, bytes memory transactions) = constructAndSignTransaction(0);
        address authrty = authority.addr;
        uint256 n = nonce;
        vm.resumeGasMetering();
        // this will call Callee.expectSender(authority)
        invoker.execute(authrty, n, transactions, v, r, s);
    }

    // invalid nonce fails
    function test_invalidNonce() public {
        vm.pauseGasMetering();
        // 1 is invalid starting nonce
        nonce = 1;
        (uint8 v, bytes32 r, bytes32 s, bytes memory transactions) = constructAndSignTransaction(0);
        address authrty = authority.addr;
        uint256 n = nonce;
        vm.expectRevert(abi.encodeWithSelector(BatchInvoker.InvalidNonce.selector, authrty, 1));
        vm.resumeGasMetering();
        invoker.execute(authrty, n, transactions, v, r, s);
    }

    function test_authCallWithValue() public {
        vm.pauseGasMetering();
        (uint8 v, bytes32 r, bytes32 s, bytes memory transactions) = constructAndSignTransaction(1 ether);
        address authrty = authority.addr;
        uint256 n = nonce;
        vm.resumeGasMetering();
        // this will call Callee.expectSender(authority)
        invoker.execute{ value: 1 ether }(authrty, n, transactions, v, r, s);
    }

    // fails if too little value to pass to sub-call
    function test_tooLittleValue() public {
        vm.pauseGasMetering();
        (uint8 v, bytes32 r, bytes32 s, bytes memory transactions) = constructAndSignTransaction(1 ether);
        address authrty = authority.addr;
        uint256 n = nonce;
        vm.expectRevert();
        vm.resumeGasMetering();
        invoker.execute{ value: 0.5 ether }(authrty, n, transactions, v, r, s);
    }

    // fails if too much value to pass to sub-call
    function test_tooMuchValue() public {
        vm.pauseGasMetering();
        (uint8 v, bytes32 r, bytes32 s, bytes memory transactions) = constructAndSignTransaction(1 ether);
        address authrty = authority.addr;
        uint256 n = nonce;
        vm.expectRevert(abi.encodeWithSelector(BatchInvoker.ExtraValue.selector));
        vm.resumeGasMetering();
        invoker.execute{ value: 2 ether }(authrty, n, transactions, v, r, s);
    }

    // TODO: if subcall reverts, it reverts with the right return data (bubbles up the error)
}
