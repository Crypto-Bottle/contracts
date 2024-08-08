import { ethers } from "hardhat";
import { IVRFCoordinatorV2Plus } from "../typechain-types";

// Deploy ONLY for polygon amoy
const polygonUSDC = "0x5809A528f705E0E7e7debb051d63994800111E63"; // Custom ERC20 to test
const systemWallet = "0x66776a6df6622c671E8fa3E1aeC9a4404D22a7cA";
const coordinator = "0x343300b5d84D444B2ADc9116FEF1bED02BE49Cf2";
//const vrfCoordinatorAddress = "0x343300b5d84d444b2adc9116fef1bed02be49cf2";
const subId =
  "32661733261404588143174815268949173524595912581425273350345660355849544508561";

export async function createChainlinkSubscription(
  vrfCoordinator: IVRFCoordinatorV2Plus,
): Promise<string> {
  const tx = await vrfCoordinator.createSubscription();
  const receipt = await tx.wait();
  const subscriptionId = BigInt(receipt?.logs?.[0]?.topics?.[1] || 0);
  if (!subscriptionId) {
    throw new Error("Subscription ID not found");
  }
  return subscriptionId.toString();
}

async function deployImplementation() {
  const gasPrice = await ethers.provider.getFeeData();
  console.log("Deploying CryptoCuvee implementation...");
  /*
    const [deployer] = await ethers.getSigners();
    const vrfCoordinator = await ethers.getContractAt(
      "IVRFCoordinatorV2Plus",
      vrfCoordinatorAddress,
      deployer,
    );

    console.log("Creating Chainlink subscription...");
    const subId = await createChainlinkSubscription(vrfCoordinator);
    console.log("Chainlink subscription created with subId:", subId);
  */
  const CryptoCuvee = await ethers.getContractFactory("CryptoCuvee");

  console.log("Deploying the CryptoCuvee Implementation contract...");
  const cryptoCuvee = await CryptoCuvee.deploy();

  // Prevent contract from being initialized again
  await cryptoCuvee.initialize(
    polygonUSDC,
    [],
    "https://app.cryptobottle.fr/api/metadata/",
    systemWallet,
    systemWallet,
    coordinator,
    ethers.keccak256(ethers.toUtf8Bytes("CryptoBottleHash")),
    2000000,
    1,
    subId,
  );

  console.log(
    `CryptoCuvee Implementation deployed to: ${await cryptoCuvee.getAddress()}`,
  );
}

async function main() {
  await deployImplementation();
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
