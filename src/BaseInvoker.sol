// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Auth } from "src/Auth.sol";
import { MultiSendAuthCallOnly } from "src/MultiSendAuthCallOnly.sol";

/// @title BaseInvoker
/// @author Anna Carroll <https://github.com/anna-carroll/3074>
/// @notice Shared functionality for Invoker contracts to efficiently AUTH a signer, then execute arbitrary application logic.
/// @dev To implement an Invoker contract, simply inherit BaseInvoker and override the exec function with your Invoker logic.
abstract contract BaseInvoker is Auth {
    /// @notice thrown when `execute` finishes with leftover value in the Invoker contract, which is unsafe as it could be spent by anyone
    error ExtraValue();

    /// @notice produce a digest to sign that authorizes the invoker
    ///         to execute actions using AUTHCALL
    /// @param execData - packed bytes containing invoker-specific execution logic
    /// @dev keccak256 hash of execData is used as the commit for AUTH
    /// @return digest - the payload that the authority should sign
    ///         in order to authorize the specific execData using AUTHCALL
    function getDigest(bytes memory execData) external view returns (bytes32 digest) {
        digest = getDigest(keccak256(execData));
    }

    /// @notice execute some action(s) on behalf of a signing authority using AUTH and AUTHCALL
    /// @param authData - packed bytes containing:
    ///        `authority` - 20 bytes addr of signer to AUTH
    ///        `v` - 1 byte signature input
    ///        `r` - 32 byte signature input
    ///        `s` - 32 byte signature input
    /// @param execData - packed bytes containing invoker-specific logic
    function execute(bytes memory authData, bytes memory execData) external payable {
        (address authority, uint8 v, bytes32 r, bytes32 s) = unpackAuth(authData);
        // AUTH this contract to execute the Batch on behalf of the authority
        auth(authority, keccak256(execData), v, r, s);
        // execute Invoker operations, which may use AUTHCALL
        exec(authority, execData);
        // ensure that all value passed to the transaction was passed on to sub-calls (no leftover value in invoker)
        if (address(this).balance != 0) revert ExtraValue();
    }

    /// @notice override `exec` to implement Invoker-specific application logic
    function exec(address authority, bytes memory execData) internal virtual;

    /// @notice helper to unpack authData
    function unpackAuth(bytes memory authData)
        private
        pure
        returns (address authority, uint8 v, bytes32 r, bytes32 s)
    {
        assembly {
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
}
