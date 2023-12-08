// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { BaseInvoker } from "src/BaseInvoker.sol";

/// @title SingleInvoker
/// @author Julian Rachman <https://github.com/Jrachman>
/// @notice Example EIP-3074 Invoker contract which executes a single call using AUTH and AUTHCALL.
contract SingleInvoker is BaseInvoker {
    // TODO: add commit check errors here

    /// @notice execute a Batch of Calls on behalf of a signing authority using AUTH and AUTHCALL
    /// @param authority - the signer authorizing the AUTHCALL
    /// @param execData - abi-encoded:
    ///         gas - gas limit for both the `auth` and `authcall` executions
    ///         value - the value to transfer from the authority to `to`
    ///         to - the address to make the call to
    ///         data - the input data to send to `to`
    /// @dev (v, r, s) are interpreted as an ECDSA signature on the secp256k1 curve over getDigest(batch)
    function exec(address authority, bytes memory execData) internal override {
        (uint256 gas, uint256 value, address to, bytes memory data) = abi.decode(execData, (uint256, uint256, address, bytes));
        // AUTHCALL to execute transaction on behalf of the authority
        authCall(to, data, value, gas);
    }
}
