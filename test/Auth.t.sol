// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Test, console2 } from "forge-std/Test.sol";
import { VmSafe } from "forge-std/Vm.sol";
import { Auth } from "../src/Auth.sol";

contract AuthHarness is Auth {
    function authHarness(address authority, bytes32 commit, uint8 v, bytes32 r, bytes32 s) external {
        auth(authority, commit, v, r, s);
    }

    function authCallHarness(address to, bytes memory data, uint256 value, uint256 gasLimit) external {
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

    // auth succeeds and returns correct signer
    function testAuth() external {
        bytes32 commit = keccak256("eip-3074 4ever");
        bytes32 digest = target.getDigest(commit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(authority.privateKey, digest);
        target.authHarness(authority.addr, commit, v, r, s);
    }

    // fuzz: auth succeeds and returns correct signer
    function testFuzz_Auth(bytes32 commit, uint256 privateKey) external {
        vm.assume(
            privateKey > 0
                && privateKey < 115792089237316195423570985008687907852837564279074904382605163141518161494337
        );
        bytes32 digest = target.getDigest(commit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        address authrty = vm.addr(privateKey);
        target.authHarness(authrty, commit, v, r, s);
    }

    // auth fails if you pass the wrong commit for the signature
    function testBadAuth() external {
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
    function testAuthCall() external {
        vm.expectRevert();
        target.authCallHarness(address(0), "0x", 0, 0);
    }
}
