import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import {
  MockERC20,
  MockCryptoCuvee,
  VRFCoordinatorV2_5Mock,
} from "../typechain-types";
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
  let cryptoCuvee: MockCryptoCuvee;
  let mockVRFCoordinator: VRFCoordinatorV2_5Mock;

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
    const MockVRFCoordinatorFactory = await ethers.getContractFactory(
      "VRFCoordinatorV2_5Mock",
    );
    mockVRFCoordinator = await MockVRFCoordinatorFactory.deploy(
      ethers.parseEther("1"),
      ethers.parseEther("1"),
      ethers.parseEther("1"),
    );
    await mockVRFCoordinator.waitForDeployment();

    const tx = await mockVRFCoordinator
      .connect(deployerAccount)
      .createSubscription();
    const receipt = await tx.wait();
    const subId = (receipt?.logs[0] as EventLog)?.args[0] ?? 1n;

    const mockCoordinatorAddress = await mockVRFCoordinator.getAddress();
    // Fund subscription
    await mockVRFCoordinator.fundSubscription(
      subId,
      ethers.parseEther("100000000"),
    );

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
    const CryptoCuveeFactory =
      await ethers.getContractFactory("MockCryptoCuvee");
    cryptoCuvee = (await upgrades.deployProxy(
      CryptoCuveeFactory as ContractFactory,
      { initializer: false },
    )) as unknown as MockCryptoCuvee;

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
    await cryptoCuvee
      .connect(systemWalletAccount)
      .mint(deployerAccount.address, 1n, 1n);
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
      cryptoCuvee.connect(user1).mint(user1.address, 1, 2),
    ).to.be.revertedWithCustomError(cryptoCuvee, "CategoryFullyMinted");
  });

  it("Should test supportInterface of cryptobottle contract", async () => {
    const isSupported = await cryptoCuvee.supportsInterface("0x01ffc9a7");
    expect(isSupported).to.equal(true);
  });

  it("Should revert if the role is not granted when setDefaultRoyalty", async () => {
    await expect(
      cryptoCuvee.connect(user1).setDefaultRoyalty(user1.address, 10),
    ).to.be.revertedWithCustomError(
      cryptoCuvee,
      "AccessControlUnauthorizedAccount",
    );
  });

  it("Should set default royalty correctly", async () => {
    await cryptoCuvee
      .connect(deployerAccount)
      .setDefaultRoyalty(user1.address, 10);
  });

  it("Should successfully mint with random fulfillment simulation from chainlink and withdrawal from deployer", async () => {
    await cryptoCuvee.connect(user1).mint(user1.address, 1, 1n);
    await mockVRFCoordinator.fulfillRandomWords(
      1n,
      await cryptoCuvee.getAddress(),
    );
    await cryptoCuvee.connect(deployerAccount).withdrawUSDC();
  });

  it("Should revert if the role is not granted when withdrawUSDC", async () => {
    await expect(
      cryptoCuvee.connect(user1).withdrawUSDC(),
    ).to.be.revertedWithCustomError(
      cryptoCuvee,
      "AccessControlUnauthorizedAccount",
    );
  });

  it("Should revert if the role is not granted when closeMinting", async () => {
    await expect(
      cryptoCuvee.connect(user1).closeMinting(),
    ).to.be.revertedWithCustomError(
      cryptoCuvee,
      "AccessControlUnauthorizedAccount",
    );
  });

  it("Should close minting successfully", async () => {
    await cryptoCuvee.connect(deployerAccount).closeMinting();
    await expect(
      cryptoCuvee.connect(user1).mint(user1.address, 1, 1n),
    ).to.be.revertedWithCustomError(cryptoCuvee, "MintingClosed");

    // Check that no remaining balance is left mBTC and mETH
    expect(await mockBTC.balanceOf(await cryptoCuvee.getAddress())).to.equal(0);
    expect(await mockETH.balanceOf(await cryptoCuvee.getAddress())).to.equal(0);
  });

  it("Should revert if the quantity to be mint is more than 3", async () => {
    await expect(
      cryptoCuvee.connect(user1).mint(user1.address, 4, 1n),
    ).to.be.revertedWithCustomError(cryptoCuvee, "MaxQuantityReached");
  });

  it("Should upgrade the implementation", async () => {
    // change the implementation of the contract
    const CryptoCuveeFactory =
      await ethers.getContractFactory("MockCryptoCuvee");
    await upgrades.upgradeProxy(
      await cryptoCuvee.getAddress(),
      CryptoCuveeFactory,
    );
  });

  it("Should revert if the role is not admin for upgrade", async () => {
    const CryptoCuveeFactory = await ethers.getContractFactory("CryptoCuvee", {
      signer: user1,
    });
    await expect(
      upgrades.upgradeProxy(await cryptoCuvee.getAddress(), CryptoCuveeFactory),
    ).to.be.revertedWithCustomError(
      cryptoCuvee,
      "AccessControlUnauthorizedAccount",
    );
  });

  it("Should mint a bottle and open a bottle with releasing the tokens", async () => {
    await cryptoCuvee.connect(user1).mint(user1.address, 1, 1n);
    await mockVRFCoordinator.fulfillRandomWords(
      1n,
      await cryptoCuvee.getAddress(),
    );
    await cryptoCuvee.connect(user1).openBottle(1);
  });

  it("Should successfully return tokenURI", async () => {
    // Mint a bottle
    await cryptoCuvee.connect(user1).mint(user1.address, 1, 1n);
    await mockVRFCoordinator.fulfillRandomWords(
      1n,
      await cryptoCuvee.getAddress(),
    );
    expect(await cryptoCuvee.tokenURI(1)).to.equal("https://test.com/1");
  });

  it("Should test increase balance", async () => {
    await expect(
      cryptoCuvee.testIncreaseBalance(user1.address, 1n),
    ).to.be.revertedWithCustomError(
      cryptoCuvee,
      "ERC721EnumerableForbiddenBatchMint",
    );
  });
});

describe("CryptoCuvee wrong init", () => {
  let deployerAccount: SignerWithAddress;
  let systemWalletAccount: SignerWithAddress;
  let mockUSDC: MockERC20;
  let mockBTC: MockERC20;
  let mockETH: MockERC20;
  let mockLINK: MockERC20;
  let cryptoCuvee: MockCryptoCuvee;
  let mockVRFCoordinator: VRFCoordinatorV2_5Mock;

  beforeEach(async () => {
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

    mockLINK = await MockERC20Factory.deploy("Mock LINK", "mLINK");
    await mockLINK.waitForDeployment();

    // Deploy MockVRFCoordinator
    const MockVRFCoordinatorFactory = await ethers.getContractFactory(
      "VRFCoordinatorV2_5Mock",
    );
    mockVRFCoordinator = await MockVRFCoordinatorFactory.deploy(1n, 1n, 1n);
    await mockVRFCoordinator.waitForDeployment();

    const tx = await mockVRFCoordinator
      .connect(deployerAccount)
      .createSubscription();
    const receipt = await tx.wait();
    const subId = (receipt?.logs[0] as EventLog)?.args[0] ?? 1n;
    await mockVRFCoordinator.fundSubscription(subId, 1000n);

    const mockCoordinatorAddress = await mockVRFCoordinator.getAddress();

    // Fund subscription
    await mockLINK.mint(deployerAccount.address, 100_000_000n);
    await mockLINK.approve(mockCoordinatorAddress, 100_000_000n);
    await mockVRFCoordinator.fundSubscription(subId, 100_000_000n);

    // Prepare CryptoCuvee for deployment
    const CryptoCuveeFactory =
      await ethers.getContractFactory("MockCryptoCuvee");
    cryptoCuvee = (await upgrades.deployProxy(
      CryptoCuveeFactory as ContractFactory,
      { initializer: false },
    )) as unknown as MockCryptoCuvee;

    await cryptoCuvee.waitForDeployment();

    // Add the CryptoBottle contract as a consumer
    await mockVRFCoordinator.addConsumer(subId, await cryptoCuvee.getAddress());
  });

  it("Should revert if we try to re initialize the contract", async () => {
    // Mint some mock tokens for the CryptoBottle
    await mockBTC.mint(deployerAccount.address, 100n);
    await mockETH.mint(deployerAccount.address, 100n);

    // Initialize CryptoCuvee contract
    await cryptoCuvee.connect(deployerAccount).initialize(
      await mockUSDC.getAddress(),
      [],
      "https://test.com/",
      systemWalletAccount.address,
      await mockVRFCoordinator.getAddress(),
      ethers.keccak256(ethers.toUtf8Bytes("keyHash_example")), // keyHash
      2000000, // callbackGasLimit
      1, // requestConfirmations
      1,
    );

    await expect(
      cryptoCuvee.connect(deployerAccount).initialize(
        await mockUSDC.getAddress(),
        [],
        "https://test.com/",
        systemWalletAccount.address,
        await mockVRFCoordinator.getAddress(),
        ethers.keccak256(ethers.toUtf8Bytes("keyHash_example")), // keyHash
        2000000, // callbackGasLimit
        1, // requestConfirmations
        1, // subscriptionId, assuming "1" for example
      ),
    ).to.be.revertedWithCustomError(cryptoCuvee, "InvalidInitialization");
  });

  it("Should revert if not sufficient token amount", async () => {
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

    await expect(
      cryptoCuvee.connect(deployerAccount).initialize(
        await mockUSDC.getAddress(),
        exampleCryptoBottle,
        "https://test.com/",
        systemWalletAccount.address,
        await mockVRFCoordinator.getAddress(),
        ethers.keccak256(ethers.toUtf8Bytes("keyHash_example")), // keyHash
        2000000, // callbackGasLimit
        1, // requestConfirmations
        1, // subscriptionId, assuming "1" for example
      ),
    ).to.be.revertedWithCustomError(cryptoCuvee, "InsufficientTokenBalance");
  });
});
