// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {PackedUserOperation} from "../../src/interfaces/IERC4337.sol";

/**
 * @title TestUtils
 * @notice Utility functions for tests
 */
library TestUtils {
    /**
     * @notice Create a default PackedUserOperation
     */
    function createUserOp(
        address sender,
        uint256 nonce,
        bytes memory callData
    ) internal pure returns (PackedUserOperation memory) {
        return PackedUserOperation({
            sender: sender,
            nonce: nonce,
            initCode: "",
            callData: callData,
            accountGasLimits: bytes32(abi.encodePacked(uint128(100000), uint128(100000))),
            preVerificationGas: 21000,
            gasFees: bytes32(abi.encodePacked(uint128(1 gwei), uint128(1 gwei))),
            paymasterAndData: "",
            signature: ""
        });
    }

    /**
     * @notice Create user operation with signature
     */
    function createSignedUserOp(
        address sender,
        uint256 nonce,
        bytes memory callData,
        uint8 ownerIndex,
        bytes memory signatureData
    ) internal pure returns (PackedUserOperation memory) {
        PackedUserOperation memory userOp = createUserOp(sender, nonce, callData);
        userOp.signature = abi.encode(ownerIndex, signatureData);
        return userOp;
    }

    /**
     * @notice Pack gas limits
     */
    function packGasLimits(
        uint128 verificationGasLimit,
        uint128 callGasLimit
    ) internal pure returns (bytes32) {
        return bytes32(abi.encodePacked(verificationGasLimit, callGasLimit));
    }

    /**
     * @notice Pack gas fees
     */
    function packGasFees(
        uint128 maxPriorityFeePerGas,
        uint128 maxFeePerGas
    ) internal pure returns (bytes32) {
        return bytes32(abi.encodePacked(maxPriorityFeePerGas, maxFeePerGas));
    }

    /**
     * @notice Sign message with private key
     */
    function signMessage(
        bytes32 messageHash,
        uint256 privateKey
    ) internal pure returns (uint8 v, bytes32 r, bytes32 s) {
        // This is a simplified version - in real tests, use vm.sign from forge-std
        // For now, return dummy values
        return (27, bytes32(uint256(1)), bytes32(uint256(2)));
    }

    /**
     * @notice Encode execute call
     */
    function encodeExecute(
        address target,
        uint256 value,
        bytes memory data
    ) internal pure returns (bytes memory) {
        bytes32 mode = bytes32(uint256(0)); // Single call mode
        bytes memory executionData = abi.encode(target, value, data);
        return abi.encodeWithSignature("execute(bytes32,bytes)", mode, executionData);
    }

    /**
     * @notice Encode batch execute call
     */
    function encodeBatchExecute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory datas
    ) internal pure returns (bytes memory) {
        require(
            targets.length == values.length && values.length == datas.length,
            "Length mismatch"
        );
        
        bytes32 mode = bytes32(uint256(1) << 248); // Batch call mode
        
        // Create execution array
        bytes memory executionData = new bytes(0);
        for (uint256 i = 0; i < targets.length; i++) {
            executionData = abi.encodePacked(
                executionData,
                abi.encode(targets[i], values[i], datas[i])
            );
        }
        
        return abi.encodeWithSignature("execute(bytes32,bytes)", mode, executionData);
    }

    /**
     * @notice Encode owner as bytes
     */
    function encodeOwner(address owner) internal pure returns (bytes memory) {
        return abi.encode(owner);
    }

    /**
     * @notice Encode passkey owner as bytes
     */
    function encodePasskeyOwner(
        bytes32 x,
        bytes32 y
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(x, y);
    }

    /**
     * @notice Generate random bytes32
     */
    function randomBytes32(uint256 seed) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(seed));
    }

    /**
     * @notice Generate random address
     */
    function randomAddress(uint256 seed) internal pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(seed)))));
    }
}
