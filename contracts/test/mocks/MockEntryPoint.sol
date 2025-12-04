// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {PackedUserOperation, IEntryPoint, DepositInfo} from "../../src/interfaces/IERC4337.sol";

/**
 * @title MockEntryPoint
 * @notice Mock EntryPoint for testing
 * @dev Simplified version of ERC-4337 EntryPoint for unit tests
 */
contract MockEntryPoint is IEntryPoint {
    mapping(address => uint256) public deposits;
    mapping(address => mapping(uint192 => uint256)) public nonces;
    
    uint256 public constant SIG_VALIDATION_FAILED = 1;
    
    event UserOperationEvent(
        bytes32 indexed userOpHash,
        address indexed sender,
        address indexed paymaster,
        uint256 nonce,
        bool success,
        uint256 actualGasCost,
        uint256 actualGasUsed
    );

    /**
     * @notice Handle a single user operation
     */
    function handleOp(
        PackedUserOperation calldata op,
        address payable beneficiary
    ) external {
        bytes32 userOpHash = getUserOpHash(op);
        
        // Call validateUserOp
        uint256 validationData = _validateUserOp(op, userOpHash);
        
        if (validationData == SIG_VALIDATION_FAILED) {
            revert("Validation failed");
        }
        
        // Execute the operation
        (bool success, ) = op.sender.call(op.callData);
        
        emit UserOperationEvent(
            userOpHash,
            op.sender,
            address(0),
            op.nonce,
            success,
            0,
            0
        );
    }

    /**
     * @notice Handle multiple user operations
     */
    function handleOps(
        PackedUserOperation[] calldata ops,
        address payable beneficiary
    ) external {
        for (uint256 i = 0; i < ops.length; i++) {
            bytes32 userOpHash = getUserOpHash(ops[i]);
            
            uint256 validationData = _validateUserOp(ops[i], userOpHash);
            
            if (validationData == SIG_VALIDATION_FAILED) {
                revert("Validation failed");
            }
            
            (bool success, ) = ops[i].sender.call(ops[i].callData);
            
            emit UserOperationEvent(
                userOpHash,
                ops[i].sender,
                address(0),
                ops[i].nonce,
                success,
                0,
                0
            );
        }
    }

    /**
     * @notice Get nonce for an account
     */
    function getNonce(address sender, uint192 key) external view returns (uint256) {
        return nonces[sender][key];
    }

    /**
     * @notice Increment nonce
     */
    function incrementNonce(address sender, uint192 key) external {
        nonces[sender][key]++;
    }

    /**
     * @notice Get deposit info
     */
    function getDepositInfo(address account) external view returns (DepositInfo memory info) {
        return DepositInfo({
            deposit: deposits[account],
            staked: false,
            stake: 0,
            unstakeDelaySec: 0,
            withdrawTime: 0
        });
    }

    /**
     * @notice Deposit funds for an account
     */
    function depositTo(address account) external payable {
        deposits[account] += msg.value;
    }

    /**
     * @notice Withdraw funds
     */
    function withdrawTo(address payable withdrawAddress, uint256 withdrawAmount) external {
        require(deposits[msg.sender] >= withdrawAmount, "Insufficient deposit");
        deposits[msg.sender] -= withdrawAmount;
        withdrawAddress.transfer(withdrawAmount);
    }

    /**
     * @notice Add stake (simplified - no actual staking)
     */
    function addStake(uint32 unstakeDelaySec) external payable {
        deposits[msg.sender] += msg.value;
    }

    /**
     * @notice Unlock stake (no-op in mock)
     */
    function unlockStake() external {}

    /**
     * @notice Withdraw stake (same as withdrawTo)
     */
    function withdrawStake(address payable withdrawAddress) external {
        uint256 amount = deposits[msg.sender];
        deposits[msg.sender] = 0;
        withdrawAddress.transfer(amount);
    }

    /**
     * @notice Get user operation hash
     */
    function getUserOpHash(PackedUserOperation calldata userOp) public view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256(
                    abi.encode(
                        userOp.sender,
                        userOp.nonce,
                        keccak256(userOp.initCode),
                        keccak256(userOp.callData),
                        userOp.accountGasLimits,
                        userOp.preVerificationGas,
                        userOp.gasFees,
                        keccak256(userOp.paymasterAndData)
                    )
                ),
                address(this),
                block.chainid
            )
        );
    }

    /**
     * @notice Internal validation
     */
    function _validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    ) internal returns (uint256) {
        // Increment nonce
        uint192 key = uint192(userOp.nonce >> 64);
        nonces[userOp.sender][key]++;
        
        // Call account validation
        (bool success, bytes memory result) = userOp.sender.call(
            abi.encodeWithSignature(
                "validateUserOp((address,uint256,bytes,bytes,bytes32,uint256,bytes32,bytes,bytes),bytes32,uint256)",
                userOp,
                userOpHash,
                0
            )
        );
        
        if (!success) {
            return SIG_VALIDATION_FAILED;
        }
        
        return abi.decode(result, (uint256));
    }

    receive() external payable {
        deposits[msg.sender] += msg.value;
    }
}
