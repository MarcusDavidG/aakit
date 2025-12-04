// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/**
 * @title MultiOwnable
 * @notice Manages multiple owners for a smart wallet
 * @dev Supports both EOA (address) and passkey (P256 public key) owners
 * 
 * Owner Encoding:
 * - EOA: 20 bytes (address)
 * - Passkey: 64 bytes (x coordinate || y coordinate)
 */
abstract contract MultiOwnable {
    // Storage slot for owners (diamond storage pattern)
    // keccak256("aakit.storage.MultiOwnable")
    bytes32 private constant _MULTI_OWNABLE_STORAGE = 
        0x8d8d0c4f3c8f8c1e8e7f1d2e3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e;

    struct MultiOwnableStorage {
        mapping(uint256 => bytes) ownerAtIndex;
        mapping(bytes => bool) isOwner;
        uint256 nextOwnerIndex;
    }

    // Events
    event AddOwner(uint256 indexed index, bytes owner);
    event RemoveOwner(uint256 indexed index, bytes owner);

    // Errors
    error InvalidOwner();
    error OwnerAlreadyExists();
    error OwnerDoesNotExist();
    error NoOwnerAtIndex(uint256 index);
    error InvalidOwnerBytesLength(bytes owner);

    /**
     * @notice Get storage pointer
     */
    function _getMultiOwnableStorage() private pure returns (MultiOwnableStorage storage $) {
        assembly {
            $.slot := _MULTI_OWNABLE_STORAGE
        }
    }

    /**
     * @notice Initialize with an owner
     * @param owner Initial owner (address or passkey)
     */
    function _initializeOwner(bytes memory owner) internal {
        _addOwner(owner);
    }

    /**
     * @notice Add an owner address
     * @param owner Address to add
     */
    function addOwnerAddress(address owner) public virtual {
        _checkOwner();
        if (owner == address(0)) revert InvalidOwner();
        _addOwner(abi.encode(owner));
    }

    /**
     * @notice Add a passkey owner
     * @param x X coordinate of P256 public key
     * @param y Y coordinate of P256 public key
     */
    function addOwnerPublicKey(bytes32 x, bytes32 y) public virtual {
        _checkOwner();
        if (x == bytes32(0) || y == bytes32(0)) revert InvalidOwner();
        _addOwner(abi.encodePacked(x, y));
    }

    /**
     * @notice Add owner at specific index
     * @param index Index to add at
     * @param owner Owner bytes to add
     */
    function addOwnerAtIndex(uint256 index, bytes memory owner) public virtual {
        _checkOwner();
        MultiOwnableStorage storage $ = _getMultiOwnableStorage();
        
        if ($.ownerAtIndex[index].length != 0) {
            revert OwnerAlreadyExists();
        }
        if ($.isOwner[owner]) {
            revert OwnerAlreadyExists();
        }

        _validateOwnerBytes(owner);

        $.ownerAtIndex[index] = owner;
        $.isOwner[owner] = true;

        if (index >= $.nextOwnerIndex) {
            $.nextOwnerIndex = index + 1;
        }

        emit AddOwner(index, owner);
    }

    /**
     * @notice Remove owner at index
     * @param index Index of owner to remove
     */
    function removeOwnerAtIndex(uint256 index) public virtual {
        _checkOwner();
        MultiOwnableStorage storage $ = _getMultiOwnableStorage();
        
        bytes memory owner = $.ownerAtIndex[index];
        if (owner.length == 0) {
            revert NoOwnerAtIndex(index);
        }

        delete $.ownerAtIndex[index];
        delete $.isOwner[owner];

        emit RemoveOwner(index, owner);
    }

    /**
     * @notice Check if bytes represent an owner
     * @param account Account bytes to check
     * @return True if account is an owner
     */
    function isOwnerBytes(bytes memory account) public view virtual returns (bool) {
        return _getMultiOwnableStorage().isOwner[account];
    }

    /**
     * @notice Check if address is an owner
     * @param account Address to check
     * @return True if account is an owner
     */
    function isOwnerAddress(address account) public view virtual returns (bool) {
        return _getMultiOwnableStorage().isOwner[abi.encode(account)];
    }

    /**
     * @notice Check if public key is an owner
     * @param x X coordinate
     * @param y Y coordinate
     * @return True if public key is an owner
     */
    function isOwnerPublicKey(bytes32 x, bytes32 y) public view virtual returns (bool) {
        return _getMultiOwnableStorage().isOwner[abi.encodePacked(x, y)];
    }

    /**
     * @notice Get owner at index
     * @param index Index to query
     * @return Owner bytes at index
     */
    function ownerAtIndex(uint256 index) public view virtual returns (bytes memory) {
        MultiOwnableStorage storage $ = _getMultiOwnableStorage();
        bytes memory owner = $.ownerAtIndex[index];
        if (owner.length == 0) {
            revert NoOwnerAtIndex(index);
        }
        return owner;
    }

    /**
     * @notice Get next owner index
     * @return Next available owner index
     */
    function nextOwnerIndex() public view virtual returns (uint256) {
        return _getMultiOwnableStorage().nextOwnerIndex;
    }

    /**
     * @notice Internal: Add an owner
     * @param owner Owner bytes to add
     */
    function _addOwner(bytes memory owner) internal {
        MultiOwnableStorage storage $ = _getMultiOwnableStorage();
        
        if ($.isOwner[owner]) {
            revert OwnerAlreadyExists();
        }

        _validateOwnerBytes(owner);

        uint256 index = $.nextOwnerIndex;
        $.ownerAtIndex[index] = owner;
        $.isOwner[owner] = true;
        $.nextOwnerIndex = index + 1;

        emit AddOwner(index, owner);
    }

    /**
     * @notice Internal: Validate owner bytes length
     * @param owner Owner bytes to validate
     */
    function _validateOwnerBytes(bytes memory owner) internal pure {
        uint256 length = owner.length;
        
        // Must be 32 bytes (address) or 64 bytes (passkey)
        if (length == 32) {
            // Address encoded with abi.encode
            return;
        } else if (length == 64) {
            // Passkey public key (x || y)
            return;
        } else if (length == 20) {
            // Raw address bytes
            return;
        } else {
            revert InvalidOwnerBytesLength(owner);
        }
    }

    /**
     * @notice Internal: Check if caller is an owner
     * @dev Must be overridden by implementing contract
     */
    function _checkOwner() internal view virtual;
}
