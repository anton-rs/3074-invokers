// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.20;

import { Auth } from "src/Auth.sol";

/// @title BaseInvoker
/// @author Anna Carroll <https://github.com/anna-carroll/3074>
/// @author Jake Moxey <https://github.com/jxom>
/// @notice Invoker contract template.
/// @dev Inherit & override the `exec` function to implement arbitrary Invoker logic.
abstract contract BaseInvoker is Auth {
    /// @notice produce a digest to sign that authorizes the invoker
    ///         to execute actions using AUTHCALL
    /// @param execData - packed bytes containing invoker-specific execution logic
    /// @param nonce - nonce of the authority.
    /// @dev keccak256 hash of execData is used as the commit for AUTH
    /// @return digest - the payload that the authority should sign
    ///         in order to authorize the specific execData using AUTHCALL
    function getDigest(bytes memory execData, uint256 nonce) external view returns (bytes32 digest) {
        digest = getDigest(keccak256(execData), nonce);
    }

    /// @notice execute some action(s) on behalf of a signing authority using AUTH and AUTHCALL
    /// @param execData - arbitrary bytes containing Invoker-specific logic
    /// @param signature - Authority's signature over the AUTH digest.
    function execute(bytes memory execData, Signature memory signature) external {
        // AUTH this contract to execute the Batch on behalf of the authority
        auth(keccak256(execData), signature);
        // execute Invoker operations, which may use AUTHCALL
        exec(execData, signature);
    }

    /// @notice override `exec` to implement Invoker-specific application logic
    function exec(bytes memory execData, Signature memory signature) internal virtual;
}
