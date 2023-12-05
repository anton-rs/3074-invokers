// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { SimpleAuth } from "./SimpleAuth.sol";

/// @title Auth
/// @author Anna Carroll <https://github.com/anna-carroll/3074>
abstract contract Auth is SimpleAuth {
    /// @notice magic byte to disambiguate EIP-3074 signature payloads
    uint8 constant MAGIC = 0x04;

    /// @notice Thrown when the `AUTH` opcode fails due to invalid signature.
    /// @dev Selector 0xd386ef3e.
    error BadAuth();

    /// @notice helper to produce a digest for the authorizer to sign
    /// @param commit - any 32-byte value used to commit to transaction validity conditions
    /// @return digest - sign the `digest` to authorize the invoker to execute the `calls`
    /// @dev signing this digest authorizes address(this) to execute code on behalf of the signer
    ///      the logic of address(this) should encode rules which respect the information within `commit`
    /// @dev the authorizer includes `commit` in their signature to ensure the authorized contract will only execute intended actions(s).
    ///      the Invoker logic MUST implement constraints on the contract execution based on information in the `commit`;
    ///      otherwise, any EOA that signs an AUTH for the Invoker will be compromised
    /// @dev per EIP-3074, digest = keccak256(MAGIC || chainId || paddedInvokerAddress || commit)
    function getDigest(bytes32 commit) public view returns (bytes32 digest) {
        // address(this) is the contract that will execute the AUTH. cast it to left-padded 32 bytes.
        bytes32 paddedInvokerAddress = bytes32(uint256(uint160(address(this))));
        digest = keccak256(abi.encodePacked(MAGIC, bytes32(block.chainid), paddedInvokerAddress, commit));
    }

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
