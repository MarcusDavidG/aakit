// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "./base/BaseTest.sol";
import {AAKitWallet} from "../src/wallet/AAKitWallet.sol";
import {TestUtils} from "./utils/TestUtils.sol";

/**
 * @title AAKitFactoryTest
 * @notice Tests for AAKitFactory
 */
contract AAKitFactoryTest is BaseTest {
    function test_WalletImplementation() public view {
        address impl = factory.walletImplementation();
        assertTrue(impl != address(0));
        
        // Verify implementation is a wallet
        AAKitWallet wallet = AAKitWallet(payable(impl));
        assertEq(wallet.accountId(), "aakit.wallet.v1");
    }

    function test_CreateAccount_WithAddressOwner() public {
        bytes memory ownerBytes = TestUtils.encodeOwner(owner);
        uint256 salt = 123;
        
        address predicted = factory.getAddress(ownerBytes, salt);
        address created = factory.createAccount(ownerBytes, salt);
        
        assertEq(created, predicted);
        
        // Verify wallet is initialized
        AAKitWallet wallet = AAKitWallet(payable(created));
        assertTrue(wallet.isOwnerAddress(owner));
    }

    function test_CreateAccount_WithPasskeyOwner() public {
        bytes32 x = bytes32(uint256(1));
        bytes32 y = bytes32(uint256(2));
        bytes memory ownerBytes = TestUtils.encodePasskeyOwner(x, y);
        uint256 salt = 456;
        
        address predicted = factory.getAddress(ownerBytes, salt);
        address created = factory.createAccount(ownerBytes, salt);
        
        assertEq(created, predicted);
        
        // Verify wallet is initialized
        AAKitWallet wallet = AAKitWallet(payable(created));
        assertTrue(wallet.isOwnerPublicKey(x, y));
    }

    function test_CreateAccount_Deterministic() public {
        bytes memory ownerBytes = TestUtils.encodeOwner(owner);
        uint256 salt = 789;
        
        address wallet1 = factory.createAccount(ownerBytes, salt);
        
        // Creating again should return same address
        address wallet2 = factory.createAccount(ownerBytes, salt);
        
        assertEq(wallet1, wallet2);
    }

    function test_CreateAccount_DifferentSalts() public {
        bytes memory ownerBytes = TestUtils.encodeOwner(owner);
        
        address wallet1 = factory.createAccount(ownerBytes, 1);
        address wallet2 = factory.createAccount(ownerBytes, 2);
        
        assertTrue(wallet1 != wallet2);
    }

    function test_CreateAccount_DifferentOwners() public {
        // Same salt but different owners should create different wallets
        // But actually, the salt determines the address with CREATE2, not the owner
        // So we need to use getSalt to get different salts for different owners
        
        bytes memory owner1Bytes = TestUtils.encodeOwner(owner);
        bytes memory owner2Bytes = TestUtils.encodeOwner(user);
        
        uint256 salt1 = factory.getSalt(owner1Bytes, 0);
        uint256 salt2 = factory.getSalt(owner2Bytes, 0);
        
        address wallet1 = factory.createAccount(owner1Bytes, salt1);
        address wallet2 = factory.createAccount(owner2Bytes, salt2);
        
        assertTrue(wallet1 != wallet2);
    }

    function test_GetAddress_BeforeDeployment() public {
        address newOwner = makeAddr("newOwner");
        bytes memory ownerBytes = TestUtils.encodeOwner(newOwner);
        uint256 salt = 999;
        
        address predicted = factory.getAddress(ownerBytes, salt);
        
        // Address should be computable even before deployment
        assertTrue(predicted != address(0));
    }

    function test_GetSalt() public view {
        bytes memory ownerBytes = TestUtils.encodeOwner(owner);
        uint256 nonce = 42;
        
        uint256 salt = factory.getSalt(ownerBytes, nonce);
        
        // Salt should be deterministic
        uint256 salt2 = factory.getSalt(ownerBytes, nonce);
        assertEq(salt, salt2);
        
        // Different nonce should give different salt
        uint256 salt3 = factory.getSalt(ownerBytes, 43);
        assertTrue(salt != salt3);
    }

    function test_WalletCanReceiveEther() public {
        address wallet = factory.createAccount(TestUtils.encodeOwner(owner), 0);
        
        vm.deal(address(this), 1 ether);
        (bool success, ) = wallet.call{value: 0.5 ether}("");
        assertTrue(success);
        
        assertEq(wallet.balance, 0.5 ether);
    }

    function test_EntryPointAddress() public view {
        assertEq(factory.entryPoint(), address(entryPoint));
    }

    function testFuzz_CreateAccount(address _owner, uint256 _salt) public {
        vm.assume(_owner != address(0));
        
        bytes memory ownerBytes = TestUtils.encodeOwner(_owner);
        address predicted = factory.getAddress(ownerBytes, _salt);
        address created = factory.createAccount(ownerBytes, _salt);
        
        assertEq(created, predicted);
        
        AAKitWallet wallet = AAKitWallet(payable(created));
        assertTrue(wallet.isOwnerAddress(_owner));
    }

    function testFuzz_CreateAccount_Passkey(bytes32 x, bytes32 y, uint256 salt) public {
        vm.assume(x != bytes32(0) && y != bytes32(0));
        
        bytes memory ownerBytes = TestUtils.encodePasskeyOwner(x, y);
        address predicted = factory.getAddress(ownerBytes, salt);
        address created = factory.createAccount(ownerBytes, salt);
        
        assertEq(created, predicted);
        
        AAKitWallet wallet = AAKitWallet(payable(created));
        assertTrue(wallet.isOwnerPublicKey(x, y));
    }
}
