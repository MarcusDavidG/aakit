// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "./base/BaseTest.sol";
import {AAKitWallet} from "../src/wallet/AAKitWallet.sol";
import {TestUtils} from "./utils/TestUtils.sol";

/**
 * @title MultiOwnableTest
 * @notice Tests for MultiOwnable functionality
 */
contract MultiOwnableTest is BaseTest {
    AAKitWallet public wallet;
    
    address public owner1;
    address public owner2;
    address public owner3;
    
    bytes32 public passkeyX = bytes32(uint256(1));
    bytes32 public passkeyY = bytes32(uint256(2));

    function setUp() public override {
        super.setUp();
        
        // Create test owners
        owner1 = makeAddr("owner1");
        owner2 = makeAddr("owner2");
        owner3 = makeAddr("owner3");
        
        // Create wallet with owner1
        wallet = createWallet(owner1);
    }

    function test_InitialOwner() public view {
        // Check initial owner is set
        bytes memory ownerBytes = TestUtils.encodeOwner(owner1);
        assertTrue(wallet.isOwnerBytes(ownerBytes));
        assertTrue(wallet.isOwnerAddress(owner1));
    }

    function test_AddOwnerAddress() public {
        vm.prank(owner1);
        wallet.addOwnerAddress(owner2);
        
        assertTrue(wallet.isOwnerAddress(owner2));
        assertEq(wallet.nextOwnerIndex(), 2);
    }

    function test_AddOwnerPublicKey() public {
        vm.prank(owner1);
        wallet.addOwnerPublicKey(passkeyX, passkeyY);
        
        assertTrue(wallet.isOwnerPublicKey(passkeyX, passkeyY));
        assertEq(wallet.nextOwnerIndex(), 2);
    }

    function test_RevertWhen_AddOwnerNotOwner() public {
        vm.prank(owner2); // owner2 is not an owner yet
        vm.expectRevert();
        wallet.addOwnerAddress(owner3);
    }

    function test_RevertWhen_AddOwnerTwice() public {
        vm.startPrank(owner1);
        wallet.addOwnerAddress(owner2);
        
        vm.expectRevert();
        wallet.addOwnerAddress(owner2); // Try to add again
        vm.stopPrank();
    }

    function test_RevertWhen_AddZeroAddress() public {
        vm.prank(owner1);
        vm.expectRevert();
        wallet.addOwnerAddress(address(0));
    }

    function test_RevertWhen_AddZeroPublicKey() public {
        vm.prank(owner1);
        vm.expectRevert();
        wallet.addOwnerPublicKey(bytes32(0), bytes32(0));
    }

    function test_RemoveOwnerAtIndex() public {
        // Add owner2
        vm.prank(owner1);
        wallet.addOwnerAddress(owner2);
        assertTrue(wallet.isOwnerAddress(owner2));
        
        // Remove owner at index 1 (owner2)
        vm.prank(owner1);
        wallet.removeOwnerAtIndex(1);
        assertFalse(wallet.isOwnerAddress(owner2));
    }

    function test_RevertWhen_RemoveOwnerNotOwner() public {
        vm.prank(owner2); // Not an owner
        vm.expectRevert();
        wallet.removeOwnerAtIndex(0);
    }

    function test_RevertWhen_RemoveNonExistentOwner() public {
        vm.prank(owner1);
        vm.expectRevert();
        wallet.removeOwnerAtIndex(999); // Index doesn't exist
    }

    function test_OwnerAtIndex() public {
        bytes memory ownerBytes = wallet.ownerAtIndex(0);
        assertEq(ownerBytes, TestUtils.encodeOwner(owner1));
    }

    function test_MultipleOwners() public {
        // Add multiple owners
        vm.startPrank(owner1);
        wallet.addOwnerAddress(owner2);
        wallet.addOwnerAddress(owner3);
        wallet.addOwnerPublicKey(passkeyX, passkeyY);
        vm.stopPrank();
        
        // Verify all owners
        assertTrue(wallet.isOwnerAddress(owner1));
        assertTrue(wallet.isOwnerAddress(owner2));
        assertTrue(wallet.isOwnerAddress(owner3));
        assertTrue(wallet.isOwnerPublicKey(passkeyX, passkeyY));
        
        assertEq(wallet.nextOwnerIndex(), 4);
    }

    function test_OwnerCanPerformActions() public {
        // Add owner2
        vm.prank(owner1);
        wallet.addOwnerAddress(owner2);
        
        // owner2 should be able to add owner3
        vm.prank(owner2);
        wallet.addOwnerAddress(owner3);
        
        assertTrue(wallet.isOwnerAddress(owner3));
    }

    function testFuzz_AddOwnerAddress(address newOwner) public {
        vm.assume(newOwner != address(0));
        vm.assume(!wallet.isOwnerAddress(newOwner));
        
        vm.prank(owner1);
        wallet.addOwnerAddress(newOwner);
        
        assertTrue(wallet.isOwnerAddress(newOwner));
    }

    function testFuzz_AddOwnerPublicKey(bytes32 x, bytes32 y) public {
        vm.assume(x != bytes32(0) && y != bytes32(0));
        vm.assume(!wallet.isOwnerPublicKey(x, y));
        
        vm.prank(owner1);
        wallet.addOwnerPublicKey(x, y);
        
        assertTrue(wallet.isOwnerPublicKey(x, y));
    }
}
