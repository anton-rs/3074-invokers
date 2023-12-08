// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Auth } from "src/Auth.sol";

/// @title SingleInvoker
/// @author Julian Rachman <https://github.com/Jrachman>
/// @notice Example EIP-3074 Invoker contract which executes a single call using AUTH and AUTHCALL.
contract SingleInvoker is Auth {
    // TODO: add commit check errors here

    /// @notice produce a digest to sign that authorizes this contract
    ///         to execute the transactions using AUTHCALL
    /// @return digest - the payload that the authority should sign
    ///         in order to authorize the transactions using AUTHCALL
    function getDigest(uint256 nonce, uint256 gas, uint256 value, address to, bytes memory data) external view returns (bytes32 digest) {
        digest = getDigest(getCommit(nonce, gas, value, to, data));
    }

    /// @notice produce a hashed commitment to an Batch to be executed using AUTHCALL
    /// @return commit - commitment to the batch of transactions
    /// @dev commit is a security-critical parameter to the signed digest for `auth`
    function getCommit(uint256 nonce, uint256 gas, uint256 value, address to, bytes memory data) public pure returns (bytes32 commit) {
        commit = keccak256(abi.encodePacked(nonce, gas, value, to, data));
    }

    /// @notice execute a Batch of Calls on behalf of a signing authority using AUTH and AUTHCALL
    /// @dev (v, r, s) are interpreted as an ECDSA signature on the secp256k1 curve over getDigest(batch)
    function execute(address authority, uint256 nonce, uint256 gas, uint256 value, address to, bytes memory data, uint8 v, bytes32 r, bytes32 s)
        public
        payable
    {
        // AUTH this contract to execute the Batch on behalf of the authority
        auth(authority, getCommit(nonce, gas, value, to, data), v, r, s);
        // multiSend the transactions using AUTHCALL
        authCall(to, data, value, gas);
    }
}
