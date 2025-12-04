// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {AAKitWallet} from "../wallet/AAKitWallet.sol";

/**
 * @title AAKitFactory
 * @notice Factory for deploying AAKit wallets deterministically
 * @dev Uses CREATE2 for counterfactual addresses
 */
contract AAKitFactory {
    // Immutable wallet implementation
    address public immutable walletImplementation;
    
    // EntryPoint address
    address public immutable entryPoint;

    // Events
    event WalletCreated(
        address indexed wallet,
        address indexed owner,
        uint256 salt
    );

    // Errors
    error WalletCreationFailed();
    error WalletAlreadyExists();

    /**
     * @notice Constructor
     * @param _entryPoint EntryPoint contract address
     */
    constructor(address _entryPoint) {
        entryPoint = _entryPoint;
        walletImplementation = address(new AAKitWallet(_entryPoint));
    }

    /**
     * @notice Create a new wallet
     * @param owner Initial owner (address or passkey public key)
     * @param salt Salt for CREATE2
     * @return wallet Address of created wallet
     */
    function createAccount(
        bytes calldata owner,
        uint256 salt
    ) external returns (address wallet) {
        // Compute deterministic address
        wallet = getAddress(owner, salt);
        
        // Check if already deployed
        if (wallet.code.length > 0) {
            return wallet;
        }
        
        // Deploy minimal proxy
        bytes memory deploymentData = abi.encodePacked(
            hex"3d602d80600a3d3981f3363d3d373d3d3d363d73",
            walletImplementation,
            hex"5af43d82803e903d91602b57fd5bf3"
        );
        
        address deployed;
        assembly {
            deployed := create2(0, add(deploymentData, 0x20), mload(deploymentData), salt)
        }
        
        if (deployed == address(0)) {
            revert WalletCreationFailed();
        }
        
        // Initialize wallet
        AAKitWallet(payable(deployed)).initialize(owner);
        
        emit WalletCreated(deployed, _getOwnerAddress(owner), salt);
        
        return deployed;
    }

    /**
     * @notice Get counterfactual address for a wallet
     * @param owner Initial owner
     * @param salt CREATE2 salt
     * @return Predicted wallet address
     */
    function getAddress(
        bytes calldata owner,
        uint256 salt
    ) public view returns (address) {
        bytes memory deploymentData = abi.encodePacked(
            hex"3d602d80600a3d3981f3363d3d373d3d3d363d73",
            walletImplementation,
            hex"5af43d82803e903d91602b57fd5bf3"
        );
        
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(this),
                salt,
                keccak256(deploymentData)
            )
        );
        
        return address(uint160(uint256(hash)));
    }

    /**
     * @notice Compute deterministic salt from owner
     * @param owner Owner bytes
     * @param nonce Additional entropy
     * @return Salt for CREATE2
     */
    function getSalt(bytes calldata owner, uint256 nonce) external pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(owner, nonce)));
    }

    /**
     * @notice Helper to extract address from owner bytes
     */
    function _getOwnerAddress(bytes calldata owner) private pure returns (address) {
        if (owner.length == 32) {
            return abi.decode(owner, (address));
        } else if (owner.length == 20) {
            return address(bytes20(owner));
        } else {
            // Passkey - return zero address
            return address(0);
        }
    }
}
