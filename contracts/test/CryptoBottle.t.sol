// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {CryptoCuvee} from "../src/CryptoBottle.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {VRFCoordinatorV2_5Mock} from "../src/mocks/MockVRFCoordinatorV2_5.sol";

contract CryptoCuveeTest is Test {
    CryptoCuvee cryptoCuvee;
    CryptoCuvee cryptoCuvee2;
    ERC1967Proxy proxy;
    MockERC20 mockUSDC;
    MockERC20 mockBTC;
    MockERC20 mockETH;
    MockERC20 mockLINK;
    VRFCoordinatorV2_5Mock mockVRFCoordinator;

    address deployer;
    address systemWallet;
    address user1;
    address user2;

    CryptoCuvee.Token[] tokens;

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
        mockVRFCoordinator = new VRFCoordinatorV2_5Mock(1 ether, 1 ether, 1 ether);

        // Setup and fund subscription
        uint256 subId = mockVRFCoordinator.createSubscription();
        mockVRFCoordinator.fundSubscription(subId, 100_000_000 ether);

        // Deploy CryptoCuvee
        cryptoCuvee = new CryptoCuvee();
        proxy = new ERC1967Proxy(address(cryptoCuvee), "");
        CryptoCuvee.CryptoBottle[] memory bottles = new CryptoCuvee.CryptoBottle[](2);
        bottles[0] = CryptoCuvee.CryptoBottle({
            categoryType: CryptoCuvee.CategoryType.ROUGE,
            price: 10 ether,
            tokens: new CryptoCuvee.Token[](2)
        });
        bottles[0].tokens[0] = CryptoCuvee.Token({name: "mBTC", tokenAddress: address(mockBTC), quantity: 3 ether});
        bottles[0].tokens[1] = CryptoCuvee.Token({name: "mETH", tokenAddress: address(mockETH), quantity: 7 ether});

        bottles[1] = CryptoCuvee.CryptoBottle({
            categoryType: CryptoCuvee.CategoryType.CHAMPAGNE,
            price: 5 ether,
            tokens: new CryptoCuvee.Token[](2)
        });
        bottles[1].tokens[0] = CryptoCuvee.Token({name: "mBTC", tokenAddress: address(mockBTC), quantity: 4 ether});
        bottles[1].tokens[1] = CryptoCuvee.Token({name: "mETH", tokenAddress: address(mockETH), quantity: 6 ether});

        // Mint mock tokens
        mockBTC.mint(deployer, 200 ether);
        mockETH.mint(deployer, 200 ether);

        // Approve mock tokens
        mockBTC.approve(address(cryptoCuvee), 100 ether);
        mockETH.approve(address(cryptoCuvee), 100 ether);
        mockBTC.approve(address(proxy), 100 ether);
        mockETH.approve(address(proxy), 100 ether);

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

        CryptoCuvee(address(proxy)).initialize(
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
    }

    function testRedployCryptoCuveeWithoutTokens() public {
        vm.startPrank(user1);
        cryptoCuvee2 = new CryptoCuvee();
        CryptoCuvee.CryptoBottle[] memory bottles = new CryptoCuvee.CryptoBottle[](1);
        bottles[0] = CryptoCuvee.CryptoBottle({
            categoryType: CryptoCuvee.CategoryType.ROUGE,
            price: 10 ether,
            tokens: new CryptoCuvee.Token[](2)
        });
        bottles[0].tokens[0] = CryptoCuvee.Token({name: "mBTC", tokenAddress: address(mockBTC), quantity: 3 ether});
        bottles[0].tokens[1] = CryptoCuvee.Token({name: "mETH", tokenAddress: address(mockETH), quantity: 7 ether});

        vm.expectRevert(abi.encodeWithSelector(CryptoCuvee.InsufficientTokenBalance.selector, address(mockBTC), 0));
        cryptoCuvee2.initialize(
            mockUSDC,
            bottles,
            "https://test.com/",
            systemWallet,
            address(mockVRFCoordinator),
            keccak256(abi.encodePacked("keyHash_example")),
            2000000,
            1,
            1
        );
        vm.stopPrank();
    }

    function testContractInit() public {
        assertTrue(cryptoCuvee.hasRole(cryptoCuvee.SYSTEM_WALLET_ROLE(), address(systemWallet)));
    }

    function testMintCryptoBottleSystemWallet() public {
        vm.startPrank(systemWallet);
        cryptoCuvee.mint(user1, 1, CryptoCuvee.CategoryType.ROUGE);
        mockVRFCoordinator.fulfillRandomWords(1, address(cryptoCuvee));
        vm.stopPrank();
    }

    function testMintCryptoBottleChampagneSystemWallet() public {
        vm.startPrank(systemWallet);
        cryptoCuvee.mint(user1, 1, CryptoCuvee.CategoryType.CHAMPAGNE);
        mockVRFCoordinator.fulfillRandomWords(1, address(cryptoCuvee));
        vm.stopPrank();
    }

    function testMintCryptoBottleSystemWalletFullMinted() public {
        vm.startPrank(systemWallet);
        vm.expectRevert(abi.encodeWithSelector(CryptoCuvee.CategoryFullyMinted.selector));
        cryptoCuvee.mint(user1, 2, CryptoCuvee.CategoryType.ROUGE);
        vm.stopPrank();
    }

    function testMintSimultaneouslySystemWallet() public {
        vm.startPrank(systemWallet);
        cryptoCuvee.mint(user1, 1, CryptoCuvee.CategoryType.ROUGE);
        cryptoCuvee.mint(user2, 1, CryptoCuvee.CategoryType.ROUGE);
        mockVRFCoordinator.fulfillRandomWords(1, address(cryptoCuvee));
        mockVRFCoordinator.fulfillRandomWords(2, address(cryptoCuvee));
        vm.stopPrank();
    }

    function testMintCryptoBottleUser1() public {
        vm.startPrank(user1);
        // Set allowances and mint tokens
        mockUSDC.mint(user1, 100 ether);
        mockUSDC.approve(address(cryptoCuvee), 100 ether);
        cryptoCuvee.mint(user1, 1, CryptoCuvee.CategoryType.ROUGE);
        vm.stopPrank();
    }

    function testOpenBottle() public {
        vm.startPrank(user1);
        // Set allowances and mint tokens
        mockUSDC.mint(user1, 100 ether);
        mockUSDC.approve(address(cryptoCuvee), 100 ether);
        cryptoCuvee.mint(user1, 1, CryptoCuvee.CategoryType.ROUGE);
        mockVRFCoordinator.fulfillRandomWords(1, address(cryptoCuvee));
        cryptoCuvee.openBottle(1);
        vm.stopPrank();
    }

    function testOpenBottleRevert() public {
        vm.startPrank(user1);
        // Set allowances and mint tokens
        mockUSDC.mint(user1, 100 ether);
        mockUSDC.approve(address(cryptoCuvee), 100 ether);
        cryptoCuvee.mint(user1, 1, CryptoCuvee.CategoryType.ROUGE);
        mockVRFCoordinator.fulfillRandomWords(1, address(cryptoCuvee));
        cryptoCuvee.openBottle(1);
        vm.expectRevert(abi.encodeWithSelector(CryptoCuvee.BottleAlreadyOpened.selector, 1));
        cryptoCuvee.openBottle(1);
        vm.stopPrank();
    }

    function testMintWithRandomFulfillmentAndWithdraw() public {
        // Mint some USDC for user1 and set approval
        vm.startPrank(user1);
        mockUSDC.mint(user1, 100 ether);
        mockUSDC.approve(address(cryptoCuvee), 100 ether);
        // Mint a CryptoBottle
        cryptoCuvee.mint(user1, 1, CryptoCuvee.CategoryType.ROUGE);
        // Fulfill random words request
        mockVRFCoordinator.fulfillRandomWords(1, address(cryptoCuvee));
        vm.stopPrank();

        // Withdraw USDC as deployer
        vm.startPrank(deployer);
        cryptoCuvee.withdrawUSDC();
        vm.stopPrank();
    }

    function testwithdrawAllTokensBottlesNotAllOpened() public {
        // Mint some USDC for user1 and set approval
        vm.startPrank(user1);
        mockUSDC.mint(user1, 100 ether);
        mockUSDC.approve(address(cryptoCuvee), 100 ether);
        // Mint a CryptoBottle
        cryptoCuvee.mint(user1, 1, CryptoCuvee.CategoryType.ROUGE);
        // Fulfill random words request
        mockVRFCoordinator.fulfillRandomWords(1, address(cryptoCuvee));
        vm.stopPrank();

        // Withdraw all tokens
        vm.startPrank(deployer);
        cryptoCuvee.closeMinting();
        vm.expectRevert(abi.encodeWithSelector(CryptoCuvee.BottlesNotAllOpened.selector));
        cryptoCuvee.withdrawAllTokens();

        vm.stopPrank();
    }

    function testwithdrawAllTokens() public {
        // Mint some USDC for user1 and set approval
        vm.startPrank(user1);
        mockUSDC.mint(user1, 100 ether);
        mockUSDC.approve(address(cryptoCuvee), 100 ether);
        // Mint a CryptoBottle
        cryptoCuvee.mint(user1, 1, CryptoCuvee.CategoryType.ROUGE);
        // Fulfill random words request
        mockVRFCoordinator.fulfillRandomWords(1, address(cryptoCuvee));
        cryptoCuvee.openBottle(1);
        vm.stopPrank();

        // Withdraw all tokens
        vm.startPrank(deployer);
        cryptoCuvee.closeMinting();
        cryptoCuvee.withdrawAllTokens();

        // Check remaining balances
        assertEq(mockBTC.balanceOf(address(cryptoCuvee)), 0);
        assertEq(mockETH.balanceOf(address(cryptoCuvee)), 0);
        vm.stopPrank();
    }

    function testwithdrawAllTokensMintingNotClosed() public {
        // Mint some USDC for user1 and set approval
        vm.startPrank(user1);
        mockUSDC.mint(user1, 100 ether);
        mockUSDC.approve(address(cryptoCuvee), 100 ether);
        // Mint a CryptoBottle
        cryptoCuvee.mint(user1, 1, CryptoCuvee.CategoryType.ROUGE);
        // Fulfill random words request
        mockVRFCoordinator.fulfillRandomWords(1, address(cryptoCuvee));
        cryptoCuvee.openBottle(1);
        vm.stopPrank();

        // Withdraw all tokens
        vm.startPrank(deployer);
        vm.expectRevert(abi.encodeWithSelector(CryptoCuvee.MintingNotClosed.selector));
        cryptoCuvee.withdrawAllTokens();
        vm.stopPrank();
    }

    function testMintAndRetrieveTokens() public {
        // Mint some USDC for user1 and set approval
        vm.startPrank(user1);
        mockUSDC.mint(user1, 100 ether);
        mockUSDC.approve(address(cryptoCuvee), 100 ether);
        // Mint a CryptoBottle
        cryptoCuvee.mint(user1, 1, CryptoCuvee.CategoryType.ROUGE);
        // Fulfill random words request
        mockVRFCoordinator.fulfillRandomWords(1, address(cryptoCuvee));
        tokens = cryptoCuvee.getCryptoBottleTokens(1);

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

    function testQuantityMintZero() public {
        vm.startPrank(user1);
        mockUSDC.mint(user1, 100 ether);
        mockUSDC.approve(address(cryptoCuvee), 100 ether);
        vm.expectRevert(abi.encodeWithSelector(CryptoCuvee.QuantityMustBeGreaterThanZero.selector));
        cryptoCuvee.mint(user1, 0, CryptoCuvee.CategoryType.ROUGE);
        vm.stopPrank();
    }

    function testRevertWithdrawUSDCWithoutRole() public {
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                user1,
                cryptoCuvee.DEFAULT_ADMIN_ROLE()
            )
        );
        cryptoCuvee.withdrawUSDC();
        vm.stopPrank();
    }

    function testRevertCloseMintingWithoutRole() public {
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                user1,
                cryptoCuvee.DEFAULT_ADMIN_ROLE()
            )
        );
        cryptoCuvee.closeMinting();
        vm.stopPrank();
    }

    function testCloseMintingSuccessfully() public {
        vm.startPrank(deployer);
        cryptoCuvee.closeMinting();
        vm.stopPrank();

        // Try minting again and expect revert
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(CryptoCuvee.MintingClosed.selector));
        cryptoCuvee.mint(user1, 1, CryptoCuvee.CategoryType.ROUGE);
        vm.stopPrank();
    }

    function testTokenURI() public {
        vm.startPrank(user1);
        // Set allowances and mint tokens
        mockUSDC.mint(user1, 100 ether);
        mockUSDC.approve(address(cryptoCuvee), 100 ether);
        cryptoCuvee.mint(user1, 1, CryptoCuvee.CategoryType.ROUGE);
        mockVRFCoordinator.fulfillRandomWords(1, address(cryptoCuvee));
        string memory uri = cryptoCuvee.tokenURI(1);
        assertTrue(keccak256(abi.encodePacked(uri)) == keccak256(abi.encodePacked("https://test.com/1")));
        vm.stopPrank();
    }

    function testRevertCategoryFullyMinted() public {
        vm.startPrank(systemWallet);
        cryptoCuvee.mint(user1, 1, CryptoCuvee.CategoryType.ROUGE);
        mockVRFCoordinator.fulfillRandomWords(1, address(cryptoCuvee));
        assertTrue(cryptoCuvee.totalSupply() == 1);
        vm.expectRevert(CryptoCuvee.CategoryFullyMinted.selector);
        cryptoCuvee.mint(user1, 1, CryptoCuvee.CategoryType.ROUGE);
        vm.stopPrank();
    }

    function testRevertMaxQuantityReach() public {
        vm.startPrank(systemWallet);
        vm.expectRevert(CryptoCuvee.MaxQuantityReached.selector);
        cryptoCuvee.mint(user1, 4, CryptoCuvee.CategoryType.ROUGE);
        vm.stopPrank();
    }

    function testSupportsInterface() public {
        bool isSupported = cryptoCuvee.supportsInterface(0x01ffc9a7);
        assertTrue(isSupported);
    }

    function testSetDefaultRoyalty() public {
        vm.startPrank(systemWallet);
        cryptoCuvee.setDefaultRoyalty(user1, 10);
        vm.stopPrank();
    }

    function testUpgradeToAndCall() public {
        vm.startPrank(deployer);
        cryptoCuvee2 = new CryptoCuvee();
        (bool success, ) = address(proxy).call(
            abi.encodeWithSignature("upgradeToAndCall(address,bytes)", address(cryptoCuvee2), "")
        );
        require(success, "Upgrade failed");
        vm.stopPrank();
    }

    function testRevertSetDefaultRoyaltyUnauthorized() public {
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(user1),
                cryptoCuvee.SYSTEM_WALLET_ROLE()
            )
        );
        cryptoCuvee.setDefaultRoyalty(user1, 10);
        vm.stopPrank();
    }
}
