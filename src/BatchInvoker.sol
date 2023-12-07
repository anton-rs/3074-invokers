// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { BaseInvoker } from "src/BaseInvoker.sol";
import { MultiSendAuthCallOnly } from "src/MultiSendAuthCallOnly.sol";

/// @title BatchInvoker
/// @author Anna Carroll <https://github.com/anna-carroll/3074>
/// @notice Example EIP-3074 Invoker contract which executes a batch of calls using AUTH and AUTHCALL.
///         BatchInvoker enables multi-transaction flows for EOAs,
///         such as performing an ERC-20 approve & transfer with just one signature.
///         It also natively enables gas sponsored transactions.
/// @dev batches are executed in sequence based on their nonce;
///      each calls within the batch is executed in sequence based on the order it is included in the array;
///      calls are executed non-interactively (return data from one call is not passed into the next);
///      batches are executed atomically (if one sub-call reverts, the whole batch reverts)
contract BatchInvoker is BaseInvoker, MultiSendAuthCallOnly {
    /// @notice authority => next valid nonce
    mapping(address => uint256) public nextNonce;

    /// @notice thrown when a Batch is executed with an invalid nonce
    /// @param authority - the signing authority
    /// @param attempted - the attempted, invalid nonce
    error InvalidNonce(address authority, uint256 attempted);

    /// @notice execute a Batch of transactions on behalf of a signing authority using AUTH and AUTHCALL
    /// @param execData - packed bytes containing:
    ///        `nonce` - as a uint256 (=> 32 bytes)
    ///        `transactionsLength` - as a uint256 (=> 32 bytes),
    ///        `transactions` - Encoded transactions.
    ///           Each transaction is encoded as a packed bytes of:
    ///           `operation` as a uint8 (=> 1 byte) - MUST equal uint8(2) for AUTHCALL
    ///           `to` as an address (=> 20 bytes),
    ///           `value` as a uint256 (=> 32 bytes),
    ///           `dataLength` as a uint256 (=> 32 bytes),
    ///           `data` as bytes.
    function exec(address authority, bytes memory execData) internal override {
        (uint256 nonce, bytes memory transactions) = unpack(execData);
        // validate the nonce & increment
        if (nonce != nextNonce[authority]++) revert InvalidNonce(authority, nonce);
        // multiSend the transactions using AUTHCALL
        multiSend(transactions);
    }

    /// @notice helper to unpack execData
    function unpack(bytes memory execData) private pure returns (uint256 nonce, bytes memory transactions) {
        assembly {
            // Offset: 32 bytes (32 byte pointer length)
            // Length: 32 bytes.
            nonce := mload(add(execData, 0x20))
            // Offset: 64 bytes (32 byte pointer length + 32 byte uint256)
            transactions := add(execData, 0x40)
        }
    }
}
