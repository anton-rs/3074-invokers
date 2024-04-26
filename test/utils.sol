// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.20;

function vToYParity(uint8 v) pure returns (uint8 yParity_) {
    assembly {
        switch lt(v, 35)
        case true { yParity_ := eq(v, 28) }
        default { yParity_ := mod(sub(v, 35), 2) }
    }
}
