// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IERC7579Account} from "./IERC7579.sol";
import {IAccount} from "./IERC4337.sol";

/**
 * @title IAAKitWallet
 * @notice Main interface for AAKit wallet
 * @dev Combines ERC-4337 and ERC-7579 interfaces with custom functionality
 */
interface IAAKitWallet is IAccount, IERC7579Account {
    // Events
    event OwnerAdded(bytes indexed owner);
    event OwnerRemoved(bytes indexed owner);
    event WalletInitialized(address indexed entryPoint);

    // Errors
    error InvalidOwner();
    error OwnerAlreadyExists();
    error OwnerDoesNotExist();
    error InvalidSignature();
    error InvalidNonceKey(uint256 key);
    error UnauthorizedCaller();
    error ExecutionFailed();

    /**
     * @notice Initialize the wallet
     * @param anOwner Initial owner (can be address or passkey public key)
     */
    function initialize(bytes calldata anOwner) external payable;

    /**
     * @notice Execute without chain ID validation (for cross-chain operations)
     * @param data Calldata for the execution
     */
    function executeWithoutChainIdValidation(bytes calldata data) external payable;

    /**
     * @notice Add an owner address
     * @param owner Address to add as owner
     */
    function addOwnerAddress(address owner) external;

    /**
     * @notice Add an owner public key (for passkeys)
     * @param x X coordinate of public key
     * @param y Y coordinate of public key
     */
    function addOwnerPublicKey(bytes32 x, bytes32 y) external;

    /**
     * @notice Remove an owner at index
     * @param index Index of owner to remove
     */
    function removeOwnerAtIndex(uint256 index) external;

    /**
     * @notice Check if an account is an owner
     * @param account Owner to check (address or public key bytes)
     * @return True if account is an owner
     */
    function isOwner(bytes memory account) external view returns (bool);

    /**
     * @notice Get owner at index
     * @param index Index of owner
     * @return Owner bytes
     */
    function ownerAtIndex(uint256 index) external view returns (bytes memory);

    /**
     * @notice Check if function selector can skip chain ID validation
     * @param selector Function selector to check
     * @return True if selector is allowed
     */
    function canSkipChainIdValidation(bytes4 selector) external pure returns (bool);

    /**
     * @notice Get implementation address
     * @return Implementation contract address
     */
    function implementation() external view returns (address);

    /**
     * @notice Get EntryPoint address
     * @return EntryPoint contract address
     */
    function entryPoint() external view returns (address);
}
