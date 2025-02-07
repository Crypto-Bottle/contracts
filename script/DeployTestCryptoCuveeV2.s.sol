// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {CryptoCuveeV2} from "../contracts/src/CryptoCuveeV2.sol";
import {MockERC20} from "../contracts/src/mocks/MockERC20.sol";

contract DeployCryptoCuveeV2 is Script {
    // Constants for token quantities
    uint256 constant ROUGE_BTC_QUANTITY = 3 ether;
    uint256 constant ROUGE_ETH_QUANTITY = 7 ether;
    uint256 constant CHAMPAGNE_BTC_QUANTITY = 4 ether;
    uint256 constant CHAMPAGNE_ETH_QUANTITY = 6 ether;

    function run() public {
        // This is a trash deploy script, it's not used in the project, reason why private keys aren't in .env file.
        // Deploy is done via dApp only!
        uint256 deployerPrivateKey = 0x0000000000000000000000000000000000000000000000000000000000000000; // Internal note: Set admin private key here
        uint256 domainWalletPrivateKey = 0x0000000000000000000000000000000000000000000000000000000000000000; // Internal note: Set domaine private key here
        address deployer = vm.addr(deployerPrivateKey);
        address domainWallet = vm.addr(domainWalletPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy mock tokens (for testing)
        MockERC20 mockStableCoin = new MockERC20("Mock Stable Coin", "mStableCoin");
        MockERC20 mockBTC = new MockERC20("Mock BTC", "mBTC");
        MockERC20 mockETH = new MockERC20("Mock ETH", "mETH");

        // Mint mock tokens to deployer
        mockBTC.mint(deployer, ROUGE_BTC_QUANTITY + CHAMPAGNE_BTC_QUANTITY);
        mockETH.mint(deployer, ROUGE_ETH_QUANTITY + CHAMPAGNE_ETH_QUANTITY);

        // Prepare category prices and total bottles
        uint256[] memory prices = new uint256[](4);
        prices[0] = 10 ether; // Rouge price
        prices[1] = 0; // Blanc price
        prices[2] = 0; // Rosé price
        prices[3] = 5 ether; // Champagne price

        uint256[] memory totalBottles = new uint256[](4);
        totalBottles[0] = 1; // Rouge total bottles
        totalBottles[1] = 0; // Blanc total bottles
        totalBottles[2] = 0; // Rosé total bottles
        totalBottles[3] = 1; // Champagne total bottles

        // Prepare tokens for each category
        CryptoCuveeV2.Token[][] memory categoryTokens = new CryptoCuveeV2.Token[][](4);

        // Rouge category tokens
        categoryTokens[0] = new CryptoCuveeV2.Token[](2);
        categoryTokens[0][0] =
            CryptoCuveeV2.Token({name: "mBTC", tokenAddress: address(mockBTC), quantity: ROUGE_BTC_QUANTITY});
        categoryTokens[0][1] =
            CryptoCuveeV2.Token({name: "mETH", tokenAddress: address(mockETH), quantity: ROUGE_ETH_QUANTITY});

        // Empty categories
        categoryTokens[1] = new CryptoCuveeV2.Token[](0);
        categoryTokens[2] = new CryptoCuveeV2.Token[](0);

        // Champagne category tokens
        categoryTokens[3] = new CryptoCuveeV2.Token[](2);
        categoryTokens[3][0] =
            CryptoCuveeV2.Token({name: "mBTC", tokenAddress: address(mockBTC), quantity: CHAMPAGNE_BTC_QUANTITY});
        categoryTokens[3][1] =
            CryptoCuveeV2.Token({name: "mETH", tokenAddress: address(mockETH), quantity: CHAMPAGNE_ETH_QUANTITY});

        // Deploy CryptoCuveeV2
        CryptoCuveeV2 cryptoCuveeV2 = new CryptoCuveeV2(
            mockStableCoin,
            prices,
            totalBottles,
            categoryTokens,
            "https://api.cryptocuvee.com/metadata/",
            deployer,
            domainWallet,
            deployer
        );

        // Approve tokens for filling bottles
        mockBTC.approve(
            address(cryptoCuveeV2),
            ROUGE_BTC_QUANTITY + CHAMPAGNE_BTC_QUANTITY // Total BTC needed
        );
        mockETH.approve(
            address(cryptoCuveeV2),
            ROUGE_ETH_QUANTITY + CHAMPAGNE_ETH_QUANTITY // Total ETH needed
        );

        // Fill bottles with tokens
        cryptoCuveeV2.fillBottles();

        // Open minting
        cryptoCuveeV2.changeMintStatus();

        vm.stopBroadcast();
    }
}
