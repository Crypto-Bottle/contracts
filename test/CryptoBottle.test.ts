import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { MockERC20, CryptoCuvee, VRFCoordinatorV2Mock } from "../typechain-types";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import type { ContractFactory, EventLog } from "ethers";

describe("CryptoCuvee", () => {
  let deployerAccount: SignerWithAddress;
  let systemWalletAccount: SignerWithAddress;
  let user1: SignerWithAddress;
  let user2: SignerWithAddress;
  let mockUSDC: MockERC20;
  let mockBTC: MockERC20;
  let mockETH: MockERC20;
  let mockLINK: MockERC20;
  let cryptoCuvee: CryptoCuvee;
  let mockVRFCoordinator: VRFCoordinatorV2Mock;

  beforeEach(async () => {
    [deployerAccount, systemWalletAccount, user1, user2] =
      await ethers.getSigners();

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

    mockLINK = await MockERC20Factory.deploy("Mock LINK", "mLINK");
    await mockLINK.waitForDeployment();

    // Deploy MockVRFCoordinator
    const MockVRFCoordinatorFactory =
      await ethers.getContractFactory("VRFCoordinatorV2Mock");
    mockVRFCoordinator = await MockVRFCoordinatorFactory.deploy(100000000000000000n, 1e9);
    await mockVRFCoordinator.waitForDeployment();

    const tx = await mockVRFCoordinator.connect(deployerAccount).createSubscription();
    const receipt = await tx.wait()
    const subId = (receipt?.logs[0] as EventLog)?.args[0] ?? 1n;
    await mockVRFCoordinator.fundSubscription(subId, 1000n);

    const mockCoordinatorAddress = await mockVRFCoordinator.getAddress();

    // Fund subscription 
    await mockLINK.mint(deployerAccount.address, 1000n);
    await mockLINK.approve(mockCoordinatorAddress, 1000n);
    await mockVRFCoordinator.fundSubscription(subId, 1000n);

    const exampleCryptoBottle = [
      {
        categoryType: 1n, // Example category type
        price: 10n,
        isLinked: false,
        tokens: [
          {
            name: "mBTC",
            tokenAddress: await mockBTC.getAddress(),
            quantity: 3n,
          },
          {
            name: "mETH",
            tokenAddress: await mockETH.getAddress(),
            quantity: 7n,
          },
        ],
      },
    ];

    // Mint some mock tokens for the CryptoBottle
    await mockBTC.mint(deployerAccount.address, 100n);
    await mockETH.mint(deployerAccount.address, 100n);

    // Prepare CryptoCuvee for deployment
    const CryptoCuveeFactory = await ethers.getContractFactory("CryptoCuvee");
    cryptoCuvee = (await upgrades.deployProxy(
      CryptoCuveeFactory as ContractFactory,
      { initializer: false },
    )) as unknown as CryptoCuvee;

    await cryptoCuvee.waitForDeployment();

    // Add the CryptoBottle contract as a consumer
    await mockVRFCoordinator.addConsumer(subId, await cryptoCuvee.getAddress());

    // Setup allowance for CryptoCuvee to spend USDC, BTC, and ETH
    await mockUSDC
      .connect(deployerAccount)
      .approve(await cryptoCuvee.getAddress(), 100n);
    await mockBTC
      .connect(deployerAccount)
      .approve(await cryptoCuvee.getAddress(), 100n);
    await mockETH
      .connect(deployerAccount)
      .approve(await cryptoCuvee.getAddress(), 100n);

    // Initialize CryptoCuvee contract
    await cryptoCuvee.connect(deployerAccount).initialize(
      await mockUSDC.getAddress(),
      exampleCryptoBottle,
      "https://test.com/",
      systemWalletAccount.address,
      mockCoordinatorAddress,
      ethers.keccak256(ethers.toUtf8Bytes("keyHash_example")), // keyHash
      2000000, // callbackGasLimit
      1, // requestConfirmations
      subId, // subscriptionId, assuming "1" for example
    );

    await mockUSDC.connect(user1).mint(user1.address, 100n);
    await mockUSDC.connect(user1).approve(await cryptoCuvee.getAddress(), 100n);
  });

  it("Should mint a CryptoBottle correctly with system wallet", async () => {
    try {
      const tx = await cryptoCuvee
        .connect(systemWalletAccount)
        .mint(deployerAccount.address, 1n, 1n);
      await tx.wait();
    } catch (error) {
      console.log(error);
    }

  });

  it("Should mint a CryptoBottle correctly with user1 wallet", async () => {
    await cryptoCuvee.connect(user1).mint(user1.address, 1, 1n);
  });

  it("Should revert minting a CryptoBottle with insufficient USDC", async () => {
    await expect(
      cryptoCuvee.connect(user2).mint(user2.address, 1, 1n),
    ).to.be.revertedWithCustomError(mockUSDC, "ERC20InsufficientAllowance");
  });

  it("Should revert if the category is totally minted", async () => {
    await expect(
      cryptoCuvee.connect(user1).mint(user1.address, 1, 2)
    ).to.be.revertedWithCustomError(cryptoCuvee, "CategoryFullyMinted");
  });

  it("Should successfully mint with random fulfillment simulation from chainlink", async () => {
    await cryptoCuvee.connect(user1).mint(user1.address, 1, 1n);
    // We need to simulate the fulfillRandomWords function call from the VRFCoordinator
    await cryptoCuvee
      .connect(deployerAccount)
      .rawFulfillRandomWords(1, [Math.floor(Math.random() * 1000000)]);
  });
});
