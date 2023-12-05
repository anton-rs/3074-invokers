// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Test, console2 } from "forge-std/Test.sol";
import { VmSafe } from "forge-std/Vm.sol";
import { Auth } from "../src/Auth.sol";

contract AuthHarness is Auth {
    function authHarness(address authority, bytes32 commit, uint8 v, bytes32 r, bytes32 s) external {
        auth(authority, commit, v, r, s);
    }

    function authSimpleHarness(address authority, bytes32 commit, uint8 v, bytes32 r, bytes32 s)
        external
        returns (bool success)
    {
        return authSimple(authority, commit, v, r, s);
    }

    function authCallHarness(address to, bytes memory data, uint256 value, uint256 gasLimit)
        external
    {
        authCall(to, data, value, gasLimit);
    }
}

contract AuthTest is Test {
    AuthHarness public target;
    VmSafe.Wallet public authority;

    function setUp() public {
        target = new AuthHarness();
        authority = vm.createWallet("authority");
        vm.label(address(target), "auth");
        vm.label(authority.addr, "authority");
    }

    // auth succeeds
    function test_auth_success() external {
        bytes32 commit = keccak256("eip-3074 4ever");
        bytes32 digest = target.getDigest(commit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(authority.privateKey, digest);
        bool success = target.authSimpleHarness(authority.addr, commit, v, r, s);
        assertTrue(success);
    }

    // auth fails if you pass the wrong commit for the signature
    function test_authSimple_fail() external {
        // sign digest for `commit`
        bytes32 commit = keccak256("eip-3074 4ever");
        bytes32 digest = target.getDigest(commit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(authority.privateKey, digest);
        // pass `wrongCommit` with signature over `commit`
        bytes32 wrongCommit = keccak256("abstraction h8er");
        assertFalse(target.authSimpleHarness(authority.addr, wrongCommit, v, r, s));
    }

    // fuzz: auth succeeds
    function testFuzz_authSimple_success(bytes32 commit, uint256 privateKey) external {
        vm.assume(
            privateKey > 0
                && privateKey < 115792089237316195423570985008687907852837564279074904382605163141518161494337
        );
        bytes32 digest = target.getDigest(commit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        address authrty = vm.addr(privateKey);
        bool success = target.authSimpleHarness(authrty, commit, v, r, s);
        assertTrue(success);
    }

    // auth fails if you pass the wrong commit for the signature
    function test_auth_BadAuth() external {
        // sign digest for `commit`
        bytes32 commit = keccak256("eip-3074 4ever");
        bytes32 digest = target.getDigest(commit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(authority.privateKey, digest);
        // pass `wrongCommit` with signature over `commit`
        bytes32 wrongCommit = keccak256("abstraction h8er");
        vm.expectRevert(abi.encodeWithSelector(Auth.BadAuth.selector));
        target.authHarness(authority.addr, wrongCommit, v, r, s);
    }

    // authcall without auth reverts
    function test_authCall_withoutAuth() external {
        vm.expectRevert();
        target.authCallHarness(address(0), "0x", 0, 0);
    }

    // TODO: authCall failure - throws revert data
}
