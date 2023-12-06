// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Auth } from "src/Auth.sol";
import { MultiSendAuthCallOnly } from "src/MultiSendAuthCallOnly.sol";

/// @title BatchInvoker
/// @author Anna Carroll <https://github.com/anna-carroll/3074>
/// @notice Example EIP-3074 Invoker contract which executes a batch of calls using AUTH and AUTHCALL.
/// @dev batches are executed in sequence based on their nonce;
///      each calls within the batch is executed in sequence based on the order it is included in the array;
///      calls are executed non-interactively (return data from one call is not passed into the next);
///      batches are executed atomically (if one sub-call reverts, the whole batch reverts)
/// @dev BatchInvoker enables multi-transaction flows for EOAs,
///      such as performing an ERC-20 approve & transfer with just one signature.
///      It also natively enables gas sponsored transactions.
contract BatchInvoker is Auth, MultiSendAuthCallOnly {
    /// @notice authority => next valid nonce
    mapping(address => uint256) public nextNonce;

    /// @notice thrown when a Batch is executed with an invalid nonce
    /// @param authority - the signing authority
    /// @param attempted - the attempted, invalid nonce
    error InvalidNonce(address authority, uint256 attempted);

    /// @notice thrown when a Batch is executed with a larger `msg.value` than the sum of each sub-call's `value`
    error ExtraValue();

    /// @notice produce a digest to sign that authorizes this contract
    ///         to execute the transactions using AUTHCALL
    /// @param nonce - see `execute` docs
    /// @param transactions - see `execute` docs
    /// @return digest - the payload that the authority should sign
    ///         in order to authorize the transactions using AUTHCALL
    function getDigest(uint256 nonce, bytes memory transactions) external view returns (bytes32 digest) {
        digest = getDigest(getCommit(nonce, transactions));
    }

    /// @notice produce a hashed commitment to an Batch to be executed using AUTHCALL
    /// @param nonce - see `execute` docs
    /// @param transactions - see `execute` docs
    /// @return commit - commitment to the batch of transactions
    /// @dev commit is a security-critical parameter to the signed digest for `auth`
    function getCommit(uint256 nonce, bytes memory transactions) public pure returns (bytes32 commit) {
        commit = keccak256(abi.encodePacked(nonce, transactions));
    }

    /// @notice execute a Batch of Calls on behalf of a signing authority using AUTH and AUTHCALL
    /// @param authority - the signer authorizing the AUTHCALL
    /// @param nonce - unique sequential identifier for the bath of transactions
    /// @param transactions Encoded transactions. Each transaction is encoded as a packed bytes of
    ///        `operation` has to be uint8(2) in this version (=> 1 byte),
    ///        `to` as a address (=> 20 bytes),
    ///        `value` as a uint256 (=> 32 bytes),
    ///        `data length` as a uint256 (=> 32 bytes),
    ///        `data` as bytes.
    /// @dev (v, r, s) are interpreted as an ECDSA signature on the secp256k1 curve over getDigest(batch)
    function execute(address authority, uint256 nonce, bytes memory transactions, uint8 v, bytes32 r, bytes32 s)
        public
        payable
    {
        // validate the nonce & increment
        if (nonce != nextNonce[authority]++) revert InvalidNonce(authority, nonce);
        // AUTH this contract to execute the Batch on behalf of the authority
        auth(authority, getCommit(nonce, transactions), v, r, s);
        // multiSend the transactions using AUTHCALL
        multiSend(transactions);
        // ensure that all value passed to the transaction was passed on to sub-calls (no leftover value in BatchInvoker contract)
        if (address(this).balance != 0) revert ExtraValue();
    }
}
