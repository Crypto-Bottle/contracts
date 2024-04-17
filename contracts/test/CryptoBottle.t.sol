// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.23;

import {CryptoCuvee} from "../src/CryptoBottle.sol";
import {MockERC20} from "../src/mock/MockERC20.sol";
import {VRFCoordinatorV2Mock} from "../src/mock/MockVRFCoordinator.sol";
import {Test} from "forge-std/Test.sol";

contract CryptoCuveeTest is Test {
    CryptoCuvee cryptoCuvee;

    function setUp() public {
        // Setup parameters for initializing the CryptoCuvee contract
        MockERC20 usdc = new MockERC20("USD Coin", "USDC");
        CryptoCuvee.CryptoBottle[] memory bottles = new CryptoCuvee.CryptoBottle[](1);
        bottles[0] = CryptoCuvee.CryptoBottle({
            categoryType: CryptoCuvee.CategoryType.ROUGE,
            price: 1 ether, // Example price
            isLinked: true,
            tokens: new CryptoCuvee.Token[](1)
        });
        bottles[0].tokens[0] = CryptoCuvee.Token({name: "Example Token", tokenAddress: address(usdc), quantity: 100});

        // Mock addresses for VRF and system wallet
        address vrfCoordinator = address(new VRFCoordinatorV2Mock(100, 100));
        address systemWallet = address(1);

        // Mint USDC tokens to this contract
        usdc.mint(address(this), 1000 ether);
        usdc.approve(address(this), 1000 ether);

        // Initialize the contract
        cryptoCuvee = new CryptoCuvee();
        cryptoCuvee.initialize(
            usdc,
            bottles,
            "https://example.com/api/",
            systemWallet,
            vrfCoordinator,
            0x0, // Example keyHash
            200000, // Example callbackGasLimit
            3, // Example requestConfirmations
            1 // Example subscriptionId
        );
    }

    function testCreateCuvee() public {
        // We'll try minting a CryptoBottle
        vm.startPrank(address(1));
        uint32 quantity = 1;
        cryptoCuvee.mint(address(1), quantity, CryptoCuvee.CategoryType.ROUGE);

        // Check the balance of the minted tokens
        assertEq(cryptoCuvee.balanceOf(address(1)), quantity);
        vm.stopPrank();
    }
}
