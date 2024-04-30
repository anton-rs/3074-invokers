// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.20;

import { BaseInvoker } from "src/BaseInvoker.sol";
import { MultiSendAuthCallOnly } from "src/MultiSendAuthCallOnly.sol";

/// @title BatchInvoker
/// @author Anna Carroll <https://github.com/anna-carroll/3074>
/// @author Jake Moxey <https://github.com/jxom>
/// @notice Invoker with batched transaction execution.
contract BatchInvoker is BaseInvoker, MultiSendAuthCallOnly {
    /// @notice authority => next valid nonce
    mapping(address => uint256) public nextNonce;

    /// @notice thrown when a Batch is executed with an invalid nonce
    /// @param authority - the signing authority
    /// @param attempted - the attempted, invalid nonce
    error InvalidNonce(address authority, uint256 attempted);

    /// @notice execute a batch of calls on behalf of a signing authority using AUTH and AUTHCALL
    /// @param execData - abi-encoded:
    ///        `nonce` - ordered identifier for transaction batches
    ///        `transactions` - Packed bytes-encoded transactions per Gnosis Multicall contract.
    ///           Each transaction is encoded as a packed bytes of:
    ///           `operation` as a uint8 (=> 1 byte) - MUST equal uint8(2) for AUTHCALL
    ///           `to` as an address (=> 20 bytes),
    ///           `value` as a uint256 (=> 32 bytes),
    ///           `dataLength` as a uint256 (=> 32 bytes),
    ///           `data` as bytes.
    /// @param signature - Authority's signature over the AUTH digest committing to execData.
    function exec(bytes memory execData, Signature memory signature) internal override {
        (uint256 nonce, bytes memory transactions) = abi.decode(execData, (uint256, bytes));
        // validate the nonce & increment
        if (nonce != nextNonce[signature.signer]++) revert InvalidNonce(signature.signer, nonce);
        // multiSend the transactions using AUTHCALL
        multiSend(transactions);
    }
}
