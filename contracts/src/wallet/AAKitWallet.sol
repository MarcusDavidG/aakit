// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {PackedUserOperation} from "../interfaces/IERC4337.sol";
import {IERC7579Account, Execution, CallType, ExecType, ModuleType} from "../interfaces/IERC7579.sol";
import {IAAKitWallet} from "../interfaces/IAAKitWallet.sol";
import {MultiOwnable} from "../utils/MultiOwnable.sol";
import {ERC4337Account} from "../utils/ERC4337Account.sol";

/**
 * @title AAKitWallet
 * @notice Modular smart wallet with ERC-4337 and ERC-7579 compliance
 * @dev Supports passkey (P256) and address owners, modular validators/executors
 */
contract AAKitWallet is 
    ERC4337Account,
    MultiOwnable,
    IAAKitWallet,
    IERC7579Account
{
    // Storage slot for wallet state
    // keccak256("aakit.storage.Wallet")
    bytes32 private constant _WALLET_STORAGE =
        0x1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b;

    struct WalletStorage {
        mapping(uint256 => mapping(address => bool)) modules; // moduleTypeId => module => installed
        mapping(bytes4 => address) fallbackHandler; // selector => handler
        address currentValidator; // For signature validation
        bool initialized;
    }

    // Account ID
    string public constant ACCOUNT_ID = "aakit.wallet.v1";

    // Errors
    error AlreadyInitialized();
    error NotInitialized();
    error ModuleNotInstalled(uint256 moduleTypeId, address module);
    error ModuleAlreadyInstalled(uint256 moduleTypeId, address module);
    error UnsupportedModuleType(uint256 moduleTypeId);
    error UnsupportedExecutionMode(bytes32 mode);
    error ExecutionFailed();
    error SelectorNotAllowed(bytes4 selector);

    /**
     * @notice Constructor
     * @param _entryPoint Address of EntryPoint contract
     */
    constructor(address _entryPoint) ERC4337Account(_entryPoint) {
        _getWalletStorage().initialized = true; // Prevent initialization on implementation
    }

    /**
     * @notice Initialize wallet with an owner
     * @param owner Initial owner (address or passkey public key)
     */
    function initialize(bytes calldata owner) external payable {
        WalletStorage storage $ = _getWalletStorage();
        if ($.initialized) revert AlreadyInitialized();
        
        $.initialized = true;
        _initializeOwner(owner);
        
        emit WalletInitialized(entryPoint);
    }

    // ============ ERC-4337 Functions ============

    /**
     * @notice Validate signature for user operation
     * @param userOp User operation to validate
     * @param userOpHash Hash of user operation
     * @return validationData Validation result (0 = success, 1 = failure)
     */
    function _validateSignature(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    ) internal virtual override returns (uint256 validationData) {
        // Decode signature: (ownerIndex, signatureData)
        (uint8 ownerIndex, bytes memory signatureData) = 
            abi.decode(userOp.signature, (uint8, bytes));
        
        // Get owner at index
        bytes memory owner = ownerAtIndex(ownerIndex);
        
        // Validate based on owner type
        if (owner.length == 32 || owner.length == 20) {
            // Address owner - verify ECDSA signature
            return _validateECDSASignature(owner, userOpHash, signatureData);
        } else if (owner.length == 64) {
            // Passkey owner - delegate to validator module
            WalletStorage storage $ = _getWalletStorage();
            address validator = $.currentValidator;
            if (validator == address(0)) {
                return SIG_VALIDATION_FAILED;
            }
            
            // Call validator (would be PasskeyValidator in practice)
            // For now, return failed - will implement in next step
            return SIG_VALIDATION_FAILED;
        } else {
            return SIG_VALIDATION_FAILED;
        }
    }

    /**
     * @notice Validate ECDSA signature
     */
    function _validateECDSASignature(
        bytes memory owner,
        bytes32 hash,
        bytes memory signature
    ) internal pure returns (uint256) {
        address signer;
        
        if (owner.length == 32) {
            signer = abi.decode(owner, (address));
        } else {
            signer = address(uint160(bytes20(owner)));
        }
        
        // Extract r, s, v from signature
        if (signature.length != 65) {
            return SIG_VALIDATION_FAILED;
        }
        
        bytes32 r;
        bytes32 s;
        uint8 v;
        
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }
        
        address recovered = ecrecover(hash, v, r, s);
        
        return recovered == signer ? SIG_VALIDATION_SUCCESS : SIG_VALIDATION_FAILED;
    }

    // ============ ERC-7579 Execution ============

    /**
     * @notice Execute a transaction
     * @param mode Execution mode (callType, execType, etc.)
     * @param executionCalldata Encoded execution data
     */
    function execute(
        bytes32 mode,
        bytes calldata executionCalldata
    ) external payable override {
        _requireFromEntryPointOrSelf();
        _execute(mode, executionCalldata);
    }

    /**
     * @notice Execute from an executor module
     * @param mode Execution mode
     * @param executionCalldata Encoded execution data
     * @return returnData Array of return data
     */
    function executeFromExecutor(
        bytes32 mode,
        bytes calldata executionCalldata
    ) external payable override returns (bytes[] memory returnData) {
        // Verify caller is an installed executor
        WalletStorage storage $ = _getWalletStorage();
        if (!$.modules[ModuleType.EXECUTOR][msg.sender]) {
            revert ModuleNotInstalled(ModuleType.EXECUTOR, msg.sender);
        }
        
        return _execute(mode, executionCalldata);
    }

    /**
     * @notice Internal execution handler
     */
    function _execute(
        bytes32 mode,
        bytes calldata executionCalldata
    ) internal returns (bytes[] memory returnData) {
        bytes1 callType = bytes1(mode[0]);
        
        if (callType == CallType.CALL) {
            // Single call
            (address target, uint256 value, bytes memory data) = 
                abi.decode(executionCalldata, (address, uint256, bytes));
            returnData = new bytes[](1);
            returnData[0] = _call(target, value, data);
            
        } else if (callType == CallType.BATCH_CALL) {
            // Batch call
            Execution[] memory executions = abi.decode(executionCalldata, (Execution[]));
            returnData = new bytes[](executions.length);
            
            for (uint256 i = 0; i < executions.length; i++) {
                returnData[i] = _call(
                    executions[i].target,
                    executions[i].value,
                    executions[i].callData
                );
            }
            
        } else if (callType == CallType.DELEGATE_CALL) {
            // Delegate call
            (address target, bytes memory data) = 
                abi.decode(executionCalldata, (address, bytes));
            returnData = new bytes[](1);
            returnData[0] = _delegateCall(target, data);
            
        } else {
            revert UnsupportedExecutionMode(mode);
        }
    }

    /**
     * @notice Execute a call
     */
    function _call(
        address target,
        uint256 value,
        bytes memory data
    ) internal returns (bytes memory result) {
        (bool success, bytes memory returnData) = target.call{value: value}(data);
        if (!success) {
            // Bubble up revert reason
            assembly {
                revert(add(returnData, 0x20), mload(returnData))
            }
        }
        return returnData;
    }

    /**
     * @notice Execute a delegatecall
     */
    function _delegateCall(
        address target,
        bytes memory data
    ) internal returns (bytes memory result) {
        (bool success, bytes memory returnData) = target.delegatecall(data);
        if (!success) {
            assembly {
                revert(add(returnData, 0x20), mload(returnData))
            }
        }
        return returnData;
    }

    /**
     * @notice Execute without chain ID validation
     * @param data Calldata to execute on self
     */
    function executeWithoutChainIdValidation(
        bytes calldata data
    ) external payable override(ERC4337Account, IAAKitWallet) {
        _requireFromEntryPoint();
        
        bytes4 selector = bytes4(data[0:4]);
        if (!canSkipChainIdValidation(selector)) {
            revert SelectorNotAllowed(selector);
        }
        
        _call(address(this), 0, data);
    }

    /**
     * @notice Check if selector can skip chain ID validation
     */
    function canSkipChainIdValidation(bytes4 selector) public pure override returns (bool) {
        return
            selector == this.addOwnerAddress.selector ||
            selector == this.addOwnerPublicKey.selector ||
            selector == this.removeOwnerAtIndex.selector;
    }

    // ============ ERC-7579 Module Management ============

    /**
     * @notice Install a module
     */
    function installModule(
        uint256 moduleTypeId,
        address module,
        bytes calldata initData
    ) external payable override {
        _requireFromEntryPointOrSelf();
        
        WalletStorage storage $ = _getWalletStorage();
        
        if (!supportsModule(moduleTypeId)) {
            revert UnsupportedModuleType(moduleTypeId);
        }
        
        if ($.modules[moduleTypeId][module]) {
            revert ModuleAlreadyInstalled(moduleTypeId, module);
        }
        
        $.modules[moduleTypeId][module] = true;
        
        // Call module initialization
        (bool success, ) = module.call(
            abi.encodeWithSignature("onInstall(bytes)", initData)
        );
        require(success, "Module installation failed");
        
        emit ModuleInstalled(moduleTypeId, module);
    }

    /**
     * @notice Uninstall a module
     */
    function uninstallModule(
        uint256 moduleTypeId,
        address module,
        bytes calldata deInitData
    ) external payable override {
        _requireFromEntryPointOrSelf();
        
        WalletStorage storage $ = _getWalletStorage();
        
        if (!$.modules[moduleTypeId][module]) {
            revert ModuleNotInstalled(moduleTypeId, module);
        }
        
        delete $.modules[moduleTypeId][module];
        
        // Call module deinitialization
        (bool success, ) = module.call(
            abi.encodeWithSignature("onUninstall(bytes)", deInitData)
        );
        require(success, "Module uninstallation failed");
        
        emit ModuleUninstalled(moduleTypeId, module);
    }

    /**
     * @notice Check if module is installed
     */
    function isModuleInstalled(
        uint256 moduleTypeId,
        address module,
        bytes calldata
    ) external view override returns (bool) {
        return _getWalletStorage().modules[moduleTypeId][module];
    }

    // ============ ERC-7579 Configuration ============

    /**
     * @notice Get account ID
     */
    function accountId() external pure override returns (string memory) {
        return ACCOUNT_ID;
    }

    /**
     * @notice Check if execution mode is supported
     */
    function supportsExecutionMode(bytes32 encodedMode) external pure override returns (bool) {
        bytes1 callType = bytes1(encodedMode[0]);
        return 
            callType == CallType.CALL ||
            callType == CallType.BATCH_CALL ||
            callType == CallType.DELEGATE_CALL;
    }

    /**
     * @notice Check if module type is supported
     */
    function supportsModule(uint256 moduleTypeId) public pure override returns (bool) {
        return
            moduleTypeId == ModuleType.VALIDATOR ||
            moduleTypeId == ModuleType.EXECUTOR ||
            moduleTypeId == ModuleType.FALLBACK ||
            moduleTypeId == ModuleType.HOOK;
    }

    // ============ MultiOwnable Overrides ============

    /**
     * @notice Check if caller is owner or self
     * @dev Allows wallet to call owner-restricted functions when executing via EntryPoint
     */
    function _checkOwner() internal view override(ERC4337Account, MultiOwnable) {
        if (!isOwnerAddress(msg.sender) && msg.sender != address(this)) {
            revert UnauthorizedCaller();
        }
    }
    
    /**
     * @notice Add owner address (override both interfaces)
     */
    function addOwnerAddress(address owner) public override(MultiOwnable, IAAKitWallet) {
        super.addOwnerAddress(owner);
    }
    
    /**
     * @notice Add owner public key (override both interfaces)
     */
    function addOwnerPublicKey(bytes32 x, bytes32 y) public override(MultiOwnable, IAAKitWallet) {
        super.addOwnerPublicKey(x, y);
    }
    
    /**
     * @notice Remove owner at index (override both interfaces)
     */
    function removeOwnerAtIndex(uint256 index) public override(MultiOwnable, IAAKitWallet) {
        super.removeOwnerAtIndex(index);
    }
    
    /**
     * @notice Get owner at index (override both interfaces)
     */
    function ownerAtIndex(uint256 index) public view override(MultiOwnable, IAAKitWallet) returns (bytes memory) {
        return super.ownerAtIndex(index);
    }

    /**
     * @notice Check if account is owner (external interface)
     */
    function isOwner(bytes memory account) external view override returns (bool) {
        return isOwnerBytes(account);
    }

    /**
     * @notice Get implementation (for proxy)
     */
    function implementation() external view override returns (address) {
        return address(this);
    }

    // ============ Storage Helper ============

    function _getWalletStorage() private pure returns (WalletStorage storage $) {
        assembly {
            $.slot := _WALLET_STORAGE
        }
    }
}
