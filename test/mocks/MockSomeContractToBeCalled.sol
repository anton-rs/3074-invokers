// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MockSomeContractToBeCalled {
  error SumIncorrect();

  uint8 public correctAnswers = 0;

  function twoPlusTwoEquals(uint256 sum) public payable {
    if (2 + 2 + sum != 8) revert SumIncorrect();

    correctAnswers += 1;
  }
}

