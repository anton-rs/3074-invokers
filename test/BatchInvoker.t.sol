// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Test, console2 } from "forge-std/Test.sol";
import { VmSafe } from "forge-std/Vm.sol";
import { BatchInvoker } from "../src/BatchInvoker.sol";
import { MockSomeContractToBeCalled } from "./mocks/MockSomeContractToBeCalled.sol";

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
    bytes public transactions;
    VmSafe.Wallet public authority;
    MockSomeContractToBeCalled public someContract;

    function setUp() public {
        invoker = new BatchInvoker();
        callee = new Callee();
        authority = vm.createWallet("authority");
        someContract = new MockSomeContractToBeCalled();
        vm.label(address(invoker), "invoker");
        vm.label(address(callee), "callee");
        vm.label(authority.addr, "authority");
        vm.label(address(someContract), "someContract");
    }

    function constructAndSignTransaction(uint256 value) internal returns (uint8 v, bytes32 r, bytes32 s) {
        bytes memory data = abi.encodeWithSelector(Callee.expectSender.selector, address(authority.addr));
        uint8 identifier = 2;
        transactions = abi.encodePacked(identifier, address(callee), value, data.length, data);
        // construct batch digest & sign
        bytes32 digest = invoker.getDigest(nonce, transactions);
        (v, r, s) = vm.sign(authority.privateKey, digest);
    }

    function test_authCall() public {
        (uint8 v, bytes32 r, bytes32 s) = constructAndSignTransaction(0);
        // this will call Callee.expectSender(authority)
        invoker.execute(authority.addr, nonce, transactions, v, r, s);
    }

    // invalid nonce fails
    function test_invalidNonce() public {
        // 1 is invalid starting nonce
        nonce = 1;
        (uint8 v, bytes32 r, bytes32 s) = constructAndSignTransaction(0);
        vm.expectRevert(abi.encodeWithSelector(BatchInvoker.InvalidNonce.selector, authority.addr, 1));
        invoker.execute(authority.addr, nonce, transactions, v, r, s);
    }

    function test_authCallWithValue() public {
        (uint8 v, bytes32 r, bytes32 s) = constructAndSignTransaction(1 ether);
        // this will call Callee.expectSender(authority)
        invoker.execute{ value: 1 ether }(authority.addr, nonce, transactions, v, r, s);
    }

    // fails if too little value to pass to sub-call
    function test_tooLittleValue() public {
        (uint8 v, bytes32 r, bytes32 s) = constructAndSignTransaction(1 ether);
        vm.expectRevert();
        invoker.execute{ value: 0.5 ether }(authority.addr, nonce, transactions, v, r, s);
    }

    // fails if too much value to pass to sub-call
    function test_tooMuchValue() public {
        (uint8 v, bytes32 r, bytes32 s) = constructAndSignTransaction(1 ether);
        vm.expectRevert(abi.encodeWithSelector(BatchInvoker.ExtraValue.selector));
        invoker.execute{ value: 2 ether }(authority.addr, nonce, transactions, v, r, s);
    }

    // TODO: if subcall reverts, it reverts with the right return data (bubbles up the error)
    function test_subcallRevertWithReturnData() public {}

    // single success authcall gas comparison test versus SingleInvoker
    function test_authCallSuccess() public {
        bytes memory data = abi.encodeWithSelector(someContract.twoPlusTwoEquals.selector, 4);
        uint8 identifier = 2;
        transactions = abi.encodePacked(identifier, address(someContract), uint256(0), data.length, data);
        // construct batch digest & sign
        bytes32 digest = invoker.getDigest(nonce, transactions);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(authority.privateKey, digest);

        invoker.execute(authority.addr, nonce, transactions, v, r, s);

        assertTrue(someContract.correctAnswers() == 1);
    }

    // single reverted authcall gas comparison test versus SingleInvoker
    function test_authCallFail_SumIncorrect() public {
        bytes memory data = abi.encodeWithSelector(someContract.twoPlusTwoEquals.selector, 5);
        uint8 identifier = 2;
        transactions = abi.encodePacked(identifier, address(someContract), uint256(0), data.length, data);
        // construct batch digest & sign
        bytes32 digest = invoker.getDigest(nonce, transactions);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(authority.privateKey, digest);

        vm.expectRevert(MockSomeContractToBeCalled.SumIncorrect.selector);
        invoker.execute(authority.addr, nonce, transactions, v, r, s);
    }

}
