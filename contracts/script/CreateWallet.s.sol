// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script, console2} from "forge-std/Script.sol";
import {AAKitFactory} from "../src/factory/AAKitFactory.sol";
import {AAKitWallet} from "../src/wallet/AAKitWallet.sol";

/**
 * @title Create Wallet Script
 * @notice Script to create a test wallet
 * @dev Run with: forge script script/CreateWallet.s.sol:CreateWalletScript --rpc-url <network> --broadcast
 */
contract CreateWalletScript is Script {
    function run() external {
        // Get deployer
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // Get factory address from deployment
        address factoryAddress = vm.envAddress("FACTORY_ADDRESS");
        AAKitFactory factory = AAKitFactory(factoryAddress);
        
        console2.log("Creating wallet from factory:", factoryAddress);
        console2.log("Owner:", deployer);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Encode owner as address (20 bytes)
        bytes memory ownerBytes = abi.encodePacked(deployer);
        
        // Create wallet with salt 0
        address wallet = factory.createAccount(ownerBytes, 0);
        
        console2.log("Wallet created:", wallet);
        
        // Fund wallet with some ETH
        (bool success, ) = wallet.call{value: 0.01 ether}("");
        require(success, "Failed to fund wallet");
        
        console2.log("Wallet funded with 0.01 ETH");
        
        vm.stopBroadcast();
        
        // Print wallet info
        console2.log("\n========================================");
        console2.log("    Wallet Created Successfully");
        console2.log("========================================");
        console2.log("Wallet Address:", wallet);
        console2.log("Owner:", deployer);
        console2.log("Balance:", wallet.balance);
        console2.log("========================================\n");
    }
}
