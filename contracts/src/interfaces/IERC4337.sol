// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/**
 * @title PackedUserOperation
 * @notice User operation struct for ERC-4337 v0.7
 * @dev Packed version optimized for calldata efficiency
 */
struct PackedUserOperation {
    address sender;
    uint256 nonce;
    bytes initCode;
    bytes callData;
    bytes32 accountGasLimits;
    uint256 preVerificationGas;
    bytes32 gasFees;
    bytes paymasterAndData;
    bytes signature;
}

/**
 * @title IAccount
 * @notice Interface for ERC-4337 compliant accounts
 * @dev Accounts must implement this interface to work with EntryPoint
 */
interface IAccount {
    /**
     * @notice Validates a user operation
     * @param userOp The user operation to validate
     * @param userOpHash The hash of the user operation
     * @param missingAccountFunds Amount to deposit to EntryPoint if account doesn't have enough
     * @return validationData Packed validation data:
     *         - aggregator: 20 bytes (address 0 for valid, 1 for invalid signature)
     *         - validUntil: 6 bytes (0 for infinite)
     *         - validAfter: 6 bytes (0 for immediate)
     */
    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external returns (uint256 validationData);
}

/**
 * @title IAccountExecute
 * @notice Optional interface for custom execution logic
 * @dev If implemented, EntryPoint will call this instead of using callData directly
 */
interface IAccountExecute {
    /**
     * @notice Execute a user operation
     * @param userOp The user operation to execute
     * @param userOpHash The hash of the user operation
     */
    function executeUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash) external;
}

/**
 * @title IEntryPoint
 * @notice Interface for ERC-4337 EntryPoint contract
 * @dev Minimal interface for account interaction
 */
interface IEntryPoint {
    /**
     * @notice Execute a batch of user operations
     * @param ops Array of user operations to execute
     * @param beneficiary Address to receive collected fees
     */
    function handleOps(PackedUserOperation[] calldata ops, address payable beneficiary) external;

    /**
     * @notice Execute a single user operation
     * @param op The user operation to execute
     * @param beneficiary Address to receive collected fees
     */
    function handleOp(PackedUserOperation calldata op, address payable beneficiary) external;

    /**
     * @notice Get nonce for an account
     * @param sender The account address
     * @param key The nonce key (for key-based nonce management)
     * @return nonce The current nonce for the key
     */
    function getNonce(address sender, uint192 key) external view returns (uint256 nonce);

    /**
     * @notice Get deposit info for an account
     * @param account The account address
     * @return info Deposit information
     */
    function getDepositInfo(address account) external view returns (DepositInfo memory info);

    /**
     * @notice Deposit funds for an account
     * @param account The account to deposit for
     */
    function depositTo(address account) external payable;

    /**
     * @notice Withdraw funds to an address
     * @param withdrawAddress Where to send the funds
     * @param withdrawAmount Amount to withdraw
     */
    function withdrawTo(address payable withdrawAddress, uint256 withdrawAmount) external;

    /**
     * @notice Add stake for the calling account
     * @param unstakeDelaySec Delay in seconds before unstake is allowed
     */
    function addStake(uint32 unstakeDelaySec) external payable;

    /**
     * @notice Unlock stake (must wait unstakeDelay)
     */
    function unlockStake() external;

    /**
     * @notice Withdraw unlocked stake
     * @param withdrawAddress Where to send the stake
     */
    function withdrawStake(address payable withdrawAddress) external;
}

/**
 * @title DepositInfo
 * @notice Deposit information for an account
 */
struct DepositInfo {
    uint256 deposit;
    bool staked;
    uint112 stake;
    uint32 unstakeDelaySec;
    uint48 withdrawTime;
}

/**
 * @title IPaymaster
 * @notice Interface for ERC-4337 paymaster contracts
 */
interface IPaymaster {
    enum PostOpMode {
        opSucceeded,
        opReverted,
        postOpReverted
    }

    /**
     * @notice Validate a paymaster user operation
     * @param userOp The user operation
     * @param userOpHash Hash of the user operation
     * @param maxCost Maximum cost of this user operation
     * @return context Context to pass to postOp
     * @return validationData Packed validation data
     */
    function validatePaymasterUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 maxCost
    ) external returns (bytes memory context, uint256 validationData);

    /**
     * @notice Post-operation handler
     * @param mode Success/failure mode
     * @param context Context from validatePaymasterUserOp
     * @param actualGasCost Actual gas cost of the operation
     * @param actualUserOpFeePerGas Actual fee per gas paid
     */
    function postOp(
        PostOpMode mode,
        bytes calldata context,
        uint256 actualGasCost,
        uint256 actualUserOpFeePerGas
    ) external;
}

/**
 * @title IAggregator
 * @notice Interface for signature aggregation
 */
interface IAggregator {
    /**
     * @notice Validate aggregated signature
     * @param userOps Array of user operations
     * @return validationData Packed validation data
     */
    function validateSignatures(
        PackedUserOperation[] calldata userOps
    ) external view returns (uint256 validationData);

    /**
     * @notice Validate user op signature
     * @param userOp The user operation
     * @return sigForAggregator Signature data for aggregation
     */
    function validateUserOpSignature(
        PackedUserOperation calldata userOp
    ) external view returns (bytes memory sigForAggregator);

    /**
     * @notice Aggregate multiple signatures
     * @param userOps Array of user operations
     * @return aggregatedSignature The aggregated signature
     */
    function aggregateSignatures(
        PackedUserOperation[] calldata userOps
    ) external view returns (bytes memory aggregatedSignature);
}
