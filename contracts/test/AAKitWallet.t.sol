// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "./base/BaseTest.sol";
import {AAKitWallet} from "../src/wallet/AAKitWallet.sol";
import {PackedUserOperation} from "../src/interfaces/IERC4337.sol";
import {TestUtils} from "./utils/TestUtils.sol";
import {ModuleType, Execution} from "../src/interfaces/IERC7579.sol";

/**
 * @title AAKitWalletTest
 * @notice Tests for AAKitWallet functionality
 */
contract AAKitWalletTest is BaseTest {
    AAKitWallet public wallet;
    
    address public receiver;

    function setUp() public override {
        super.setUp();
        
        wallet = createWallet(owner);
        receiver = makeAddr("receiver");
        
        // Fund wallet (11 ether total: 10 for transactions + 1 for EntryPoint deposit)
        vm.deal(address(wallet), 11 ether);
        
        // Deposit 1 ether to EntryPoint (without overwriting balance)
        vm.prank(address(wallet));
        entryPoint.depositTo{value: 1 ether}(address(wallet));
    }

    // ============ Initialization Tests ============

    function test_Initialize() public view {
        assertTrue(wallet.isOwnerAddress(owner));
        assertEq(wallet.entryPoint(), address(entryPoint));
        assertEq(wallet.accountId(), "aakit.wallet.v1");
    }

    function test_RevertWhen_InitializeTwice() public {
        vm.expectRevert();
        wallet.initialize(TestUtils.encodeOwner(user));
    }

    // ============ UserOperation Tests ============

    function test_ValidateUserOp_Success() public {
        // Create user operation
        bytes memory callData = TestUtils.encodeExecute(
            receiver,
            0.1 ether,
            ""
        );
        
        PackedUserOperation memory userOp = TestUtils.createUserOp(
            address(wallet),
            getNonce(address(wallet)),
            callData
        );
        
        // Sign with owner
        userOp = signUserOp(userOp, ownerKey);
        
        // Get the actual userOpHash
        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
        
        // Validate
        vm.prank(address(entryPoint));
        uint256 validationData = wallet.validateUserOp(userOp, userOpHash, 0);
        
        assertEq(validationData, 0); // Success
    }

    function test_ValidateUserOp_InvalidSignature() public {
        // Create user operation
        bytes memory callData = TestUtils.encodeExecute(receiver, 0.1 ether, "");
        
        PackedUserOperation memory userOp = TestUtils.createUserOp(
            address(wallet),
            getNonce(address(wallet)),
            callData
        );
        
        // Sign with wrong key
        userOp = signUserOp(userOp, userKey); // user is not an owner
        
        // Get the actual userOpHash
        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
        
        // Validate
        vm.prank(address(entryPoint));
        uint256 validationData = wallet.validateUserOp(userOp, userOpHash, 0);
        
        assertEq(validationData, 1); // Failed
    }

    function test_RevertWhen_ValidateUserOpNotEntryPoint() public {
        PackedUserOperation memory userOp = TestUtils.createUserOp(
            address(wallet),
            0,
            ""
        );
        
        vm.prank(user); // Not EntryPoint
        vm.expectRevert();
        wallet.validateUserOp(userOp, bytes32(0), 0);
    }

    // ============ Execution Tests ============

    function test_Execute_SingleCall() public {
        uint256 balanceBefore = receiver.balance;
        
        bytes32 mode = bytes32(0); // Single call
        bytes memory executionData = abi.encode(receiver, 0.1 ether, "");
        
        vm.prank(address(entryPoint));
        wallet.execute(mode, executionData);
        
        assertEq(receiver.balance, balanceBefore + 0.1 ether);
    }

    function test_Execute_BatchCall() public {
        // Create Execution structs
        Execution[] memory executions = new Execution[](2);
        executions[0] = Execution({
            target: receiver,
            value: 0.1 ether,
            callData: ""
        });
        executions[1] = Execution({
            target: receiver,
            value: 0.2 ether,
            callData: ""
        });
        
        uint256 balanceBefore = receiver.balance;
        
        bytes32 mode = bytes32(uint256(1) << 248); // Batch call
        bytes memory executionData = abi.encode(executions);
        
        vm.prank(address(entryPoint));
        wallet.execute(mode, executionData);
        
        assertEq(receiver.balance, balanceBefore + 0.3 ether);
    }

    function test_RevertWhen_ExecuteNotAuthorized() public {
        bytes32 mode = bytes32(0);
        bytes memory executionData = abi.encode(receiver, 0.1 ether, "");
        
        vm.prank(user); // Not EntryPoint or self
        vm.expectRevert();
        wallet.execute(mode, executionData);
    }

    function test_ExecuteFromSelf() public {
        uint256 balanceBefore = receiver.balance;
        
        bytes32 mode = bytes32(0);
        bytes memory executionData = abi.encode(receiver, 0.1 ether, "");
        
        // Prepare call from self via EntryPoint
        bytes memory selfCallData = abi.encodeWithSignature(
            "execute(bytes32,bytes)",
            mode,
            executionData
        );
        
        vm.prank(address(entryPoint));
        (bool success, ) = address(wallet).call(selfCallData);
        assertTrue(success);
        
        assertEq(receiver.balance, balanceBefore + 0.1 ether);
    }

    // ============ Module Management Tests ============

    function test_InstallModule() public {
        address mockModule = makeAddr("mockModule");
        
        vm.prank(address(entryPoint));
        wallet.installModule(ModuleType.VALIDATOR, mockModule, "");
        
        assertTrue(wallet.isModuleInstalled(ModuleType.VALIDATOR, mockModule, ""));
    }

    function test_UninstallModule() public {
        address mockModule = makeAddr("mockModule");
        
        // Install
        vm.prank(address(entryPoint));
        wallet.installModule(ModuleType.VALIDATOR, mockModule, "");
        
        // Uninstall
        vm.prank(address(entryPoint));
        wallet.uninstallModule(ModuleType.VALIDATOR, mockModule, "");
        
        assertFalse(wallet.isModuleInstalled(ModuleType.VALIDATOR, mockModule, ""));
    }

    function test_RevertWhen_InstallModuleNotAuthorized() public {
        address mockModule = makeAddr("mockModule");
        
        vm.prank(user);
        vm.expectRevert();
        wallet.installModule(ModuleType.VALIDATOR, mockModule, "");
    }

    function test_RevertWhen_UninstallNonInstalledModule() public {
        address mockModule = makeAddr("mockModule");
        
        vm.prank(address(entryPoint));
        vm.expectRevert();
        wallet.uninstallModule(ModuleType.VALIDATOR, mockModule, "");
    }

    // ============ Cross-Chain Replayable Tests ============

    function test_ExecuteWithoutChainIdValidation() public {
        address newOwner = makeAddr("newOwner");
        
        bytes memory data = abi.encodeWithSignature(
            "addOwnerAddress(address)",
            newOwner
        );
        
        vm.prank(address(entryPoint));
        wallet.executeWithoutChainIdValidation(data);
        
        assertTrue(wallet.isOwnerAddress(newOwner));
    }

    function test_CanSkipChainIdValidation() public view {
        assertTrue(wallet.canSkipChainIdValidation(wallet.addOwnerAddress.selector));
        assertTrue(wallet.canSkipChainIdValidation(wallet.addOwnerPublicKey.selector));
        assertTrue(wallet.canSkipChainIdValidation(wallet.removeOwnerAtIndex.selector));
    }

    function test_RevertWhen_SkipChainIdValidationInvalidSelector() public {
        bytes memory data = abi.encodeWithSignature("someInvalidFunction()");
        
        vm.prank(address(entryPoint));
        vm.expectRevert();
        wallet.executeWithoutChainIdValidation(data);
    }

    // ============ Configuration Tests ============

    function test_SupportsExecutionMode() public view {
        // Single call
        assertTrue(wallet.supportsExecutionMode(bytes32(0)));
        
        // Batch call
        assertTrue(wallet.supportsExecutionMode(bytes32(uint256(1) << 248)));
        
        // Delegatecall
        assertTrue(wallet.supportsExecutionMode(bytes32(uint256(0xFF) << 248)));
    }

    function test_SupportsModule() public view {
        assertTrue(wallet.supportsModule(ModuleType.VALIDATOR));
        assertTrue(wallet.supportsModule(ModuleType.EXECUTOR));
        assertTrue(wallet.supportsModule(ModuleType.FALLBACK));
        assertTrue(wallet.supportsModule(ModuleType.HOOK));
    }

    // ============ Deposit Management Tests ============

    function test_AddDeposit() public {
        uint256 depositBefore = wallet.getDeposit();
        
        vm.prank(owner);
        wallet.addDeposit{value: 1 ether}();
        
        assertEq(wallet.getDeposit(), depositBefore + 1 ether);
    }

    function test_WithdrawDeposit() public {
        // Add deposit first
        vm.prank(owner);
        wallet.addDeposit{value: 1 ether}();
        
        uint256 balanceBefore = owner.balance;
        
        vm.prank(owner);
        wallet.withdrawDepositTo(payable(owner), 0.5 ether);
        
        assertEq(owner.balance, balanceBefore + 0.5 ether);
    }

    function test_GetNonce() public view {
        uint256 nonce = wallet.getNonce(0);
        assertEq(nonce, 0);
    }

    function test_ReceiveEther() public {
        uint256 balanceBefore = address(wallet).balance;
        
        vm.prank(user);
        (bool success, ) = address(wallet).call{value: 1 ether}("");
        assertTrue(success);
        
        assertEq(address(wallet).balance, balanceBefore + 1 ether);
    }
}
