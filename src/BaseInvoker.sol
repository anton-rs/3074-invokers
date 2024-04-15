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
    /// @param nonce - the current transaction nonce of the signing authority
    /// @param execData - packed bytes containing invoker-specific execution logic
    /// @dev keccak256 hash of execData is used as the commit for AUTH
    /// @return digest - the payload that the authority should sign
    ///         in order to authorize the specific execData using AUTHCALL
    function getDigest(uint256 nonce, bytes memory execData) external view returns (bytes32 digest) {
        digest = getDigest(nonce, keccak256(execData));
    }

    /// @notice execute some action(s) on behalf of a signing authority using AUTH and AUTHCALL
    /// @param authority - signer to AUTH
    /// @param v - signature input
    /// @param r - signature input
    /// @param s - signature input
    /// @param execData - arbitrary bytes containing Invoker-specific logic
    function execute(address authority, uint8 v, bytes32 r, bytes32 s, bytes memory execData) external payable {
        // AUTH this contract to execute the Batch on behalf of the authority
        auth(authority, keccak256(execData), v, r, s);
        // execute Invoker operations, which may use AUTHCALL
        exec(authority, execData);
        // ensure that all value passed to the transaction was passed on to sub-calls (no leftover value in invoker)
        if (address(this).balance != 0) revert ExtraValue();
    }

    /// @notice override `exec` to implement Invoker-specific application logic
    function exec(address authority, bytes memory execData) internal virtual;
}
