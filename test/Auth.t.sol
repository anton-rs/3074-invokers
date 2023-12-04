// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Test, console2 } from "forge-std/Test.sol";
import { VmSafe } from "forge-std/Vm.sol";
import { Auth } from "../src/Auth.sol";

contract AuthHarness is Auth {
    function authHarness(bytes32 commit, uint8 v, bytes32 r, bytes32 s) external view returns (address authority) {
        return auth(commit, v, r, s);
    }

    function authCallHarness(address to, bytes memory data, uint256 value, uint256 gasLimit) external {
        authCall(to, data, value, gasLimit);
    }
}

contract AuthTest is Test {
    AuthHarness public target;

    function setUp() public {
        target = new AuthHarness();
        authority = vm.createWallet("authority");
        vm.label(address(target), "auth");
        vm.label(authority.addr, "authority");
    }

    // auth succeeds and returns correct signer
    function testAuth() external {
        bytes32 commit = keccak256("eip-3074 4ever");
        bytes32 digest = target.getDigest(commit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(authority.privateKey, digest);
        address recovered = target.authHarness(commit, v, r, s);
        assertEq(recovered, authority.addr);
    }

    // fuzz: auth succeeds and returns correct signer
    function testFuzz_Auth(bytes32 commit, uint256 privateKey) external {
        bytes32 digest = target.getDigest(commit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        address recovered = target.authHarness(commit, v, r, s);
        assertEq(recovered, vm.addr(privateKey));
    }

    // auth fails if you pass the wrong commit for the signature
    function testAuth() external {
        bytes32 commit = keccak256("eip-3074 4ever");
        bytes32 wrongCommit = keccak256("abstraction h8er");
        bytes32 digest = target.getDigest(commit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(authority.privateKey, digest);
        vm.expectRevert(abi.encodeWithSelector(Auth.BadAuth.selector));
        target.authHarness(wrongCommit, v, r, s);
    }

    // authcall without auth reverts
    function testAuthCall() external {
        vm.expectRevert();
        authCall(address(0), "0x", 0, 0);
    }
}
