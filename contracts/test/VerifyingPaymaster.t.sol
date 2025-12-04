// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "./base/BaseTest.sol";
import {PackedUserOperation} from "../src/interfaces/IERC4337.sol";
import {TestUtils} from "./utils/TestUtils.sol";

/**
 * @title VerifyingPaymasterTest
 * @notice Tests for VerifyingPaymaster
 */
contract VerifyingPaymasterTest is BaseTest {
    AAKitWallet public wallet;
    
    address public signer;
    uint256 public signerKey;

    function setUp() public override {
        super.setUp();
        
        wallet = createWallet(owner);
        (signer, signerKey) = makeAddrAndKey("signer");
        
        // Deploy new paymaster with signer (deployed by owner)
        vm.prank(owner);
        paymaster = new VerifyingPaymaster(
            address(entryPoint),
            signer,
            1 ether
        );
        
        // Fund paymaster
        vm.deal(address(paymaster), 10 ether);
        vm.prank(address(paymaster));
        entryPoint.depositTo{value: 5 ether}(address(paymaster));
    }

    function test_Initialization() public view {
        assertEq(paymaster.entryPoint(), address(entryPoint));
        assertEq(paymaster.verifyingSigner(), signer);
        assertEq(paymaster.accountSpendingCap(), 1 ether);
    }

    function test_SetVerifyingSigner() public {
        address newSigner = makeAddr("newSigner");
        
        vm.prank(owner);
        paymaster.setVerifyingSigner(newSigner);
        
        assertEq(paymaster.verifyingSigner(), newSigner);
    }

    function test_RevertWhen_SetVerifyingSignerNotOwner() public {
        address newSigner = makeAddr("newSigner");
        
        vm.prank(user);
        vm.expectRevert();
        paymaster.setVerifyingSigner(newSigner);
    }

    function test_RevertWhen_SetVerifyingSignerZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert();
        paymaster.setVerifyingSigner(address(0));
    }

    function test_SetAccountSpendingCap() public {
        uint256 newCap = 2 ether;
        
        vm.prank(owner);
        paymaster.setAccountSpendingCap(newCap);
        
        assertEq(paymaster.accountSpendingCap(), newCap);
    }

    function test_RevertWhen_SetAccountSpendingCapNotOwner() public {
        vm.prank(user);
        vm.expectRevert();
        paymaster.setAccountSpendingCap(2 ether);
    }

    function test_Deposit() public {
        uint256 amount = 1 ether;
        
        vm.deal(owner, amount);
        vm.prank(owner);
        paymaster.deposit{value: amount}();
        
        // Verify deposit increased
        uint256 deposit = entryPoint.getDepositInfo(address(paymaster)).deposit;
        assertEq(deposit, 5 ether + amount);
    }

    function test_WithdrawTo() public {
        uint256 balanceBefore = owner.balance;
        uint256 withdrawAmount = 0.5 ether;
        
        vm.prank(owner);
        paymaster.withdrawTo(payable(owner), withdrawAmount);
        
        assertEq(owner.balance, balanceBefore + withdrawAmount);
    }

    function test_RevertWhen_WithdrawToNotOwner() public {
        vm.prank(user);
        vm.expectRevert();
        paymaster.withdrawTo(payable(user), 0.1 ether);
    }

    function test_AddStake() public {
        uint256 stakeAmount = 1 ether;
        uint32 unstakeDelay = 1 days;
        
        vm.deal(owner, stakeAmount);
        vm.prank(owner);
        paymaster.addStake{value: stakeAmount}(unstakeDelay);
        
        // Verify deposit increased (stake goes to deposit in our mock)
        uint256 deposit = entryPoint.getDepositInfo(address(paymaster)).deposit;
        assertEq(deposit, 5 ether + stakeAmount);
    }

    function test_UnlockStake() public {
        vm.prank(owner);
        paymaster.unlockStake();
        
        // Should not revert (no-op in mock EntryPoint)
    }

    function test_WithdrawStake() public {
        uint256 balanceBefore = owner.balance;
        
        vm.prank(owner);
        paymaster.withdrawStake(payable(owner));
        
        // In mock, this withdraws all deposit
        assertTrue(owner.balance > balanceBefore);
    }

    function test_ReceiveEther() public {
        uint256 balanceBefore = address(paymaster).balance;
        
        vm.deal(owner, 1 ether);
        vm.prank(owner);
        (bool success, ) = address(paymaster).call{value: 1 ether}("");
        assertTrue(success);
        
        assertEq(address(paymaster).balance, balanceBefore + 1 ether);
    }

    function test_SpendingTracking() public view {
        // Initially, no spending
        assertEq(paymaster.spentThisPeriod(address(wallet)), 0);
    }

    function testFuzz_SetAccountSpendingCap(uint256 newCap) public {
        vm.prank(owner);
        paymaster.setAccountSpendingCap(newCap);
        
        assertEq(paymaster.accountSpendingCap(), newCap);
    }
}
