// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Auth } from "src/Auth.sol";

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
contract BatchInvoker is Auth {
    /// @notice a Batch is an array of calls which will be executed behalf of an authority.
    /// @dev authority signs a commitment to the Batch, enabling it to be executed by the BatchInvoker using AUTHCALL
    struct Batch {
        uint256 nonce;
        Call[] calls;
    }

    /// @notice a Call contains transaction execution information for a single sub-call within a Batch.
    /// @dev The fields are relatively self-explanatory:
    ///      - to - the address to call.
    ///      - data - the encoded calldata passed to the call.
    ///      - value - the ether value forwarded to the call.
    ///      - gasLimit - the gas limit set for the call.
    struct Call {
        address to;
        bytes data;
        uint256 value;
        uint256 gasLimit;
    }

    /// @notice authority => next valid nonce
    mapping(address => uint256) public nextNonce;

    /// @notice thrown when a Batch is executed with an invalid nonce
    /// @param authority - the signing authority
    /// @param expected - the expected, valid nonce
    /// @param attempted - the attempted, invalid nonce
    error InvalidNonce(address authority, uint256 expected, uint256 attempted);

    /// @notice thrown when a Batch is executed with a larger `msg.value` than the sum of each sub-call's `value`
    error ExtraValue();

    /// @notice produce a signable digest that empowers this BatchInvoker to execute the Batch on behalf of the signing authority using AUTHCALL
    /// @param batch - the Batch of Calls that the authority wishes to be executed on their behalf
    /// @return digest - the payload that the authority should sign in order to empower this BatchInvoker to execute the Batch using AUTHCALL
    function getDigest(Batch calldata batch) external view returns (bytes32 digest) {
        digest = getDigest(getCommit(batch));
    }

    /// @notice produce a hashed commitment to an Batch to be executed using AUTHCALL
    /// @param batch - the Batch of Calls that the authority wishes to be executed on their behalf
    /// @return commit - the hashed commitment to the encoded Batch
    /// @dev commit is a key parameter to the signed digest
    function getCommit(Batch calldata batch) public pure returns (bytes32 commit) {
        commit = keccak256(abi.encode(batch));
    }

    /// @notice execute a Batch of Calls on behalf of a signing authority using AUTH and AUTHCALL
    /// @param batch - the Batch of Calls that the authority wishes to be executed on their behalf
    /// @dev (v, r, s) are interpreted as an ECDSA signature on the secp256k1 curve over getDigest(batch)
    function execute(address authority, Batch calldata batch, uint8 v, bytes32 r, bytes32 s) public payable {
        // AUTH this contract to execute the Batch on behalf of the authority
        auth(authority, getCommit(batch), v, r, s);
        // validate the nonce & increment
        uint256 expectedNonce = nextNonce[authority]++;
        if (expectedNonce != batch.nonce) revert InvalidNonce(authority, expectedNonce, batch.nonce);
        // AUTHCALL each call in the batch
        for (uint256 i; i < batch.calls.length; i++) {
            exec(batch.calls[i]);
        }
        // ensure that all value passed to the transaction was passed on to sub-calls (no leftover value in BatchInvoker contract)
        if (address(this).balance != 0) revert ExtraValue();
    }

    /// @notice execute a single Call. revert if it fails.
    function exec(Call memory call) internal {
        authCall(call.to, call.data, call.value, call.gasLimit);
    }
}
