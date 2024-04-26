// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Test, console2 } from "forge-std/Test.sol";
import { VmSafe } from "forge-std/Vm.sol";
import { Auth } from "../src/Auth.sol";
import { BatchInvoker } from "../src/BatchInvoker.sol";
import { BaseInvoker } from "../src/BaseInvoker.sol";
import { vToYParity } from "./utils.sol";

contract Callee {
    error UnexpectedSender(address expected, address actual);

    mapping(address => uint256) public counter;
    mapping(address => uint256) public values;

    function increment() public payable {
        counter[msg.sender] += 1;
        values[msg.sender] += msg.value;
    }

    function expectSender(address expected) public payable {
        if (msg.sender != expected) revert UnexpectedSender(expected, msg.sender);
    }
}

contract BatchInvokerTest is Test {
    Callee public callee;
    BatchInvoker public invoker;
    VmSafe.Wallet public authority;
    VmSafe.Wallet public recipient;

    uint8 AUTHCALL_IDENTIFIER = 2;

    function setUp() public {
        invoker = new BatchInvoker();
        callee = new Callee();
        authority = vm.createWallet("authority");
        recipient = vm.createWallet("recipient");
        vm.label(address(invoker), "invoker");
        vm.label(address(callee), "callee");
        vm.label(authority.addr, "authority");
    }

    function test_execute_withData() external {
        vm.pauseGasMetering();
        uint256 nonce = invoker.nextNonce(authority.addr);

        bytes memory data = abi.encodeWithSelector(Callee.increment.selector);
        bytes memory calls;
        calls = abi.encodePacked(AUTHCALL_IDENTIFIER, address(callee), uint256(0), data.length, data);
        calls = abi.encodePacked(calls, AUTHCALL_IDENTIFIER, address(callee), uint256(0), data.length, data);
        calls = abi.encodePacked(calls, AUTHCALL_IDENTIFIER, address(callee), uint256(0), data.length, data);
        bytes memory execData = abi.encode(nonce, calls);

        bytes32 hash = invoker.getDigest(execData, vm.getNonce(address(authority.addr)));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(authority.privateKey, hash);

        vm.resumeGasMetering();
        invoker.execute(execData, Auth.Signature({ signer: authority.addr, yParity: vToYParity(v), r: r, s: s }));

        assertEq(callee.counter(authority.addr), 3);
        assertEq(callee.values(authority.addr), 0);
    }

    function test_execute_withValue() external {
        vm.pauseGasMetering();

        vm.deal(authority.addr, 1 ether);

        uint256 nonce = invoker.nextNonce(authority.addr);

        bytes memory calls;
        calls = abi.encodePacked(AUTHCALL_IDENTIFIER, address(recipient.addr), uint256(0.5 ether), uint256(0));
        calls = abi.encodePacked(calls, AUTHCALL_IDENTIFIER, address(recipient.addr), uint256(0.5 ether), uint256(0));
        bytes memory execData = abi.encode(nonce, calls);

        bytes32 hash = invoker.getDigest(execData, vm.getNonce(address(authority.addr)));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(authority.privateKey, hash);

        vm.resumeGasMetering();
        invoker.execute(execData, Auth.Signature({ signer: authority.addr, yParity: vToYParity(v), r: r, s: s }));

        assertEq(address(authority.addr).balance, 0 ether);
        assertEq(address(recipient.addr).balance, 1 ether);
    }

    function test_execute_withDataAndValue() external {
        vm.pauseGasMetering();

        vm.deal(authority.addr, 6 ether);

        uint256 nonce = invoker.nextNonce(authority.addr);

        bytes memory data = abi.encodeWithSelector(Callee.increment.selector);
        bytes memory calls;
        calls = abi.encodePacked(AUTHCALL_IDENTIFIER, address(callee), uint256(1 ether), data.length, data);
        calls = abi.encodePacked(calls, AUTHCALL_IDENTIFIER, address(callee), uint256(2 ether), data.length, data);
        calls = abi.encodePacked(calls, AUTHCALL_IDENTIFIER, address(callee), uint256(3 ether), data.length, data);
        bytes memory execData = abi.encode(nonce, calls);

        bytes32 hash = invoker.getDigest(execData, vm.getNonce(address(authority.addr)));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(authority.privateKey, hash);

        vm.resumeGasMetering();
        invoker.execute(execData, Auth.Signature({ signer: authority.addr, yParity: vToYParity(v), r: r, s: s }));

        assertEq(callee.counter(authority.addr), 3);
        assertEq(callee.values(authority.addr), 6 ether);
    }

    function test_execute_broadcastAsAuthority() external {
        vm.pauseGasMetering();

        vm.deal(authority.addr, 1 ether);

        uint256 nonce = invoker.nextNonce(authority.addr);

        bytes memory calls;
        calls = abi.encodePacked(AUTHCALL_IDENTIFIER, address(recipient.addr), uint256(0.5 ether), uint256(0));
        calls = abi.encodePacked(calls, AUTHCALL_IDENTIFIER, address(recipient.addr), uint256(0.5 ether), uint256(0));
        bytes memory execData = abi.encode(nonce, calls);

        // increment nonce by 1 as VM will consume a nonce for the AUTHCALL.
        bytes32 hash = invoker.getDigest(execData, vm.getNonce(address(authority.addr)) + 1);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(authority.privateKey, hash);

        // authority is the broadcaster.
        vm.broadcast(authority.addr);
        vm.resumeGasMetering();
        invoker.execute(execData, Auth.Signature({ signer: authority.addr, yParity: vToYParity(v), r: r, s: s }));

        assertEq(address(authority.addr).balance, 0 ether);
        assertEq(address(recipient.addr).balance, 1 ether);
    }

    function test_execute_revert_invalidSender() external {
        vm.pauseGasMetering();

        uint256 nonce = invoker.nextNonce(authority.addr);

        bytes memory data_1 = abi.encodeWithSelector(Callee.increment.selector);
        bytes memory data_2 = abi.encodeWithSelector(Callee.expectSender.selector, address(0));

        bytes memory calls;
        calls = abi.encodePacked(AUTHCALL_IDENTIFIER, address(callee), uint256(0), data_1.length, data_1);
        calls = abi.encodePacked(calls, AUTHCALL_IDENTIFIER, address(callee), uint256(0), data_2.length, data_2);
        bytes memory execData = abi.encode(nonce, calls);

        bytes32 hash = invoker.getDigest(execData, vm.getNonce(address(authority.addr)));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(authority.privateKey, hash);

        vm.expectRevert(abi.encodeWithSelector(Callee.UnexpectedSender.selector, address(0), address(authority.addr)));
        vm.resumeGasMetering();
        invoker.execute(execData, Auth.Signature({ signer: authority.addr, yParity: vToYParity(v), r: r, s: s }));

        assertEq(callee.counter(authority.addr), 0);
    }

    function test_execute_revert_revoke() external {
        vm.pauseGasMetering();
        vm.deal(authority.addr, 1 ether);

        bytes memory calls;
        calls = abi.encodePacked(AUTHCALL_IDENTIFIER, recipient.addr, uint256(0.5 ether), uint256(0));
        calls = abi.encodePacked(calls, AUTHCALL_IDENTIFIER, recipient.addr, uint256(0.5 ether), uint256(0));

        uint256 nonce = invoker.nextNonce(authority.addr);
        bytes memory execData = abi.encode(nonce, calls);

        bytes32 hash = invoker.getDigest(execData, vm.getNonce(address(authority.addr)));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(authority.privateKey, hash);

        // revoke by setting nonce
        vm.setNonce(address(authority.addr), vm.getNonce(address(authority.addr)) + 1);

        vm.expectRevert(Auth.BadAuth.selector);
        vm.resumeGasMetering();
        invoker.execute(execData, Auth.Signature({ signer: authority.addr, yParity: vToYParity(v), r: r, s: s }));
    }

    function test_execute_revert_invalidNonce() external {
        vm.pauseGasMetering();
        vm.deal(authority.addr, 1 ether);

        bytes memory calls;
        calls = abi.encodePacked(AUTHCALL_IDENTIFIER, recipient.addr, uint256(0.5 ether), uint256(0));
        calls = abi.encodePacked(calls, AUTHCALL_IDENTIFIER, recipient.addr, uint256(0.5 ether), uint256(0));

        uint256 nonce = invoker.nextNonce(authority.addr);
        bytes memory execData = abi.encode(nonce, calls);

        bytes32 hash = invoker.getDigest(execData, vm.getNonce(address(authority.addr)));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(authority.privateKey, hash);

        vm.resumeGasMetering();
        invoker.execute(execData, Auth.Signature({ signer: authority.addr, yParity: vToYParity(v), r: r, s: s }));

        assertEq(address(authority.addr).balance, 0 ether);
        assertEq(address(recipient.addr).balance, 1 ether);

        vm.expectRevert(abi.encodeWithSelector(BatchInvoker.InvalidNonce.selector, address(authority.addr), nonce));
        invoker.execute(execData, Auth.Signature({ signer: authority.addr, yParity: vToYParity(v), r: r, s: s }));

        assertEq(address(authority.addr).balance, 0 ether);
        assertEq(address(recipient.addr).balance, 1 ether);
    }
}
