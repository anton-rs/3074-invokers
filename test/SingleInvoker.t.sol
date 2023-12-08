// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Test, console2 } from "forge-std/Test.sol";
import { VmSafe } from "forge-std/Vm.sol";
import { SingleInvoker } from "../src/SingleInvoker.sol";

contract SomeContractToBeCalled {
  error SumIncorrect();

  uint8 public correctAnswers = 0;

  function twoPlusTwoEquals(uint256 sum) public payable {
    if (2 + 2 + sum != 8) revert SumIncorrect();

    correctAnswers += 1;
  }
}

contract SingleInvokerTest is Test {
    uint256 public nonce;
    uint256 public gas;

    SingleInvoker public invoker;
    VmSafe.Wallet public authority;
    SomeContractToBeCalled public someContract;

    function setUp() public {
        nonce = 0;
        gas = 0;

        invoker = new SingleInvoker();
        authority = vm.createWallet("authority");
        someContract = new SomeContractToBeCalled();

        vm.label(address(invoker), "invoker");
        vm.label(authority.addr, "authority");
        vm.label(address(someContract), "someContract");
    }

    function constructAndSignTransaction(uint256 value, bytes memory data) internal returns (uint8 v, bytes32 r, bytes32 s) {
        bytes32 digest = invoker.getDigest(nonce, gas, value, address(someContract), data);
        (v, r, s) = vm.sign(authority.privateKey, digest);
    }

    function test_authCallSuccess() public {
        bytes memory data = abi.encodeWithSelector(someContract.twoPlusTwoEquals.selector, 4);
        (uint8 v, bytes32 r, bytes32 s) = constructAndSignTransaction(0, data);

        invoker.execute(authority.addr, nonce, gas, 0, address(someContract), data, v, r, s);

        assertTrue(someContract.correctAnswers() == 1);
    }

    function test_authCallFail_SumIncorrect() public {
        bytes memory data = abi.encodeWithSelector(someContract.twoPlusTwoEquals.selector, 5);
        (uint8 v, bytes32 r, bytes32 s) = constructAndSignTransaction(0, data);

        vm.expectRevert(SomeContractToBeCalled.SumIncorrect.selector);
        invoker.execute(authority.addr, nonce, gas, 0, address(someContract), data, v, r, s);
    }
}
