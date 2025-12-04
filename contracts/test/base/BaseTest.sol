// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import {MockEntryPoint} from "../mocks/MockEntryPoint.sol";
import {AAKitWallet} from "../../src/wallet/AAKitWallet.sol";
import {AAKitFactory} from "../../src/factory/AAKitFactory.sol";
import {PasskeyValidator} from "../../src/validators/PasskeyValidator.sol";
import {VerifyingPaymaster} from "../../src/paymaster/VerifyingPaymaster.sol";
import {PackedUserOperation} from "../../src/interfaces/IERC4337.sol";
import {TestUtils} from "../utils/TestUtils.sol";

/**
 * @title BaseTest
 * @notice Base test contract with common setup
 */
abstract contract BaseTest is Test {
    using TestUtils for *;

    // Core contracts
    MockEntryPoint public entryPoint;
    AAKitFactory public factory;
    PasskeyValidator public passkeyValidator;
    VerifyingPaymaster public paymaster;

    // Test accounts
    address public owner;
    uint256 public ownerKey;
    address public user;
    uint256 public userKey;
    address public bundler;
    address payable public beneficiary;

    // Constants
    uint256 constant INITIAL_BALANCE = 100 ether;

    function setUp() public virtual {
        // Setup test accounts
        (owner, ownerKey) = makeAddrAndKey("owner");
        (user, userKey) = makeAddrAndKey("user");
        bundler = makeAddr("bundler");
        beneficiary = payable(makeAddr("beneficiary"));

        // Deploy EntryPoint
        entryPoint = new MockEntryPoint();

        // Deploy Factory
        factory = new AAKitFactory(address(entryPoint));

        // Deploy PasskeyValidator
        passkeyValidator = new PasskeyValidator();

        // Deploy Paymaster
        paymaster = new VerifyingPaymaster(
            address(entryPoint),
            owner,
            1 ether // 1 ETH spending cap per account
        );

        // Fund accounts
        vm.deal(owner, INITIAL_BALANCE);
        vm.deal(user, INITIAL_BALANCE);
        vm.deal(bundler, INITIAL_BALANCE);
        vm.deal(address(paymaster), INITIAL_BALANCE);

        // Fund paymaster in EntryPoint
        vm.prank(address(paymaster));
        entryPoint.depositTo{value: 10 ether}(address(paymaster));
    }

    /**
     * @notice Create a wallet with address owner
     */
    function createWallet(address _owner) internal returns (AAKitWallet) {
        bytes memory ownerBytes = TestUtils.encodeOwner(_owner);
        uint256 salt = 0;
        
        address walletAddress = factory.createAccount(ownerBytes, salt);
        return AAKitWallet(payable(walletAddress));
    }

    /**
     * @notice Create a wallet with passkey owner
     */
    function createPasskeyWallet(
        bytes32 x,
        bytes32 y
    ) internal returns (AAKitWallet) {
        bytes memory ownerBytes = TestUtils.encodePasskeyOwner(x, y);
        uint256 salt = 0;
        
        address walletAddress = factory.createAccount(ownerBytes, salt);
        return AAKitWallet(payable(walletAddress));
    }

    /**
     * @notice Sign user operation
     */
    function signUserOp(
        PackedUserOperation memory userOp,
        uint256 privateKey
    ) internal view returns (PackedUserOperation memory) {
        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
        bytes32 ethSignedHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", userOpHash)
        );
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, ethSignedHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        
        userOp.signature = abi.encode(uint8(0), signature);
        return userOp;
    }

    /**
     * @notice Get current nonce for wallet
     */
    function getNonce(address wallet) internal view returns (uint256) {
        return entryPoint.getNonce(wallet, 0);
    }

    /**
     * @notice Get current nonce with key
     */
    function getNonce(address wallet, uint192 key) internal view returns (uint256) {
        return entryPoint.getNonce(wallet, key);
    }

    /**
     * @notice Fund wallet in EntryPoint
     */
    function fundWallet(address wallet, uint256 amount) internal {
        vm.deal(wallet, amount);
        vm.prank(wallet);
        entryPoint.depositTo{value: amount}(wallet);
    }

    /**
     * @notice Helper to expect revert with custom error
     */
    function expectRevertWithCustomError(bytes4 selector) internal {
        vm.expectRevert(abi.encodeWithSelector(selector));
    }
}
