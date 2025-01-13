// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {CryptoCuveeV2} from "../src/CryptoBottleV2.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {console} from "hardhat/console.sol";

contract CryptoCuveeV2Test is Test {
    CryptoCuveeV2 cryptoCuveeV2;
    MockERC20 mockUSDC;
    MockERC20 mockBTC;
    MockERC20 mockETH;
    MockERC20 mockLINK;

    address deployer;
    address systemWallet;
    address user1;
    address user2;

    CryptoCuveeV2.Token[] tokens;

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

        // Mint mock tokens
        mockBTC.mint(deployer, 200 ether);
        mockETH.mint(deployer, 200 ether);

        // Prepare CryptoCuveeV2
        CryptoCuveeV2.CryptoBottle[] memory bottles = new CryptoCuveeV2.CryptoBottle[](2);
        bottles[0] = CryptoCuveeV2.CryptoBottle({
            categoryType: CryptoCuveeV2.CategoryType.ROUGE,
            price: 10 ether,
            tokens: new CryptoCuveeV2.Token[](2)
        });
        bottles[0].tokens[0] = CryptoCuveeV2.Token({name: "mBTC", tokenAddress: address(mockBTC), quantity: 3 ether});
        bottles[0].tokens[1] = CryptoCuveeV2.Token({name: "mETH", tokenAddress: address(mockETH), quantity: 7 ether});

        bottles[1] = CryptoCuveeV2.CryptoBottle({
            categoryType: CryptoCuveeV2.CategoryType.CHAMPAGNE,
            price: 5 ether,
            tokens: new CryptoCuveeV2.Token[](2)
        });
        bottles[1].tokens[0] = CryptoCuveeV2.Token({name: "mBTC", tokenAddress: address(mockBTC), quantity: 4 ether});
        bottles[1].tokens[1] = CryptoCuveeV2.Token({name: "mETH", tokenAddress: address(mockETH), quantity: 6 ether});

        // Deploy CryptoCuveeV2
        cryptoCuveeV2 = new CryptoCuveeV2(mockUSDC, bottles, "https://test.com/", systemWallet, address(deployer));

        // Approve mock tokens after deployment
        mockBTC.approve(address(cryptoCuveeV2), 100 ether);
        mockETH.approve(address(cryptoCuveeV2), 100 ether);

        // Fill bottles
        cryptoCuveeV2.fillBottles();
    }

    function testContractInit() public view {
        assertTrue(cryptoCuveeV2.hasRole(cryptoCuveeV2.SYSTEM_WALLET_ROLE(), address(systemWallet)));
    }

    function testRevertFillBottles() public {
        vm.expectRevert(abi.encodeWithSelector(CryptoCuveeV2.BottlesAlreadyFilled.selector));
        cryptoCuveeV2.fillBottles();
    }

    function testMintCryptoBottleSystemWallet() public {
        vm.startPrank(systemWallet);
        cryptoCuveeV2.mint(user1, 1, CryptoCuveeV2.CategoryType.ROUGE);
        vm.stopPrank();
    }

    function testMintCryptoBottleChampagneSystemWallet() public {
        vm.startPrank(systemWallet);
        cryptoCuveeV2.mint(user1, 1, CryptoCuveeV2.CategoryType.CHAMPAGNE);
        vm.stopPrank();
    }

    function testRevertMintCryptoBottleSystemWalletFullMinted() public {
        vm.startPrank(systemWallet);
        vm.expectRevert(abi.encodeWithSelector(CryptoCuveeV2.CategoryFullyMinted.selector));
        cryptoCuveeV2.mint(user1, 2, CryptoCuveeV2.CategoryType.ROUGE);
        vm.stopPrank();
    }

    function testSetMaxQuantityMintable() public {
        vm.startPrank(deployer);
        cryptoCuveeV2.setMaxQuantityMintable(5);
        vm.stopPrank();
    }

    function testMintTwiceAndCheckTotalSupply() public {
        vm.startPrank(systemWallet);
        cryptoCuveeV2.mint(user1, 1, CryptoCuveeV2.CategoryType.ROUGE);
        cryptoCuveeV2.mint(user2, 1, CryptoCuveeV2.CategoryType.CHAMPAGNE);
        assertEq(cryptoCuveeV2.totalSupply(), 2);
        vm.stopPrank();
    }

    function testRevertMintSimultaneouslySystemWallet() public {
        vm.startPrank(systemWallet);
        cryptoCuveeV2.mint(user1, 1, CryptoCuveeV2.CategoryType.ROUGE);
        vm.expectRevert(abi.encodeWithSelector(CryptoCuveeV2.CategoryFullyMinted.selector));
        cryptoCuveeV2.mint(user2, 1, CryptoCuveeV2.CategoryType.ROUGE);
        vm.stopPrank();
    }

    function testMintCryptoBottleUser1() public {
        vm.startPrank(user1);
        // Set allowances and mint tokens
        mockUSDC.mint(user1, 100 ether);
        mockUSDC.approve(address(cryptoCuveeV2), 100 ether);
        cryptoCuveeV2.mint(user1, 1, CryptoCuveeV2.CategoryType.ROUGE);
        vm.stopPrank();
    }

    function testOpenBottle() public {
        vm.startPrank(user1);
        // Set allowances and mint tokens
        mockUSDC.mint(user1, 100 ether);
        mockUSDC.approve(address(cryptoCuveeV2), 100 ether);
        cryptoCuveeV2.mint(user1, 1, CryptoCuveeV2.CategoryType.ROUGE);
        cryptoCuveeV2.openBottle(1);
        vm.stopPrank();
    }

    function testRevertOpenBottleNotOwner() public {
        vm.startPrank(user1);
        // Set allowances and mint tokens
        mockUSDC.mint(user1, 100 ether);
        mockUSDC.approve(address(cryptoCuveeV2), 100 ether);
        cryptoCuveeV2.mint(user1, 1, CryptoCuveeV2.CategoryType.ROUGE);
        vm.stopPrank();
        vm.startPrank(user2);
        vm.expectRevert(abi.encodeWithSelector(CryptoCuveeV2.NotOwnerBottle.selector, 1));
        cryptoCuveeV2.openBottle(1);
        vm.stopPrank();
    }

    function testRevertOpenBottleTwice() public {
        vm.startPrank(user1);
        // Set allowances and mint tokens
        mockUSDC.mint(user1, 100 ether);
        mockUSDC.approve(address(cryptoCuveeV2), 100 ether);
        cryptoCuveeV2.mint(user1, 1, CryptoCuveeV2.CategoryType.ROUGE);
        cryptoCuveeV2.openBottle(1);
        vm.expectRevert(abi.encodeWithSelector(CryptoCuveeV2.BottleAlreadyOpened.selector, 1));
        cryptoCuveeV2.openBottle(1);
        vm.stopPrank();
    }

    function testMintAndWithdraw() public {
        // Mint some USDC for user1 and set approval
        vm.startPrank(user1);
        mockUSDC.mint(user1, 100 ether);
        mockUSDC.approve(address(cryptoCuveeV2), 100 ether);
        // Mint a CryptoBottle
        cryptoCuveeV2.mint(user1, 1, CryptoCuveeV2.CategoryType.ROUGE);
        vm.stopPrank();

        // Withdraw USDC as deployer
        vm.startPrank(deployer);
        cryptoCuveeV2.withdrawUSDC();
        vm.stopPrank();
    }

    function testWithdrawAllTokens() public {
        // Mint some USDC for user1 and set approval
        vm.startPrank(user1);
        mockUSDC.mint(user1, 100 ether);
        mockUSDC.approve(address(cryptoCuveeV2), 100 ether);
        // Mint a CryptoBottle
        cryptoCuveeV2.mint(user1, 1, CryptoCuveeV2.CategoryType.ROUGE);
        cryptoCuveeV2.openBottle(1);
        vm.stopPrank();

        // Withdraw all tokens
        vm.startPrank(deployer);
        cryptoCuveeV2.changeMintingStatus();
        cryptoCuveeV2.withdrawAllTokens();
        vm.expectRevert(abi.encodeWithSelector(CryptoCuveeV2.AllTokensWithdrawn.selector));
        cryptoCuveeV2.changeMintingStatus();
        vm.expectRevert(abi.encodeWithSelector(CryptoCuveeV2.AllTokensWithdrawn.selector));
        cryptoCuveeV2.withdrawAllTokens();

        // Check remaining balances
        assertEq(mockBTC.balanceOf(address(cryptoCuveeV2)), 0);
        assertEq(mockETH.balanceOf(address(cryptoCuveeV2)), 0);
        vm.stopPrank();
    }

    function testRevertWithdrawAllTokensMintingNotClosed() public {
        // Mint some USDC for user1 and set approval
        vm.startPrank(user1);
        mockUSDC.mint(user1, 100 ether);
        mockUSDC.approve(address(cryptoCuveeV2), 100 ether);
        // Mint a CryptoBottle
        cryptoCuveeV2.mint(user1, 1, CryptoCuveeV2.CategoryType.ROUGE);
        cryptoCuveeV2.openBottle(1);
        vm.stopPrank();

        // Withdraw all tokens
        vm.startPrank(deployer);
        vm.expectRevert(abi.encodeWithSelector(CryptoCuveeV2.MintingNotClosed.selector));
        cryptoCuveeV2.withdrawAllTokens();
        vm.stopPrank();
    }

    function testMintAndRetrieveTokens() public {
        // Mint some USDC for user1 and set approval
        vm.startPrank(user1);
        mockUSDC.mint(user1, 100 ether);
        mockUSDC.approve(address(cryptoCuveeV2), 100 ether);
        // Mint a CryptoBottle
        cryptoCuveeV2.mint(user1, 1, CryptoCuveeV2.CategoryType.ROUGE);
        tokens = cryptoCuveeV2.getCryptoBottleTokens(1);

        // Check tokens array is returning the correct values
        assertEq(tokens.length, 2);
        assertEq(tokens[0].name, "mBTC");
        assertEq(tokens[0].tokenAddress, address(mockBTC));
        assertEq(tokens[0].quantity, 3 ether);

        assertEq(tokens[1].name, "mETH");
        assertEq(tokens[1].tokenAddress, address(mockETH));
        assertEq(tokens[1].quantity, 7 ether);
        vm.stopPrank();
    }

    function testRevertMintZeroQuantity() public {
        vm.startPrank(user1);
        mockUSDC.mint(user1, 100 ether);
        mockUSDC.approve(address(cryptoCuveeV2), 100 ether);
        vm.expectRevert(abi.encodeWithSelector(CryptoCuveeV2.QuantityMustBeGreaterThanZero.selector));
        cryptoCuveeV2.mint(user1, 0, CryptoCuveeV2.CategoryType.ROUGE);
        vm.stopPrank();
    }

    function testRevertWithdrawUSDCWithoutRole() public {
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, user1, cryptoCuveeV2.DEFAULT_ADMIN_ROLE()
            )
        );
        cryptoCuveeV2.withdrawUSDC();
        vm.stopPrank();
    }

    function testRevertchangeMintingStatusWithoutRole() public {
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, user1, cryptoCuveeV2.DEFAULT_ADMIN_ROLE()
            )
        );
        cryptoCuveeV2.changeMintingStatus();
        vm.stopPrank();
    }

    function testChangeMintingStatusSuccessfully() public {
        vm.startPrank(deployer);
        cryptoCuveeV2.changeMintingStatus();
        vm.stopPrank();

        // Try minting again and expect revert
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(CryptoCuveeV2.MintingClosed.selector));
        cryptoCuveeV2.mint(user1, 1, CryptoCuveeV2.CategoryType.ROUGE);
        vm.stopPrank();
    }

    function testTokenURI() public {
        vm.startPrank(user1);
        // Set allowances and mint tokens
        mockUSDC.mint(user1, 100 ether);
        mockUSDC.approve(address(cryptoCuveeV2), 100 ether);
        cryptoCuveeV2.mint(user1, 1, CryptoCuveeV2.CategoryType.ROUGE);
        string memory uri = cryptoCuveeV2.tokenURI(1);
        assertTrue(keccak256(abi.encodePacked(uri)) == keccak256(abi.encodePacked("https://test.com/1")));
        vm.stopPrank();
    }

    function testRevertCategoryFullyMinted() public {
        vm.startPrank(systemWallet);
        cryptoCuveeV2.mint(user1, 1, CryptoCuveeV2.CategoryType.ROUGE);
        assertTrue(cryptoCuveeV2.totalSupply() == 1);
        vm.expectRevert(CryptoCuveeV2.CategoryFullyMinted.selector);
        cryptoCuveeV2.mint(user1, 1, CryptoCuveeV2.CategoryType.ROUGE);
        vm.stopPrank();
    }

    function testRevertMaxQuantityReach() public {
        vm.startPrank(systemWallet);
        vm.expectRevert(CryptoCuveeV2.MaxQuantityReached.selector);
        cryptoCuveeV2.mint(user1, 4, CryptoCuveeV2.CategoryType.ROUGE);
        vm.stopPrank();
    }

    function testSupportsInterface() public view {
        bool isSupported = cryptoCuveeV2.supportsInterface(0x01ffc9a7);
        assertTrue(isSupported);
    }

    function testSetDefaultRoyalty() public {
        vm.startPrank(systemWallet);
        cryptoCuveeV2.setDefaultRoyalty(user1, 10);
        vm.stopPrank();
    }

    function testRevertSetDefaultRoyaltyUnauthorized() public {
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(user1),
                cryptoCuveeV2.SYSTEM_WALLET_ROLE()
            )
        );
        cryptoCuveeV2.setDefaultRoyalty(user1, 10);
        vm.stopPrank();
    }
}
