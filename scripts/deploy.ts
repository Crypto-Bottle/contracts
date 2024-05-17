import { ethers, upgrades } from "hardhat";
import { VRFCoordinatorV2Interface } from "../typechain-types";

// Deploy ONLY for polygon amoy
const polygonUSDC = "0x41E94Eb019C0762f9Bfcf9Fb1E58725BfB0e7582";
const systemWallet = "0xdec44382EAed2954e170BD2a36381A9B06627332";
const coordinator = "0x343300b5d84D444B2ADc9116FEF1bED02BE49Cf2";
const vrfCoordinatorAddress = "0x343300b5d84d444b2adc9116fef1bed02be49cf2";
const subId = ""

async function createChainlinkSubscription(
  vrfCoordinator: VRFCoordinatorV2Interface,
): Promise<string> {
  const tx = await vrfCoordinator.createSubscription();
  const receipt = await tx.wait();
  console.dir(receipt?.logs);
  const subscriptionId = BigInt(receipt?.logs?.[0]?.topics?.[1] || 0);
  if (!subscriptionId) {
    throw new Error("Subscription ID not found");
  }
  return subscriptionId.toString();
}

async function main() {
  console.log("Deploying CryptoCuvee implementation...");

  const [deployer] = await ethers.getSigners();
  const vrfCoordinator = await ethers.getContractAt(
    "VRFCoordinatorV2Interface",
    vrfCoordinatorAddress,
    deployer,
  );

  console.log("Creating Chainlink subscription...");
  const subId = await createChainlinkSubscription(vrfCoordinator);
  console.log("Chainlink subscription created with subId:", subId);

  /*const CryptoCuvee = await ethers.getContractFactory("CryptoCuvee");

  console.log("Deploying the CryptoCuvee contract...");
  const cryptoCuvee = await upgrades.deployProxy(CryptoCuvee, {
    initializer: false,
  });

  await cryptoCuvee.waitForDeployment();
  console.log(
    "CryptoCuvee Implementation deployed to:",
    await cryptoCuvee.getAddress(),
  );

  console.log("Initializing the CryptoCuvee contract...");
  const tx = await cryptoCuvee.initialize(
    polygonUSDC,
    [],
    "https://app.cryptobottle.fr/",
    systemWallet,
    coordinator,
    ethers.keccak256(ethers.toUtf8Bytes("CryptoBottleHash")),
    2000000,
    1,
    subId,
  );

  await tx.wait();
  console.log("CryptoCuvee contract initialized successfully");*/
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
