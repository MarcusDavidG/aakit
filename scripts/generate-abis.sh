#!/bin/bash
# Generate ABI types for TypeScript SDK

set -e

echo "Generating ABIs from Foundry artifacts..."

# Create output directory
mkdir -p sdk/src/abis

# Copy contract ABIs
contracts=(
  "AAKitWallet"
  "AAKitFactory"
  "PasskeyValidator"
  "VerifyingPaymaster"
  "IERC4337"
  "IERC7579"
)

for contract in "${contracts[@]}"; do
  echo "Extracting $contract ABI..."
  
  # Find the JSON artifact
  artifact=$(find contracts/out -name "${contract}.sol" -type d | head -1)
  
  if [ -n "$artifact" ]; then
    json_file="$artifact/${contract}.json"
    
    if [ -f "$json_file" ]; then
      # Extract ABI and format it
      jq '.abi' "$json_file" > "sdk/src/abis/${contract}.json"
      echo "✓ Generated sdk/src/abis/${contract}.json"
    fi
  fi
done

echo ""
echo "✓ ABI generation complete!"
echo "ABIs saved to: sdk/src/abis/"
