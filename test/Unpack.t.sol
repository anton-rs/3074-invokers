// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { VmSafe } from "forge-std/Vm.sol";

contract UnpackHarness {
    // Copy/pasted from Invoker
    function unpackAuth(bytes memory authData)
        external
        pure
        returns (address authority, uint8 v, bytes32 r, bytes32 s)
    {
        assembly {
            // first 32-byte word of memory at the variable "authData" is the length of authData. the actual data is 32 bytes later.
            let lengthOffset := 0x20
            // Offset: 32 bytes (32 byte pointer length)
            // Length: 20 bytes.
            //         Shift by 96 bits (256 bits - 160 bits [20 bytes]) since mload loads 32 bytes (a word).
            authority := shr(0x60, mload(add(authData, 0x20)))
            // Offset: 52 bytes (32 byte pointer length + 20 bytes address)
            // Length: 1 byte.
            //         Shift by 248 bits (256 bits - 8 bits [1 byte]) since mload loads 32 bytes (a word).
            v := shr(0xf8, mload(add(authData, 0x34)))
            // Offset: 53 bytes (32 byte pointer length + 20 bytes address + 1 byte v)
            // Length: 32 bytes.
            r := mload(add(authData, 0x35))
            // Offset: 85 bytes (32 byte pointer length + 20 bytes address + 1 byte v + 32 bytes r)
            // Length: 32 bytes.
            s := mload(add(authData, 0x55))
        }
    }

    // Copy/pasted from BatchInvoker
    function unpackExec(bytes memory execData) external pure returns (uint256 nonce, bytes memory transactions) {
        assembly {
            nonce := mload(add(execData, 0x20))
            transactions := add(execData, 0x40)
        }
    }
}

contract BatchInvokerTest is Test {
    VmSafe.Wallet public authority;
    uint8 AUTHCALL_IDENTIFIER = 2;

    function setUp() public {
        authority = vm.createWallet("authority");
        vm.label(authority.addr, "authority");
    }

    function test_unpack() public {
        // sign random commit to make some authdata
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(authority.privateKey, keccak256("hi"));
        bytes memory authData = abi.encodePacked(authority.addr, v, r, s);
        // unpack the packed authdata
        UnpackHarness harness = new UnpackHarness();
        (address authU, uint8 vU, bytes32 rU, bytes32 sU) = harness.unpackAuth(authData);
        // assert unpacked data matches expected
        assertEq(authority.addr, authU);
        assertEq(v, vU);
        assertEq(r, rU);
        assertEq(s, sU);
    }

    function test_unpackExec() public {
        // pack an example transaction call
        uint256 nonce = 0;
        uint256 value = 0;
        bytes memory data =
            abi.encodeWithSelector(UnpackHarness.unpackAuth.selector, abi.encodePacked(address(authority.addr)));
        bytes memory transactions = abi.encodePacked(AUTHCALL_IDENTIFIER, address(this), value, data.length, data);
        bytes memory execData = abi.encodePacked(nonce, transactions.length, transactions);
        // unpack the packed data
        UnpackHarness harness = new UnpackHarness();
        (uint256 n, bytes memory t) = harness.unpackExec(execData);
        // expect the unpacked matches
        assertEq(nonce, n);
        assertEq(transactions, t);
    }
}
