import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { MockERC20, CryptoCuvee, MockVRFCoordinator } from "../typechain-types";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import type { ContractFactory } from 'ethers';

describe("CryptoCuvee", function () {
    let deployerAccount: SignerWithAddress;
    let systemWalletAccount: SignerWithAddress;
    let mockUSDC: MockERC20;
    let mockBTC: MockERC20;
    let mockETH: MockERC20;
    let cryptoCuvee: CryptoCuvee;
    let mockVRFCoordinator: MockVRFCoordinator;

    beforeEach(async function () {
        [deployerAccount, systemWalletAccount] = await ethers.getSigners();

        // Deploy mock USDC
        const MockERC20Factory = await ethers.getContractFactory("MockERC20");
        mockUSDC = await MockERC20Factory.deploy("Mock USDC", "mUSDC");
        await mockUSDC.waitForDeployment();

        // Deploy mock BTC
        mockBTC = await MockERC20Factory.deploy("Mock BTC", "mBTC");
        await mockBTC.waitForDeployment();

        // Deploy mock ETH
        mockETH = await MockERC20Factory.deploy("Mock ETH", "mETH");
        await mockETH.waitForDeployment();

        // Deploy MockVRFCoordinator
        const MockVRFCoordinatorFactory = await ethers.getContractFactory("MockVRFCoordinator");
        mockVRFCoordinator = await MockVRFCoordinatorFactory.deploy();
        await mockVRFCoordinator.waitForDeployment();

        const exampleCryptoBottle = [{
            categoryType: 1n, // Example category type
            price: ethers.parseEther("1"), // Price set to 1 ETH equivalent in USDC for example
            isLinked: false,
            tokens: [{
                name: "mBTC",
                tokenAddress: await mockBTC.getAddress(),
                quantity: 3n
            },
            {
                name: "mETH",
                tokenAddress: await mockETH.getAddress(),
                quantity: 7n
            }]
        }];

        // Mint some mock tokens for the CryptoBottle
        await mockBTC.mint(deployerAccount.address, 100n);
        await mockETH.mint(deployerAccount.address, 100n);

        // Prepare CryptoCuvee for deployment
        console.log(mockUSDC.getAddress());
        const CryptoCuveeFactory = await ethers.getContractFactory("CryptoCuvee");
        cryptoCuvee = await upgrades.deployProxy(
            CryptoCuveeFactory as ContractFactory,
            { initializer: false }
        ) as unknown as CryptoCuvee;

        await cryptoCuvee.waitForDeployment();

        // Setup allowance for CryptoCuvee to spend USDC, BTC, and ETH
        await mockUSDC.approve(await cryptoCuvee.getAddress(), 100n);
        await mockBTC.approve(await cryptoCuvee.getAddress(), 100n);
        await mockETH.approve(await cryptoCuvee.getAddress(), 100n);

        // Initialize CryptoCuvee contract
        await cryptoCuvee.initialize(
            await mockUSDC.getAddress(),
            exampleCryptoBottle,
            "https://test.com/",
            systemWalletAccount.address,
            await mockVRFCoordinator.getAddress(),
            ethers.keccak256(ethers.toUtf8Bytes("keyHash_example")), // keyHash
            200000, // callbackGasLimit
            3, // requestConfirmations
            1n // subscriptionId, assuming "1" for example
        );


    });

    it("Should mint a CryptoBottle correctly", async function () {
        // Example test that interacts with the CryptoCuvee contract
        // Assume a mint function exists that requires setting up certain conditions beforehand
        // such as approving USDC spend for the CryptoCuvee contract

        await mockUSDC.mint(deployerAccount.address, 100n);
        await mockUSDC.approve(await cryptoCuvee.getAddress(), 100n);

        // Replace with actual mint function call and parameters
        //await cryptoCuvee.mint(/* parameters for minting */);

        // Assertions to verify the minting worked as expected
        // For example, check the balance of the CryptoBottle NFTs for the deployerAccount
    });
});
