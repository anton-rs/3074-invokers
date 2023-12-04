// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test, console } from "forge-std/Test.sol";
import { VmSafe } from "forge-std/Vm.sol";
import { MockERC20, ERC20 } from "test/mocks/MockERC20.sol";

interface IAuthRelay {
    /// @notice Relay an `AUTHCALL` to `to` with calldata `data` and a signature, `signature`, from `signer`
    /// @param signature The signature authenticating the `AUTHCALL`
    /// @param data The calldata of the `AUTHCALL` to relay
    /// @param commit The commit of the `AUTHCALL` message that was signed by the creator of `signature`
    /// @param to The address of the contract to relay the `AUTHCALL` to
    function relay(bytes calldata signature, bytes calldata data, bytes32 commit, address to) external;
}

contract EIP3074_Test is Test {
    /// @dev The `MAGIC` byte for the `AUTH` message hash
    uint8 internal constant MAGIC = 0x04;

    /// @dev The `AUTHCALL` relayer
    IAuthRelay internal relayer;
    /// @dev A mock ERC-20 token used for testing.
    MockERC20 internal mockToken;
    /// @dev The `AUTHCALL` relayer
    VmSafe.Wallet internal actor;

    /// @dev Thrown when the signature length is incorrect
    error BadSignatureLength();
    /// @dev Thrown when a `commit` has already been used.
    error CommitUsed();

    function setUp() public {
        // Deploy the `AUTHCALL` relayer
        string[] memory command = new string[](3);
        command[0] = "huffc";
        command[1] = "-b";
        command[2] = "src/AsmInvoker.huff";
        bytes memory relayerInitCode = vm.ffi(command);
        assembly ("memory-safe") {
            let addr := create(0x00, add(relayerInitCode, 0x20), mload(relayerInitCode))
            if iszero(extcodesize(addr)) { revert(0, 0) }
            sstore(relayer.slot, addr)
        }
        vm.label(address(relayer), "AuthRelay");

        // Set up the dummy actor
        actor = vm.createWallet("eip3074gud");

        // Deploy the mock ERC-20 token and send 100 tokens to the actor
        mockToken = new MockERC20();
        mockToken.transfer(actor.addr, 100 ether);
    }

    /// @dev Tests that a basic `AUTHCALL` relay succeeds from the `actor`
    function test_basicAuthCall_succeeds() public {
        // Construct the calldata for the `AUTHCALL`
        bytes memory data = abi.encodeCall(ERC20.transfer, (address(0xdead), 1 ether));

        // Sign the `AUTH` message hash.
        bytes32 commit =
            _createSimpleCommit({ _nonce: vm.getNonce(actor.addr), _to: address(mockToken), _gas: 50_000, _data: data });
        bytes32 messageHash = _constructAuthMessageHash(address(relayer), commit);
        bytes memory signature = _actorSign(actor, messageHash);

        // Sanity check that the Relayer & `0xdead` have no tokens
        assertEq(mockToken.balanceOf(address(relayer)), 0 ether);
        assertEq(mockToken.balanceOf(address(0xdead)), 0 ether);
        // Sanity check that the actor has 100 tokens
        assertEq(mockToken.balanceOf(actor.addr), 100 ether);

        // Relay the `AUTHCALL`
        relayer.relay(signature, data, commit, address(mockToken));

        // Assert that the `0xdead` address now has 1 token, and the actor has 99 tokens.
        assertEq(mockToken.balanceOf(address(0xdead)), 1 ether);
        assertEq(mockToken.balanceOf(actor.addr), 99 ether);
    }

    /// @dev Tests that a basic `AUTHCALL` relay fails if the same commit is used twice.
    function test_replayAuthCall_reverts() public {
        // Construct the calldata for the `AUTHCALL`
        bytes memory data = abi.encodeCall(ERC20.transfer, (address(0xdead), 1 ether));

        // Sign the `AUTH` message hash.
        bytes32 commit =
            _createSimpleCommit({ _nonce: vm.getNonce(actor.addr), _to: address(mockToken), _gas: 50_000, _data: data });
        bytes32 messageHash = _constructAuthMessageHash(address(relayer), commit);
        bytes memory signature = _actorSign(actor, messageHash);

        // Relay the `AUTHCALL`. Should succeed.
        relayer.relay(signature, data, commit, address(mockToken));

        // Relay the `AUTHCALL`. Should fail; duplicate `commit`.
        vm.expectRevert(CommitUsed.selector);
        relayer.relay(signature, data, commit, address(mockToken));
    }

    /// @dev Tests that the relay reverts if the signature length is not 65
    function testFuzz_basicAuthCall_badSignature_reverts(bytes memory _signature) public {
        // Ensure the signature length is never 65
        if (_signature.length == 65) {
            assembly {
                mstore(_signature, 0x40)
            }
        }

        // Construct the calldata for the `AUTHCALL`
        bytes memory data = abi.encodeCall(ERC20.transfer, (address(0xdead), 1 ether));

        // The signature length should always be 65 bytes. (yparity ++ r ++ s)
        vm.expectRevert(BadSignatureLength.selector);
        relayer.relay(_signature, data, 0, address(mockToken));
    }

    /// @dev Helper to create a simple commit hash.
    function _createSimpleCommit(uint256 _nonce, address _to, uint256 _gas, bytes memory _data)
        internal
        pure
        returns (bytes32 commit_)
    {
        commit_ = keccak256(abi.encodePacked(_nonce, _to, _gas, _data));
    }

    /// @dev Helper to sign a digest and format the signature as `abi.encodePacked(yParity, r, s)`
    function _actorSign(VmSafe.Wallet memory _wallet, bytes32 _digest) internal returns (bytes memory signature_) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_wallet, _digest);
        bool yParity;
        if (v >= 35) {
            yParity = ((v - 35) % 2) != 0;
        } else {
            yParity = v == 28;
        }
        signature_ = abi.encodePacked(yParity, r, s);
    }

    /// @dev Helper to construct the `AUTH` message hash for signing by the `actor`.
    function _constructAuthMessageHash(address _relayer, bytes32 _commit) internal view returns (bytes32 hash_) {
        hash_ = keccak256(abi.encodePacked(MAGIC, uint256(block.chainid), uint256(uint160(address(_relayer))), _commit));
    }
}
