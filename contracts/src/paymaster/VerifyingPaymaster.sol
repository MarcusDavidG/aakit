// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IPaymaster, PackedUserOperation} from "../interfaces/IERC4337.sol";

/**
 * @title VerifyingPaymaster
 * @notice Paymaster that verifies off-chain signatures for gas sponsorship
 * @dev Allows developers to sponsor user transactions with signature-based approval
 */
contract VerifyingPaymaster is IPaymaster {
    // EntryPoint address
    address public immutable entryPoint;
    
    // Verifying signer (can sponsor transactions)
    address public verifyingSigner;
    
    // Owner address
    address public owner;

    // Per-account spending tracking
    mapping(address => uint256) public spentThisPeriod;
    
    // Period start time
    uint256 public periodStart;
    
    // Period duration (e.g., 1 day)
    uint256 public constant PERIOD_DURATION = 1 days;
    
    // Per-account spending cap
    uint256 public accountSpendingCap;

    // Events
    event VerifyingSignerChanged(address indexed oldSigner, address indexed newSigner);
    event SpendingCapChanged(uint256 oldCap, uint256 newCap);
    event Sponsored(address indexed account, uint256 amount);

    // Errors
    error InvalidEntryPoint();
    error OnlyOwner();
    error OnlyEntryPoint();
    error InvalidSigner();
    error InvalidSignature();
    error SpendingCapExceeded(address account, uint256 spent, uint256 cap);

    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    modifier onlyEntryPoint() {
        if (msg.sender != entryPoint) revert OnlyEntryPoint();
        _;
    }

    /**
     * @notice Constructor
     * @param _entryPoint EntryPoint contract address
     * @param _verifyingSigner Initial verifying signer
     * @param _accountSpendingCap Per-account spending cap per period
     */
    constructor(
        address _entryPoint,
        address _verifyingSigner,
        uint256 _accountSpendingCap
    ) {
        if (_entryPoint == address(0)) revert InvalidEntryPoint();
        if (_verifyingSigner == address(0)) revert InvalidSigner();
        
        entryPoint = _entryPoint;
        verifyingSigner = _verifyingSigner;
        owner = msg.sender;
        accountSpendingCap = _accountSpendingCap;
        periodStart = block.timestamp;
    }

    /**
     * @notice Validate paymaster user operation
     * @param userOp User operation
     * @param userOpHash Hash of user operation
     * @param maxCost Maximum cost
     * @return context Context for postOp
     * @return validationData Validation result
     */
    function validatePaymasterUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 maxCost
    ) external onlyEntryPoint override returns (bytes memory context, uint256 validationData) {
        // Reset period if needed
        if (block.timestamp >= periodStart + PERIOD_DURATION) {
            periodStart = block.timestamp;
            // Note: Individual account spending is not reset here
            // Would need a more complex design for that
        }
        
        // Extract signature from paymasterAndData
        // Format: paymaster (20) || verificationGasLimit (16) || postOpGasLimit (16) || signature (variable)
        if (userOp.paymasterAndData.length < 52) {
            return ("", 1); // Invalid
        }
        
        bytes memory signature = userOp.paymasterAndData[52:];
        
        // Verify signature
        bytes32 hash = keccak256(abi.encode(
            userOpHash,
            maxCost,
            block.chainid,
            address(this)
        ));
        
        address recovered = _recoverSigner(hash, signature);
        
        if (recovered != verifyingSigner) {
            return ("", 1); // Invalid signature
        }
        
        // Check spending cap
        uint256 spent = spentThisPeriod[userOp.sender];
        if (spent + maxCost > accountSpendingCap) {
            return ("", 1); // Cap exceeded
        }
        
        // Update spent amount
        spentThisPeriod[userOp.sender] = spent + maxCost;
        
        // Return context with sender address for postOp
        context = abi.encode(userOp.sender, maxCost);
        validationData = 0; // Valid
    }

    /**
     * @notice Post-operation handler
     * @param mode Operation mode
     * @param context Context from validatePaymasterUserOp
     * @param actualGasCost Actual gas cost
     * @param actualUserOpFeePerGas Actual fee per gas
     */
    function postOp(
        PostOpMode mode,
        bytes calldata context,
        uint256 actualGasCost,
        uint256 actualUserOpFeePerGas
    ) external onlyEntryPoint override {
        // Decode context
        (address sender, uint256 maxCost) = abi.decode(context, (address, uint256));
        
        // Adjust spending based on actual cost
        uint256 refund = maxCost > actualGasCost ? maxCost - actualGasCost : 0;
        if (refund > 0) {
            spentThisPeriod[sender] -= refund;
        }
        
        emit Sponsored(sender, actualGasCost);
    }

    /**
     * @notice Recover signer from signature
     * @param hash Message hash
     * @param signature Signature bytes
     * @return Signer address
     */
    function _recoverSigner(
        bytes32 hash,
        bytes memory signature
    ) internal pure returns (address) {
        if (signature.length != 65) {
            return address(0);
        }
        
        bytes32 r;
        bytes32 s;
        uint8 v;
        
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }
        
        return ecrecover(hash, v, r, s);
    }

    /**
     * @notice Change verifying signer
     * @param newSigner New signer address
     */
    function setVerifyingSigner(address newSigner) external onlyOwner {
        if (newSigner == address(0)) revert InvalidSigner();
        
        address oldSigner = verifyingSigner;
        verifyingSigner = newSigner;
        
        emit VerifyingSignerChanged(oldSigner, newSigner);
    }

    /**
     * @notice Change spending cap
     * @param newCap New spending cap
     */
    function setAccountSpendingCap(uint256 newCap) external onlyOwner {
        uint256 oldCap = accountSpendingCap;
        accountSpendingCap = newCap;
        
        emit SpendingCapChanged(oldCap, newCap);
    }

    /**
     * @notice Deposit ETH to EntryPoint
     */
    function deposit() external payable {
        (bool success, ) = entryPoint.call{value: msg.value}(
            abi.encodeWithSignature("depositTo(address)", address(this))
        );
        require(success, "Deposit failed");
    }

    /**
     * @notice Withdraw from EntryPoint
     * @param withdrawAddress Address to withdraw to
     * @param amount Amount to withdraw
     */
    function withdrawTo(
        address payable withdrawAddress,
        uint256 amount
    ) external onlyOwner {
        (bool success, ) = entryPoint.call(
            abi.encodeWithSignature(
                "withdrawTo(address,uint256)",
                withdrawAddress,
                amount
            )
        );
        require(success, "Withdraw failed");
    }

    /**
     * @notice Add stake to EntryPoint
     * @param unstakeDelaySec Unstake delay in seconds
     */
    function addStake(uint32 unstakeDelaySec) external payable onlyOwner {
        (bool success, ) = entryPoint.call{value: msg.value}(
            abi.encodeWithSignature("addStake(uint32)", unstakeDelaySec)
        );
        require(success, "Stake failed");
    }

    /**
     * @notice Unlock stake
     */
    function unlockStake() external onlyOwner {
        (bool success, ) = entryPoint.call(
            abi.encodeWithSignature("unlockStake()")
        );
        require(success, "Unlock failed");
    }

    /**
     * @notice Withdraw stake
     * @param withdrawAddress Address to withdraw to
     */
    function withdrawStake(address payable withdrawAddress) external onlyOwner {
        (bool success, ) = entryPoint.call(
            abi.encodeWithSignature("withdrawStake(address)", withdrawAddress)
        );
        require(success, "Withdraw stake failed");
    }

    /**
     * @notice Receive ETH
     */
    receive() external payable {}
}
