// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.20;

function vToYParity(uint8 v) pure returns (uint8 yParity_) {
    assembly {
        switch lt(v, 35)
        case true { yParity_ := eq(v, 28) }
        default { yParity_ := mod(sub(v, 35), 2) }
    }
}

function packCalls(bytes memory prevCalls, address to, uint256 value, bytes memory data) pure returns (bytes memory calls) {
    return abi.encodePacked(prevCalls, uint8(2), to, value, data.length, data);
}
