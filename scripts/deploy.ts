import { ethers, upgrades } from "hardhat";

async function main() {
  console.log("Deploying CryptoCuvee implementation...");
  const CryptoCuvee = await ethers.getContractFactory("CryptoCuvee");

  const cryptoCuvee = await upgrades.deployProxy(CryptoCuvee, {
    initializer: false,
  });

  await cryptoCuvee.waitForDeployment();
  console.log(
    "CryptoCuvee Implementation deployed to:",
    await cryptoCuvee.getAddress(),
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
