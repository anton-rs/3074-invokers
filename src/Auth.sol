// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.20;

/// @title Auth
/// @author Anna Carroll <https://github.com/anna-carroll/3074>
/// @author Jake Moxey <https://github.com/jxom>
/// @notice Utils for EIP-3074 AUTH & AUTHCALL opcodes.
contract Auth {
    uint8 constant MAGIC = 0x04;

    /// @notice Thrown when the `AUTH` opcode fails due to invalid signature.
    /// @dev Selector 0xd386ef3e.
    error BadAuth();

    struct Signature {
        address signer;
        uint8 yParity;
        bytes32 r;
        bytes32 s;
    }

    /// @notice produce a digest for the authorizer to sign
    /// @param commit - any 32-byte value used to commit to transaction validity conditions
    /// @return digest - sign the `digest` to authorize the invoker to execute the `calls`
    /// @dev signing `digest` authorizes this contact to execute code on behalf of the signer
    ///      the logic of the inheriting contract should encode rules which respect the information within `commit`
    /// @dev the authorizer includes `commit` in their signature to ensure the authorized contract will only execute intended actions(s).
    ///      the Invoker logic MUST implement constraints on the contract execution based on information in the `commit`;
    ///      otherwise, any EOA that signs an AUTH for the Invoker will be compromised
    /// @dev per EIP-3074, digest = keccak256(MAGIC || chainId || paddedInvokerAddress || commit)
    function getDigest(bytes32 commit, uint256 nonce) public view returns (bytes32) {
        bytes32 chainId = bytes32(block.chainid);
        bytes32 invokerAddress = bytes32(uint256(uint160(address(this))));
        return keccak256(abi.encodePacked(MAGIC, chainId, nonce, invokerAddress, commit));
    }

    /// @notice call AUTH opcode with a given a commitment + signature
    /// @param commit - any 32-byte value used to commit to transaction validity conditions
    /// @param signature - The signature of the auth message.
    /// @dev signature values (yParity, r, s) are interpreted as an ECDSA signature on the secp256k1 curve over getDigest(commit).
    /// @return success - True if the authorization is successful.
    /// @custom:reverts BadAuth() if AUTH fails due to invalid signature.
    function auth(bytes32 commit, Signature memory signature) public returns (bool success) {
        bytes memory args = abi.encodePacked(signature.yParity, signature.r, signature.s, commit);
        address authority = signature.signer;
        assembly {
            success := auth(authority, add(args, 0x20), mload(args))
        }
        if (!success) revert BadAuth();
    }

    /// @notice call AUTHCALL opcode with given call instructions
    /// @dev MUST call AUTH before attempting to AUTHCALL
    /// @return success - True if the authorization is successful.
    /// @custom:reverts with the sub-call revert data if the AUTHCALL fails
    function authcall(address to, bytes memory data, uint256 value, uint256 gasLimit) public returns (bool success) {
        assembly {
            success := authcall(gasLimit, to, value, add(data, 0x20), mload(data), 0, 0)
            if iszero(success) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
    }
}
