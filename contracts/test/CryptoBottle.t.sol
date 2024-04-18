// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {CryptoCuvee} from "../src/CryptoBottle.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {VRFCoordinatorV2Mock} from "../src/mocks/MockVRFCoordinator.sol";

contract CryptoCuveeTest is Test {
    CryptoCuvee cryptoCuvee;
    MockERC20 mockUSDC;
    MockERC20 mockBTC;
    MockERC20 mockETH;
    MockERC20 mockLINK;
    VRFCoordinatorV2Mock mockVRFCoordinator;

    address deployer;
    address systemWallet;
    address user1;
    address user2;

    function setUp() public {
        deployer = address(this);
        systemWallet = makeAddr("systemWallet");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Deploy mock tokens
        mockUSDC = new MockERC20("Mock USDC", "mUSDC");
        mockBTC = new MockERC20("Mock BTC", "mBTC");
        mockETH = new MockERC20("Mock ETH", "mETH");
        mockLINK = new MockERC20("Mock LINK", "mLINK");

        // Deploy MockVRFCoordinator
        mockVRFCoordinator = new VRFCoordinatorV2Mock(1, 1);

        // Setup and fund subscription
        uint64 subId = mockVRFCoordinator.createSubscription();
        mockLINK.mint(deployer, 100_000_000 ether);
        mockLINK.approve(address(mockVRFCoordinator), 100_000_000 ether);
        mockVRFCoordinator.fundSubscription(subId, 100_000_000 ether);

        // Deploy CryptoCuvee
        cryptoCuvee = new CryptoCuvee();
        CryptoCuvee.CryptoBottle[] memory bottles = new CryptoCuvee.CryptoBottle[](1);
        bottles[0] = CryptoCuvee.CryptoBottle({
            categoryType: CryptoCuvee.CategoryType.ROUGE,
            price: 10 ether,
            isLinked: false,
            tokens: new CryptoCuvee.Token[](2)
        });
        bottles[0].tokens[0] = CryptoCuvee.Token({name: "mBTC", tokenAddress: address(mockBTC), quantity: 3});
        bottles[0].tokens[1] = CryptoCuvee.Token({name: "mETH", tokenAddress: address(mockETH), quantity: 7});

        // Mint mock tokens
        mockBTC.mint(deployer, 100 ether);
        mockETH.mint(deployer, 100 ether);

        // Approve mock tokens
        mockBTC.approve(address(cryptoCuvee), 100 ether);
        mockETH.approve(address(cryptoCuvee), 100 ether);

        cryptoCuvee.initialize(
            mockUSDC,
            bottles,
            "https://test.com/",
            systemWallet,
            address(mockVRFCoordinator),
            keccak256(abi.encodePacked("keyHash_example")),
            2000000,
            1,
            subId
        );

        // Add cryptoCuvee as a consumer
        mockVRFCoordinator.addConsumer(subId, address(cryptoCuvee));

        // Set allowances and mint tokens
        mockUSDC.mint(user1, 100 ether);
        mockUSDC.approve(address(cryptoCuvee), 100 ether);
    }

    function testMintCryptoBottleSystemWallet() public {
        vm.startPrank(systemWallet);
        cryptoCuvee.mint(user1, 1, CryptoCuvee.CategoryType.ROUGE);
        vm.stopPrank();
    }
    /*
    function testMintCryptoBottleUser1() public {
        vm.prank(user1);
        cryptoCuvee.mint(user1, 1, CryptoCuvee.CategoryType.ROUGE);
    }

    function testRevertMintingInsufficientUSDC() public {
        vm.startPrank(user2);
        vm.expectRevert("ERC20InsufficientAllowance");
        cryptoCuvee.mint(user2, 1, CryptoCuvee.CategoryType.ROUGE);
        vm.stopPrank();
    }

    function testRevertCategoryFullyMinted() public {
        vm.startPrank(user1);
        vm.expectRevert("CategoryFullyMinted");
        cryptoCuvee.mint(user1, 1, CryptoCuvee.CategoryType.ROUGE);
        vm.stopPrank();
    }

    function testCheckSubscriptionFundingBalance() public view {
        (uint256 balance,,,) = mockVRFCoordinator.getSubscription(1);
        assertEq(balance, 100_001_000 ether);
    }*/
}
