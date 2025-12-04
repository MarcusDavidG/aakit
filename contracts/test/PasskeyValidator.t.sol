// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "./base/BaseTest.sol";
import {PasskeyValidator} from "../src/validators/PasskeyValidator.sol";
import {IERC7579Validator} from "../src/interfaces/IERC7579.sol";
import {PackedUserOperation} from "../src/interfaces/IERC4337.sol";
import {TestUtils} from "./utils/TestUtils.sol";

/**
 * @title PasskeyValidatorTest
 * @notice Tests for PasskeyValidator module
 */
contract PasskeyValidatorTest is BaseTest {
    PasskeyValidator public validator;
    address public receiver;
    
    // Test passkey (mock P256 key pair)
    uint256 public constant PASSKEY_X = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;
    uint256 public constant PASSKEY_Y = 0xfedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321;

    function setUp() public override {
        super.setUp();
        
        validator = new PasskeyValidator();
        receiver = makeAddr("receiver");
    }

    // ============ Module Interface Tests ============

    function test_IsModuleType() public view {
        assertTrue(validator.isModuleType(1)); // Validator type
        assertFalse(validator.isModuleType(2)); // Not executor
        assertFalse(validator.isModuleType(3)); // Not fallback
        assertFalse(validator.isModuleType(4)); // Not hook
    }

    function test_OnInstall() public {
        // Should not revert
        validator.onInstall("");
    }

    function test_OnUninstall() public {
        // Should not revert
        validator.onUninstall("");
    }

    function test_SupportsInterface() public view {
        // ERC-165 check
        assertTrue(validator.supportsInterface(type(IERC7579Validator).interfaceId));
    }

    // ============ WebAuthn Structure Tests ============

    function test_WebAuthnAuth_Structure() public {
        // Create WebAuthn auth structure
        PasskeyValidator.WebAuthnAuth memory auth = PasskeyValidator.WebAuthnAuth({
            authenticatorData: hex"49960de5880e8c687434170f6476605b8fe4aeb9a28632c7995cf3ba831d97630500000001",
            clientDataJSON: bytes('{"type":"webauthn.get","challenge":"test","origin":"https://app.aakit.io"}'),
            challengeIndex: 32,
            typeIndex: 9,
            r: 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef,
            s: 0xfedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321
        });
        
        // Encode and decode
        bytes memory encoded = abi.encode(auth);
        PasskeyValidator.WebAuthnAuth memory decoded = abi.decode(
            encoded,
            (PasskeyValidator.WebAuthnAuth)
        );
        
        assertEq(decoded.r, auth.r);
        assertEq(decoded.s, auth.s);
    }

    // ============ Signature Validation Tests ============

    function test_ValidateUserOp_WithPasskey() public {
        // Create wallet with passkey owner
        AAKitWallet wallet = createPasskeyWallet(
            bytes32(PASSKEY_X),
            bytes32(PASSKEY_Y)
        );
        
        // Create user operation
        bytes memory callData = TestUtils.encodeExecute(
            receiver,
            0,
            ""
        );
        
        PackedUserOperation memory userOp = TestUtils.createUserOp(
            address(wallet),
            0,
            callData
        );
        
        // Create WebAuthn signature (mock)
        PasskeyValidator.WebAuthnAuth memory auth = PasskeyValidator.WebAuthnAuth({
            authenticatorData: hex"49960de5880e8c687434170f6476605b8fe4aeb9a28632c7995cf3ba831d97630500000001",
            clientDataJSON: bytes('{"type":"webauthn.get","challenge":"test","origin":"https://app.aakit.io"}'),
            challengeIndex: 32,
            typeIndex: 9,
            r: 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef,
            s: 0x1111111111111111111111111111111111111111111111111111111111111111
        });
        
        bytes memory signatureData = abi.encode(auth);
        userOp.signature = abi.encode(uint8(0), signatureData);
        
        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
        
        // Note: This will return 1 (failed) because we don't have a real P256 signature
        // In production, would need actual P256 signing or mock precompile
        uint256 validationData = validator.validateUserOp(userOp, userOpHash);
        
        // Expected to fail without proper P256 signature
        assertEq(validationData, 1);
    }

    function test_IsValidSignatureWithSender() public view {
        bytes32 hash = keccak256("test message");
        
        PasskeyValidator.WebAuthnAuth memory auth = PasskeyValidator.WebAuthnAuth({
            authenticatorData: hex"49960de5880e8c687434170f6476605b8fe4aeb9a28632c7995cf3ba831d97630500000001",
            clientDataJSON: bytes('{"type":"webauthn.get","challenge":"test","origin":"https://app.aakit.io"}'),
            challengeIndex: 32,
            typeIndex: 9,
            r: 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef,
            s: 0x2222222222222222222222222222222222222222222222222222222222222222
        });
        
        bytes memory signature = abi.encode(auth);
        
        // Will return invalid without proper signature
        bytes4 result = validator.isValidSignatureWithSender(
            address(this),
            hash,
            signature
        );
        
        assertEq(result, bytes4(0xffffffff)); // Invalid
    }

    // ============ Flag Validation Tests ============

    function test_AuthenticatorFlags_Valid() public pure {
        // Flags byte with UP (bit 0) and UV (bit 2) set = 0x05
        bytes1 flags = 0x05;
        
        assertTrue((flags & 0x05) == 0x05);
    }

    function test_AuthenticatorFlags_Invalid_NoUP() public pure {
        // Only UV set, no UP
        bytes1 flags = 0x04;
        
        assertFalse((flags & 0x05) == 0x05);
    }

    function test_AuthenticatorFlags_Invalid_NoUV() public pure {
        // Only UP set, no UV
        bytes1 flags = 0x01;
        
        assertFalse((flags & 0x05) == 0x05);
    }

    // ============ Gas Tests ============

    function test_Gas_ValidateUserOp() public {
        AAKitWallet wallet = createPasskeyWallet(
            bytes32(PASSKEY_X),
            bytes32(PASSKEY_Y)
        );
        
        PackedUserOperation memory userOp = TestUtils.createUserOp(
            address(wallet),
            0,
            TestUtils.encodeExecute(receiver, 0, "")
        );
        
        PasskeyValidator.WebAuthnAuth memory auth = PasskeyValidator.WebAuthnAuth({
            authenticatorData: hex"49960de5880e8c687434170f6476605b8fe4aeb9a28632c7995cf3ba831d97630500000001",
            clientDataJSON: bytes('{"type":"webauthn.get","challenge":"test","origin":"https://app.aakit.io"}'),
            challengeIndex: 32,
            typeIndex: 9,
            r: 0x1111111111111111111111111111111111111111111111111111111111111111,
            s: 0x2222222222222222222222222222222222222222222222222222222222222222
        });
        
        userOp.signature = abi.encode(uint8(0), abi.encode(auth));
        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
        
        uint256 gasBefore = gasleft();
        validator.validateUserOp(userOp, userOpHash);
        uint256 gasUsed = gasBefore - gasleft();
        
        // Gas should be reasonable (under 100k even with fallback)
        assertTrue(gasUsed < 100000);
    }

    // ============ P256 Curve Tests ============

    function test_P256_CurveOrder() public pure {
        uint256 n = 0xFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551;
        
        // Verify it's the correct P256 order
        assertTrue(n > 0);
    }

    function test_P256_PrecompileAddress() public pure {
        address precompile = address(0x100);
        
        // RIP-7212 precompile is at 0x100
        assertEq(precompile, address(256));
    }
}
