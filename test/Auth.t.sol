// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Test, console2 } from "forge-std/Test.sol";
import { VmSafe } from "forge-std/Vm.sol";
import { Auth } from "../src/Auth.sol";
import { vToYParity } from "./utils.sol";

contract AuthTest is Test {
    Auth public target;
    VmSafe.Wallet public authority;

    function setUp() public {
        target = new Auth();
        authority = vm.createWallet("authority");
        vm.label(address(target), "auth");
        vm.label(authority.addr, "authority");
    }

    function test_auth(bytes32 commit) external {
        vm.pauseGasMetering();

        uint64 nonce = vm.getNonce(address(authority.addr));

        bytes32 hash = target.getDigest(commit, nonce);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(authority.privateKey, hash);

        vm.resumeGasMetering();
        bool success = target.auth(authority.addr, commit, Auth.Signature({ yParity: vToYParity(v), r: r, s: s }));
        assertTrue(success);
    }

    function test_auth_revert_invalidCommit(bytes32 commit) external {
        vm.pauseGasMetering();

        uint64 nonce = vm.getNonce(address(authority.addr));

        bytes32 hash = target.getDigest(commit, nonce);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(authority.privateKey, hash);

        bytes32 invalidCommit = keccak256("lol");

        vm.expectRevert(Auth.BadAuth.selector);
        vm.resumeGasMetering();
        target.auth(authority.addr, invalidCommit, Auth.Signature({ yParity: vToYParity(v), r: r, s: s }));
    }

    function test_auth_revert_invalidAuthority(bytes32 commit) external {
        vm.pauseGasMetering();

        uint64 nonce = vm.getNonce(address(authority.addr));

        bytes32 hash = target.getDigest(commit, nonce);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(authority.privateKey, hash);

        address invalidAuthority = address(0);

        vm.expectRevert(Auth.BadAuth.selector);
        vm.resumeGasMetering();
        target.auth(invalidAuthority, commit, Auth.Signature({ yParity: vToYParity(v), r: r, s: s }));
    }

    function test_authCall_revert_noAuth() external {
        vm.expectRevert();
        target.authcall(address(0), "0x", 0, 0);
    }
}
