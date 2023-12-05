// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @title SimpleAuth
/// @author Anna Carroll <https://github.com/anna-carroll/3074>
abstract contract SimpleAuth {
    function authSimple(address authority, bytes32 commit, uint8 v, bytes32 r, bytes32 s)
        internal
        returns (bool success)
    {
        bytes memory authArgs = abi.encodePacked(yParity(v), r, s, commit);
        assembly {
            success := auth(authority, add(authArgs, 0x20), mload(authArgs))
        }
    }

    function authCallSimple(address to, bytes memory data, uint256 value, uint256 gasLimit)
        internal
        returns (bool success)
    {
        assembly {
            success := authcall(gasLimit, to, value, 0, add(data, 0x20), mload(data), 0, 0)
        }
    }

    /// @dev Internal helper to convert `v` to `yParity` for `AUTH`
    function yParity(uint8 v) private pure returns (uint8 yParity_) {
        assembly {
            switch lt(v, 35)
            case true { yParity_ := eq(v, 28) }
            default { yParity_ := mod(sub(v, 35), 2) }
        }
    }
}
