// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {CryptoCuveeV3} from "../src/CryptoCuveeV3.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract CryptoCuveeV3Test is Test {
    CryptoCuveeV3 cryptoCuveeV3;
    MockERC20 mockStableCoin;
    MockERC20 mockBTC;
    MockERC20 mockETH;
    MockERC20 mockLINK;

    address deployer;
    address systemWallet;
    address user1;
    address user2;

    uint256 constant ROUGE_BTC_QUANTITY = 3 ether;
    uint256 constant ROUGE_ETH_QUANTITY = 7 ether;
    uint256 constant CHAMPAGNE_BTC_QUANTITY = 4 ether;
    uint256 constant CHAMPAGNE_ETH_QUANTITY = 6 ether;

    CryptoCuveeV3.Token[] tokens;

    function setUp() public {
        deployer = address(this);
        systemWallet = makeAddr("systemWallet");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Deploy mock tokens
        mockStableCoin = new MockERC20("Mock Stable Coin", "mStableCoin");
        mockBTC = new MockERC20("Mock BTC", "mBTC");
        mockETH = new MockERC20("Mock ETH", "mETH");
        mockLINK = new MockERC20("Mock LINK", "mLINK");

        // Mint mock tokens
        mockBTC.mint(deployer, 200 ether);
        mockETH.mint(deployer, 200 ether);

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
        CryptoCuveeV3.Token[][] memory categoryTokens = new CryptoCuveeV3.Token[][](4);

        // Rouge category tokens
        categoryTokens[0] = new CryptoCuveeV3.Token[](2);
        categoryTokens[0][0] =
            CryptoCuveeV3.Token({name: "mBTC", tokenAddress: address(mockBTC), quantity: ROUGE_BTC_QUANTITY});
        categoryTokens[0][1] =
            CryptoCuveeV3.Token({name: "mETH", tokenAddress: address(mockETH), quantity: ROUGE_ETH_QUANTITY});

        // Blanc category tokens
        categoryTokens[1] = new CryptoCuveeV3.Token[](0);

        // Rosé category tokens
        categoryTokens[2] = new CryptoCuveeV3.Token[](0);

        // Champagne category tokens
        categoryTokens[3] = new CryptoCuveeV3.Token[](2);
        categoryTokens[3][0] =
            CryptoCuveeV3.Token({name: "mBTC", tokenAddress: address(mockBTC), quantity: CHAMPAGNE_BTC_QUANTITY});
        categoryTokens[3][1] =
            CryptoCuveeV3.Token({name: "mETH", tokenAddress: address(mockETH), quantity: CHAMPAGNE_ETH_QUANTITY});

        // Deploy CryptoCuveeV3
        cryptoCuveeV3 = new CryptoCuveeV3(
            mockStableCoin, prices, totalBottles, categoryTokens, "https://test.com/", systemWallet, address(deployer)
        );

        // Approve mock tokens after deployment
        mockBTC.approve(address(cryptoCuveeV3), 100 ether);
        mockETH.approve(address(cryptoCuveeV3), 100 ether);

        // Fill bottles
        cryptoCuveeV3.fillBottles();
    }

    /// @notice Verifies system wallet role was correctly assigned during initialization
    function testContractInit() public view {
        assertTrue(cryptoCuveeV3.hasRole(cryptoCuveeV3.SYSTEM_WALLET_ROLE(), address(systemWallet)));
    }

    /// @notice Ensures bottles cannot be filled twice
    function testRevertFillBottles() public {
        vm.expectRevert(abi.encodeWithSelector(CryptoCuveeV3.BottlesAlreadyFilled.selector));
        cryptoCuveeV3.fillBottles();
    }

    /// @notice Tests minting Rouge bottle by system wallet
    function testMintCryptoBottleSystemWallet() public {
        vm.startPrank(systemWallet);
        cryptoCuveeV3.mint(user1, 1, 0); // Category 0 (Rouge)
        vm.stopPrank();
    }

    /// @notice Tests minting Champagne bottle by system wallet
    function testMintCryptoBottleChampagneSystemWallet() public {
        vm.startPrank(systemWallet);
        cryptoCuveeV3.mint(user1, 1, 3); // Category 3 (Champagne)
        vm.stopPrank();
    }

    /// @notice Verifies that minting more bottles than allowed in a category fails
    function testRevertMintCryptoBottleSystemWalletFullMinted() public {
        vm.startPrank(systemWallet);
        vm.expectRevert(abi.encodeWithSelector(CryptoCuveeV3.CategoryFullyMinted.selector));
        cryptoCuveeV3.mint(user1, 2, 0); // Try to mint 2 Rouge bottles
        vm.stopPrank();
    }

    /// @notice Tests setting the maximum quantity that can be minted
    function testSetMaxQuantityMintable() public {
        vm.startPrank(deployer);
        cryptoCuveeV3.setMaxQuantityMintable(5);
        vm.stopPrank();
    }

    /// @notice Verifies total supply increases correctly after minting multiple bottles
    function testMintTwiceAndCheckTotalSupply() public {
        vm.startPrank(systemWallet);
        cryptoCuveeV3.mint(user1, 1, 0); // Rouge
        cryptoCuveeV3.mint(user2, 1, 3); // Champagne
        assertEq(cryptoCuveeV3.totalSupply(), 2);
        vm.stopPrank();
    }

    /// @notice Ensures simultaneous minting of a fully minted category reverts
    function testRevertMintSimultaneouslySystemWallet() public {
        vm.startPrank(systemWallet);
        cryptoCuveeV3.mint(user1, 1, 0); // Rouge
        vm.expectRevert(abi.encodeWithSelector(CryptoCuveeV3.CategoryFullyMinted.selector));
        cryptoCuveeV3.mint(user2, 1, 0); // Try to mint another Rouge
        vm.stopPrank();
    }

    /// @notice Tests minting process for a regular user with stable coin
    function testMintCryptoBottleUser1() public {
        vm.startPrank(user1);
        mockStableCoin.mint(user1, 100 ether);
        mockStableCoin.approve(address(cryptoCuveeV3), 100 ether);
        cryptoCuveeV3.mint(user1, 1, 0); // Rouge
        assertEq(mockStableCoin.balanceOf(user1), 100 ether - 10 ether);
        vm.stopPrank();
    }

    /// @notice Tests opening a single bottle
    function testOpenBottle() public {
        vm.startPrank(user1);
        mockStableCoin.mint(user1, 100 ether);
        mockStableCoin.approve(address(cryptoCuveeV3), 100 ether);
        cryptoCuveeV3.mint(user1, 1, 0);
        cryptoCuveeV3.openBottle(1);
        vm.stopPrank();
    }

    /// @notice Tests opening multiple bottles at once and verifies token distributions
    function testOpenMultipleBottles() public {
        // Setup: Mint 2 bottles to user1
        vm.startPrank(user1);
        mockStableCoin.mint(user1, 100 ether);
        mockStableCoin.approve(address(cryptoCuveeV3), 100 ether);
        cryptoCuveeV3.mint(user1, 1, 0); // Mint Rouge (tokenId 1)
        cryptoCuveeV3.mint(user1, 1, 3); // Mint Champagne (tokenId 2)

        // Create array of token IDs to open
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;

        // Record initial balances
        uint256 initialBTCBalance = mockBTC.balanceOf(user1);
        uint256 initialETHBalance = mockETH.balanceOf(user1);

        // Open both bottles
        cryptoCuveeV3.openBottles(tokenIds);

        // Verify both bottles are marked as opened
        assertTrue(cryptoCuveeV3.openedBottles(1));
        assertTrue(cryptoCuveeV3.openedBottles(2));

        // Calculate expected token amounts (90% of total)
        // Rouge: ROUGE_BTC_QUANTITY + ROUGE_ETH_QUANTITY
        // Champagne: CHAMPAGNE_BTC_QUANTITY + CHAMPAGNE_ETH_QUANTITY
        uint256 expectedBTCBalance = initialBTCBalance + ((ROUGE_BTC_QUANTITY + CHAMPAGNE_BTC_QUANTITY) * 90) / 100;
        uint256 expectedETHBalance = initialETHBalance + ((ROUGE_ETH_QUANTITY + CHAMPAGNE_ETH_QUANTITY) * 90) / 100;

        // Verify final balances
        assertEq(mockBTC.balanceOf(user1), expectedBTCBalance);
        assertEq(mockETH.balanceOf(user1), expectedETHBalance);
        vm.stopPrank();
    }

    /// @notice Verifies that non-owners cannot open bottles
    function testRevertOpenBottleNotOwner() public {
        vm.startPrank(user1);
        mockStableCoin.mint(user1, 100 ether);
        mockStableCoin.approve(address(cryptoCuveeV3), 100 ether);
        cryptoCuveeV3.mint(user1, 1, 0);
        vm.stopPrank();

        vm.startPrank(user2);
        vm.expectRevert(abi.encodeWithSelector(CryptoCuveeV3.NotOwnerBottle.selector, 1));
        cryptoCuveeV3.openBottle(1);
        vm.stopPrank();
    }

    /// @notice Ensures a bottle cannot be opened twice
    function testRevertOpenBottleTwice() public {
        vm.startPrank(user1);
        mockStableCoin.mint(user1, 100 ether);
        mockStableCoin.approve(address(cryptoCuveeV3), 100 ether);
        cryptoCuveeV3.mint(user1, 1, 0);
        cryptoCuveeV3.openBottle(1);
        vm.expectRevert(abi.encodeWithSelector(CryptoCuveeV3.BottleAlreadyOpened.selector, 1));
        cryptoCuveeV3.openBottle(1);
        vm.stopPrank();
    }

    /// @notice Tests minting then  withdrawing stable coin by owner
    function testMintAndWithdraw() public {
        vm.startPrank(user1);
        mockStableCoin.mint(user1, 100 ether);
        mockStableCoin.approve(address(cryptoCuveeV3), 100 ether);
        cryptoCuveeV3.mint(user1, 1, 0);
        vm.stopPrank();

        vm.startPrank(deployer);
        cryptoCuveeV3.withdrawStableCoin();
        vm.stopPrank();
    }

    /// @notice Tests withdrawing all tokens after closing minting
    function testWithdrawAllTokens() public {
        vm.startPrank(user1);
        mockStableCoin.mint(user1, 100 ether);
        mockStableCoin.approve(address(cryptoCuveeV3), 100 ether);
        cryptoCuveeV3.mint(user1, 1, 0);
        cryptoCuveeV3.mint(user1, 1, 3);
        cryptoCuveeV3.openBottle(1);
        vm.stopPrank();

        vm.startPrank(deployer);
        cryptoCuveeV3.changeMintingStatus();
        cryptoCuveeV3.withdrawAllTokens();
        vm.expectRevert(abi.encodeWithSelector(CryptoCuveeV3.AllTokensWithdrawn.selector));
        cryptoCuveeV3.changeMintingStatus();
        vm.expectRevert(abi.encodeWithSelector(CryptoCuveeV3.AllTokensWithdrawn.selector));
        cryptoCuveeV3.withdrawAllTokens();

        // Check if the tokens are withdrawn - mockBTC balance must be CHAMPAGNE_BTC_QUANTITY because only the first bottle is opened
        assertEq(mockBTC.balanceOf(address(cryptoCuveeV3)), CHAMPAGNE_BTC_QUANTITY);
        // Check if the tokens are withdrawn - mockETH balance must be CHAMPAGNE_ETH_QUANTITY because only the first bottle is opened
        assertEq(mockETH.balanceOf(address(cryptoCuveeV3)), CHAMPAGNE_ETH_QUANTITY);
        vm.stopPrank();
    }

    /// @notice Verifies tokens cannot be withdrawn while minting is still active
    function testRevertWithdrawAllTokensMintingNotClosed() public {
        vm.startPrank(user1);
        mockStableCoin.mint(user1, 100 ether);
        mockStableCoin.approve(address(cryptoCuveeV3), 100 ether);
        cryptoCuveeV3.mint(user1, 1, 0);
        cryptoCuveeV3.openBottle(1);
        vm.stopPrank();

        vm.startPrank(deployer);
        vm.expectRevert(abi.encodeWithSelector(CryptoCuveeV3.MintingNotClosed.selector));
        cryptoCuveeV3.withdrawAllTokens();
        vm.stopPrank();
    }

    /// @notice Tests minting and retrieving token information
    function testMintAndRetrieveTokens() public {
        vm.startPrank(user1);
        mockStableCoin.mint(user1, 100 ether);
        mockStableCoin.approve(address(cryptoCuveeV3), 100 ether);
        cryptoCuveeV3.mint(user1, 1, 0);
        tokens = cryptoCuveeV3.getCryptoBottleTokens(1);

        assertEq(tokens.length, 2);
        assertEq(tokens[0].name, "mBTC");
        assertEq(tokens[0].tokenAddress, address(mockBTC));
        assertEq(tokens[0].quantity, ROUGE_BTC_QUANTITY);

        assertEq(tokens[1].name, "mETH");
        assertEq(tokens[1].tokenAddress, address(mockETH));
        assertEq(tokens[1].quantity, ROUGE_ETH_QUANTITY);
        vm.stopPrank();
    }

    /// @notice Ensures minting with zero quantity fails
    function testRevertMintZeroQuantity() public {
        vm.startPrank(user1);
        mockStableCoin.mint(user1, 100 ether);
        mockStableCoin.approve(address(cryptoCuveeV3), 100 ether);
        vm.expectRevert(abi.encodeWithSelector(CryptoCuveeV3.QuantityMustBeGreaterThanZero.selector));
        cryptoCuveeV3.mint(user1, 0, 0);
        vm.stopPrank();
    }

    /// @notice Verifies that unauthorized accounts cannot withdraw stable coin
    function testRevertWithdrawStableCoinWithoutRole() public {
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, user1, cryptoCuveeV3.DEFAULT_ADMIN_ROLE()
            )
        );
        cryptoCuveeV3.withdrawStableCoin();
        vm.stopPrank();
    }

    /// @notice Ensures unauthorized accounts cannot change minting status
    function testRevertchangeMintingStatusWithoutRole() public {
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, user1, cryptoCuveeV3.DEFAULT_ADMIN_ROLE()
            )
        );
        cryptoCuveeV3.changeMintingStatus();
        vm.stopPrank();
    }

    /// @notice Tests successful minting status change and subsequent mint rejection
    function testChangeMintingStatusSuccessfully() public {
        vm.startPrank(deployer);
        cryptoCuveeV3.changeMintingStatus();
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(CryptoCuveeV3.MintingClosed.selector));
        cryptoCuveeV3.mint(user1, 1, 0);
        vm.stopPrank();
    }

    /// @notice Tests correct token URI generation
    function testTokenURI() public {
        vm.startPrank(user1);
        mockStableCoin.mint(user1, 100 ether);
        mockStableCoin.approve(address(cryptoCuveeV3), 100 ether);
        cryptoCuveeV3.mint(user1, 1, 0);
        string memory uri = cryptoCuveeV3.tokenURI(1);
        assertTrue(keccak256(abi.encodePacked(uri)) == keccak256(abi.encodePacked("https://test.com/1")));
        vm.stopPrank();
    }

    /// @notice Verifies that minting fails when category is fully minted
    function testRevertCategoryFullyMinted() public {
        vm.startPrank(systemWallet);
        cryptoCuveeV3.mint(user1, 1, 0);
        assertTrue(cryptoCuveeV3.totalSupply() == 1);
        vm.expectRevert(CryptoCuveeV3.CategoryFullyMinted.selector);
        cryptoCuveeV3.mint(user1, 1, 0);
        vm.stopPrank();
    }

    /// @notice Ensures minting fails when attempting to exceed max quantity
    function testRevertMaxQuantityReach() public {
        vm.startPrank(systemWallet);
        vm.expectRevert(CryptoCuveeV3.MaxQuantityReached.selector);
        cryptoCuveeV3.mint(user1, 4, 0);
        vm.stopPrank();
    }

    /// @notice Tests ERC165 interface support
    function testSupportsInterface() public view {
        bool isSupported = cryptoCuveeV3.supportsInterface(0x01ffc9a7);
        assertTrue(isSupported);
    }

    /// @notice Tests setting default royalty by system wallet
    function testSetDefaultRoyalty() public {
        vm.startPrank(systemWallet);
        cryptoCuveeV3.setDefaultRoyalty(user1, 10);
        vm.stopPrank();
    }

    /// @notice Ensures unauthorized accounts cannot set default royalty
    function testRevertSetDefaultRoyaltyUnauthorized() public {
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(user1),
                cryptoCuveeV3.SYSTEM_WALLET_ROLE()
            )
        );
        cryptoCuveeV3.setDefaultRoyalty(user1, 10);
        vm.stopPrank();
    }

    /// @notice Tests setting and retrieving updated base URI
    function testSetBaseURI() public {
        // Initial URI check
        vm.startPrank(user1);
        mockStableCoin.mint(user1, 100 ether);
        mockStableCoin.approve(address(cryptoCuveeV3), 100 ether);
        cryptoCuveeV3.mint(user1, 1, 0);
        string memory initialUri = cryptoCuveeV3.tokenURI(1);
        assertTrue(keccak256(abi.encodePacked(initialUri)) == keccak256(abi.encodePacked("https://test.com/1")));
        vm.stopPrank();

        // Update URI
        vm.startPrank(deployer);
        cryptoCuveeV3.setBaseURI("https://test2.com/");
        vm.stopPrank();

        // Verify updated URI
        string memory newUri = cryptoCuveeV3.tokenURI(1);
        assertTrue(keccak256(abi.encodePacked(newUri)) == keccak256(abi.encodePacked("https://test2.com/1")));
    }

    /// @notice Ensures unauthorized accounts cannot set base URI
    function testRevertSetBaseURIUnauthorized() public {
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(user1),
                cryptoCuveeV3.DEFAULT_ADMIN_ROLE()
            )
        );
        cryptoCuveeV3.setBaseURI("https://test2.com/");
        vm.stopPrank();
    }
}
