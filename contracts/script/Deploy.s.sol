// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script, console2} from "forge-std/Script.sol";
import {AAKitWallet} from "../src/wallet/AAKitWallet.sol";
import {AAKitFactory} from "../src/factory/AAKitFactory.sol";
import {PasskeyValidator} from "../src/validators/PasskeyValidator.sol";
import {VerifyingPaymaster} from "../src/paymaster/VerifyingPaymaster.sol";

/**
 * @title Deploy Script
 * @notice Deployment script for AAKit contracts
 * @dev Run with: forge script script/Deploy.s.sol:DeployScript --rpc-url <network> --broadcast
 */
contract DeployScript is Script {
    // ERC-4337 v0.7 EntryPoint (same on all chains)
    address constant ENTRYPOINT = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;
    
    // Deployment configuration
    struct DeploymentConfig {
        address entryPoint;
        address paymasterSigner;
        uint256 paymasterSpendingCap;
    }

    function run() external {
        // Get deployer from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console2.log("Deploying from:", deployer);
        console2.log("Balance:", deployer.balance);
        
        require(deployer.balance > 0.1 ether, "Insufficient balance for deployment");
        
        // Get configuration
        DeploymentConfig memory config = getConfig();
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. Deploy PasskeyValidator
        console2.log("\n=== Deploying PasskeyValidator ===");
        PasskeyValidator passkeyValidator = new PasskeyValidator();
        console2.log("PasskeyValidator:", address(passkeyValidator));
        
        // 2. Deploy AAKitWallet implementation
        console2.log("\n=== Deploying AAKitWallet Implementation ===");
        AAKitWallet walletImplementation = new AAKitWallet(config.entryPoint);
        console2.log("AAKitWallet Implementation:", address(walletImplementation));
        
        // 3. Deploy AAKitFactory
        console2.log("\n=== Deploying AAKitFactory ===");
        AAKitFactory factory = new AAKitFactory(
            address(walletImplementation),
            config.entryPoint
        );
        console2.log("AAKitFactory:", address(factory));
        
        // 4. Deploy VerifyingPaymaster
        console2.log("\n=== Deploying VerifyingPaymaster ===");
        VerifyingPaymaster paymaster = new VerifyingPaymaster(
            config.entryPoint,
            config.paymasterSigner,
            config.paymasterSpendingCap
        );
        console2.log("VerifyingPaymaster:", address(paymaster));
        
        // 5. Fund paymaster
        console2.log("\n=== Funding Paymaster ===");
        uint256 paymasterDeposit = 0.05 ether;
        (bool success, ) = address(paymaster).call{value: paymasterDeposit}("");
        require(success, "Failed to fund paymaster");
        console2.log("Paymaster funded with:", paymasterDeposit);
        
        vm.stopBroadcast();
        
        // Print deployment summary
        printDeploymentSummary(
            address(walletImplementation),
            address(factory),
            address(passkeyValidator),
            address(paymaster)
        );
        
        // Save deployment addresses
        saveDeployment(
            address(walletImplementation),
            address(factory),
            address(passkeyValidator),
            address(paymaster)
        );
    }
    
    function getConfig() internal view returns (DeploymentConfig memory) {
        // Get paymaster signer from env or use deployer
        address paymasterSigner;
        try vm.envAddress("PAYMASTER_SIGNER") returns (address signer) {
            paymasterSigner = signer;
        } catch {
            paymasterSigner = vm.addr(vm.envUint("PRIVATE_KEY"));
        }
        
        // Get spending cap from env or use default
        uint256 spendingCap;
        try vm.envUint("PAYMASTER_SPENDING_CAP") returns (uint256 cap) {
            spendingCap = cap;
        } catch {
            spendingCap = 1 ether; // Default 1 ETH per account
        }
        
        return DeploymentConfig({
            entryPoint: ENTRYPOINT,
            paymasterSigner: paymasterSigner,
            paymasterSpendingCap: spendingCap
        });
    }
    
    function printDeploymentSummary(
        address walletImpl,
        address factory,
        address validator,
        address paymaster
    ) internal view {
        console2.log("\n========================================");
        console2.log("    AAKit Deployment Summary");
        console2.log("========================================");
        console2.log("Network:", block.chainid);
        console2.log("EntryPoint:", ENTRYPOINT);
        console2.log("----------------------------------------");
        console2.log("AAKitWallet Implementation:", walletImpl);
        console2.log("AAKitFactory:", factory);
        console2.log("PasskeyValidator:", validator);
        console2.log("VerifyingPaymaster:", paymaster);
        console2.log("========================================\n");
    }
    
    function saveDeployment(
        address walletImpl,
        address factory,
        address validator,
        address paymaster
    ) internal {
        string memory json = string.concat(
            '{\n',
            '  "chainId": ', vm.toString(block.chainid), ',\n',
            '  "entryPoint": "', vm.toString(ENTRYPOINT), '",\n',
            '  "walletImplementation": "', vm.toString(walletImpl), '",\n',
            '  "factory": "', vm.toString(factory), '",\n',
            '  "passkeyValidator": "', vm.toString(validator), '",\n',
            '  "verifyingPaymaster": "', vm.toString(paymaster), '"\n',
            '}'
        );
        
        string memory filename = string.concat(
            "deployment-",
            vm.toString(block.chainid),
            ".json"
        );
        
        vm.writeFile(
            string.concat("deployments/", filename),
            json
        );
        
        console2.log("Deployment saved to:", filename);
    }
}
