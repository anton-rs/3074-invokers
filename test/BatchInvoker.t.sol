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
    BatchInvoker.Batch public batch;
    VmSafe.Wallet public authority;

    function setUp() public {
        invoker = new BatchInvoker();
        callee = new Callee();
        authority = vm.createWallet("authority");
        vm.label(address(invoker), "invoker");
        vm.label(address(callee), "callee");
        vm.label(authority.addr, "authority");
    }

    function constructAndSignBatch(uint256 nonce, uint256 value) internal returns (uint8 v, bytes32 r, bytes32 s) {
        batch.nonce = nonce;
        batch.calls.push(
            BatchInvoker.Call({
                to: address(callee),
                data: abi.encodeWithSelector(Callee.expectSender.selector, address(authority.addr)),
                value: value,
                gasLimit: 10_000
            })
        );
        // construct batch digest & sign
        bytes32 digest = invoker.getDigest(batch);
        (v, r, s) = vm.sign(authority.privateKey, digest);
    }

    function test_authCall() public {
        (uint8 v, bytes32 r, bytes32 s) = constructAndSignBatch(0, 0);
        // this will call Callee.expectSender(authority)
        invoker.execute(batch, v, r, s);
    }

    // invalid nonce fails
    function test_invalidNonce() public {
        // 1 is invalid starting nonce
        (uint8 v, bytes32 r, bytes32 s) = constructAndSignBatch(1, 0);
        vm.expectRevert(abi.encodeWithSelector(BatchInvoker.InvalidNonce.selector, authority.addr, 0, 1));
        invoker.execute(batch, v, r, s);
    }

    function test_authCallWithValue() public {
        (uint8 v, bytes32 r, bytes32 s) = constructAndSignBatch(0, 1 ether);
        // this will call Callee.expectSender(authority)
        invoker.execute{ value: 1 ether }(batch, v, r, s);
    }

    // fails if too little value to pass to sub-call
    function test_tooLittleValue() public {
        (uint8 v, bytes32 r, bytes32 s) = constructAndSignBatch(0, 1 ether);
        vm.expectRevert();
        invoker.execute{ value: 0.5 ether }(batch, v, r, s);
    }

    // fails if too much value to pass to sub-call
    function test_tooMuchValue() public {
        (uint8 v, bytes32 r, bytes32 s) = constructAndSignBatch(0, 1 ether);
        vm.expectRevert(abi.encodeWithSelector(BatchInvoker.ExtraValue.selector));
        invoker.execute{ value: 2 ether }(batch, v, r, s);
    }

    // TODO: test that auth returns authority address
}
