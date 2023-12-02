// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test, console } from "forge-std/Test.sol";
import { VmSafe } from "forge-std/Vm.sol";

interface IAuthRelay {
    /// @notice Relay an `AUTHCALL` to `to` with calldata `data` and a signature, `signature`, from `signer`
    /// @param signature The signature authenticating the `AUTHCALL`
    /// @param data The calldata of the `AUTHCALL` to relay
    /// @param signer The creator of the `signature`
    /// @param to The address of the contract to relay the `AUTHCALL` to
    /// @return The return data of the `AUTHCALL`
    function relay(bytes calldata signature, bytes calldata data, address signer, address to) external returns (bytes memory);
}

contract SimpleSmartWallet {
    function act() public {
        // TODO
    }
}

contract EIP3074_Test is Test {
    /// @dev The `MAGIC` byte for the `AUTH` message hash
    uint8 internal constant MAGIC = 0x04;

    /// @dev The `AUTHCALL` relayer
    IAuthRelay internal relayer;
    /// @dev A sample smart wallet for the `AUTHCALL` relayer to call
    SimpleSmartWallet internal wallet;
    /// @dev The `AUTHCALL` relayer
    VmSafe.Wallet internal actor;

    function setUp() public {
        // Deploy the `AUTHCALL` relayer
        string[] memory command = new string[](3);
        command[0] = "huffc";
        command[1] = "-b";
        command[2] = "src/EIP3074.huff";
        bytes memory relayerInitCode = vm.ffi(command);
        assembly ("memory-safe") {
            let addr := create(0x00, add(relayerInitCode, 0x20), mload(relayerInitCode))
            if iszero(extcodesize(addr)) {
                revert(0, 0)
            }
            sstore(relayer.slot, addr)
        }

        // Deploy the simple smart wallet
        wallet = new SimpleSmartWallet();

        // Set up the dummy actor
        actor = vm.createWallet("eip3074gud");
    }

    /// @dev Tests that a basic `AUTHCALL` relay succeeds from the `actor`
    function test_basicAuthCall_succeeds() public {
        // Sign the `AUTH` message hash.
        bytes32 messageHash = _constructAuthMessageHash(0);
        bytes memory signature = _actorSign(messageHash);

        // Construct the calldata for the `AUTHCALL`
        bytes memory data = abi.encodeCall(SimpleSmartWallet.act, ());

        // Relay the `AUTHCALL`
        relayer.relay(signature, data, actor.addr, address(wallet));
    }

    /// @dev Helper to sign a digest and format the signature as `abi.encodePacked(yParity, r, s)`
    function _actorSign(bytes32 _digest) internal returns (bytes memory signature_) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(actor, _digest);
        bool yParity;
        if (v >= 35) {
            yParity = ((v - 35) % 2) != 0;
        } else {
            yParity = v == 28;
        }
        signature_ = abi.encodePacked(yParity, r, s);
    }

    /// @dev Helper to construct the `AUTH` message hash for signing by the `actor`.
    function _constructAuthMessageHash(uint256 _commit) internal view returns (bytes32 hash_) {
        hash_ = keccak256(abi.encodePacked(
            MAGIC,
            uint256(block.chainid),
            uint256(uint160(address(relayer))),
            _commit
        ));
    }
}
