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
    /// @param nonce - see `execute` docs
    /// @param gas - see `execute` docs
    /// @param value - see `execute` docs
    /// @param to - see `execute` docs
    /// @param data - see `execute` docs
    /// @return digest - the payload that the authority should sign
    ///         in order to authorize the transactions using AUTHCALL
    function getDigest(uint256 nonce, uint256 gas, uint256 value, address to, bytes memory data) external view returns (bytes32 digest) {
        digest = getDigest(getCommit(nonce, gas, value, to, data));
    }

    /// @notice produce a hashed commitment to an Batch to be executed using AUTHCALL
    /// @param nonce - see `execute` docs
    /// @param gas - see `execute` docs
    /// @param value - see `execute` docs
    /// @param to - see `execute` docs
    /// @param data - see `execute` docs
    /// @return commit - commitment to the batch of transactions
    /// @dev commit is a security-critical parameter to the signed digest for `auth`
    function getCommit(uint256 nonce, uint256 gas, uint256 value, address to, bytes memory data) public pure returns (bytes32 commit) {
        commit = keccak256(abi.encodePacked(nonce, gas, value, to, data));
    }

    /// @notice execute a Batch of Calls on behalf of a signing authority using AUTH and AUTHCALL
    /// @param authority - the signer authorizing the AUTHCALL
    /// @param nonce - unique sequential identifier for this transaction
    /// @param gas - gas limit for both the `auth` and `authcall` executions
    /// @param value - the value to transfer from the authority to `to`
    /// @param to - the address to make the call to
    /// @param data - the input data to send to `to`
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
