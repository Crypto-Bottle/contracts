import { ethers, upgrades } from "hardhat";

async function main() {
  console.log("Deploying CryptoCuvee implementation...");
  const CryptoCuvee = await ethers.getContractFactory("CryptoCuvee");

  const cryptoCuvee = await upgrades.deployProxy(CryptoCuvee, {
    initializer: false,
  });

  await cryptoCuvee.deployed();
  console.log("CryptoCuvee Implementation deployed to:", cryptoCuvee.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
