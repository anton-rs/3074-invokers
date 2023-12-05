// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { BaseAuth } from "./BaseAuth.sol";

/// @title Auth
/// @author Anna Carroll <https://github.com/anna-carroll/3074>
abstract contract Auth is BaseAuth {
    /// @notice Thrown when the `AUTH` opcode fails due to invalid signature.
    /// @dev Selector 0xd386ef3e.
    error BadAuth();

    /// @notice call AUTH opcode with a given a commitment + signature
    /// @param commit - any 32-byte value used to commit to transaction validity conditions
    /// @dev (v, r, s) are interpreted as an ECDSA signature on the secp256k1 curve over getDigest(commit)
    /// @custom:reverts BadAuth() if  AUTH fails due to invalid signature
    function auth(address authority, bytes32 commit, uint8 v, bytes32 r, bytes32 s) internal {
        bool success = authSimple(authority, commit, v, r, s);
        if (!success) revert BadAuth();
    }

    /// @notice call AUTHCALL opcode with given call instructions
    /// @dev MUST call AUTH before attempting to AUTHCALL
    /// @custom:reverts with the sub-call revert data if the AUTHCALL fails
    function authCall(address to, bytes memory data, uint256 value, uint256 gasLimit) internal {
        bool success = authCallSimple(to, data, value, gasLimit);
        assembly {
            if iszero(success) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
    }
}
