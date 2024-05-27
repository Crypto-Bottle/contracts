import { ethers, upgrades } from "hardhat";
import { IVRFCoordinatorV2Plus } from "../typechain-types";
import { getImplementationAddress } from "@openzeppelin/upgrades-core";

// Deploy ONLY for polygon amoy
const polygonUSDC = "0x677Cf65f71Bf80fFa5D77Dc35EF85624DAa05f0c"; // Custom ERC20 to test
const systemWallet = "0x66776a6df6622c671E8fa3E1aeC9a4404D22a7cA";
const coordinator = "0x343300b5d84D444B2ADc9116FEF1bED02BE49Cf2";
const vrfCoordinatorAddress = "0x343300b5d84d444b2adc9116fef1bed02be49cf2";
const subId =
  "32661733261404588143174815268949173524595912581425273350345660355849544508561";

async function main() {}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
