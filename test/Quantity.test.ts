import { ethers, upgrades } from "hardhat";
import {
  MockERC20,
  MockCryptoCuvee,
  VRFCoordinatorV2_5Mock,
} from "../typechain-types";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import type { ContractFactory, EventLog } from "ethers";

type TokenInfo = {
  mBTC: { address: string };
  mETH: { address: string };
  mLINK: { address: string };
  mUSDC: { address: string };
  [key: string]: { address: string };
};

type Token = { name: string; tokenAddress: string; quantity: bigint };

type CryptoBottle = {
  categoryType: bigint;
  price: bigint;
  isLinked: boolean;
  tokens: { name: string; tokenAddress: string; quantity: bigint }[];
};

const generateBottles = (
  tokenInfo: TokenInfo,
  numBottlesPerCategory: number,
  numTokensPerBottle: number,
): Array<any> => {
  const categories = [0, 1, 2, 3];
  let bottles: CryptoBottle[] = [];

  categories.forEach((categoryType) => {
    for (let i = 0; i < numBottlesPerCategory; i++) {
      const tokensSelected: Token[] = [];

      for (let j = 0; j < numTokensPerBottle; j++) {
        const tokenIndex = Math.floor(Math.random() * 3);
        const token = Object.keys(tokenInfo)[tokenIndex];
        const tokenAddress = tokenInfo[token].address;
        tokensSelected.push({
          name: token,
          tokenAddress: tokenAddress,
          quantity: BigInt(1 + Math.floor(Math.random() * 4)), // Random quantity
        });
      }

      bottles.push({
        categoryType: BigInt(categoryType),
        price: BigInt(5 + (categoryType - 1) * 3), // Arbitrary price logic for each category
        isLinked: false,
        tokens: tokensSelected,
      });
    }
  });

  return bottles;
};

describe("CryptoCuvee", () => {
  let deployerAccount: SignerWithAddress;
  let systemWalletAccount: SignerWithAddress;
  let user1: SignerWithAddress;
  let mockUSDC: MockERC20;
  let mockBTC: MockERC20;
  let mockETH: MockERC20;
  let mockLINK: MockERC20;
  let cryptoCuvee: MockCryptoCuvee;
  let mockVRFCoordinator: VRFCoordinatorV2_5Mock;

  it("should deploy CryptoCuvee contract", async () => {
    [deployerAccount, systemWalletAccount, user1] = await ethers.getSigners();

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

    const tokenInfo: TokenInfo = {
      mBTC: { address: await mockBTC.getAddress() },
      mETH: { address: await mockETH.getAddress() },
      mLINK: { address: await mockLINK.getAddress() },
      mUSDC: { address: await mockUSDC.getAddress() },
    };

    const exampleCryptoBottle = generateBottles(tokenInfo, 31, 2);

    const amount = ethers.parseEther("1000000000000");

    // Mint some mock tokens for the CryptoBottle
    await mockBTC.mint(deployerAccount.address, amount);
    await mockETH.mint(deployerAccount.address, amount);
    await mockLINK.mint(deployerAccount.address, amount);
    await mockUSDC.mint(deployerAccount.address, amount);

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
      .approve(await cryptoCuvee.getAddress(), amount);
    await mockBTC
      .connect(deployerAccount)
      .approve(await cryptoCuvee.getAddress(), amount);
    await mockETH
      .connect(deployerAccount)
      .approve(await cryptoCuvee.getAddress(), amount);
    await mockLINK
      .connect(deployerAccount)
      .approve(await cryptoCuvee.getAddress(), amount);

    // Initialize CryptoCuvee contract
    await cryptoCuvee.connect(deployerAccount).initialize(
      await mockUSDC.getAddress(),
      exampleCryptoBottle,
      "https://test.com/",
      systemWalletAccount.address,
      deployerAccount.address,
      mockCoordinatorAddress,
      ethers.keccak256(ethers.toUtf8Bytes("keyHash_example")), // keyHash
      2000000, // callbackGasLimit
      1, // requestConfirmations
      subId, // subscriptionId, assuming "1" for example
    );
  });
});
