import { ethers } from "hardhat";
import { CryptoCuvee } from "../typechain-types";

async function main() {
  // Get the first signer (default wallet)
  const [signer] = await ethers.getSigners();
  const walletAddress = await signer.getAddress();
  console.log(`Using wallet address: ${walletAddress}`);

  // Define the addresses
  const polygonUSDC = "0x677cf65f71bf80ffa5d77dc35ef85624daa05f0c"; // Custom ERC20 to test
  const proxy = "0xbaa0ebd9d0ab3d9ea45981c402f02635f87ed95f";

  // Get the contract factory for CryptoCuvee
  const CryptoCuveeFactory = await ethers.getContractFactory("CryptoCuvee");

  // Attach the CryptoCuvee contract to the proxy address
  const cryptoCuvee = CryptoCuveeFactory.attach(proxy) as CryptoCuvee;

  // Get the USDC contract instance
  const usdc = await ethers.getContractAt("IERC20", polygonUSDC, signer);

  // Check USDC balance before approving
  const usdcBalance = await usdc.balanceOf(walletAddress);
  console.log(`USDC balance: ${usdcBalance.toString()}`);

  // Approve the proxy to spend USDC on behalf of the wallet
  const approveTx = await usdc.approve(proxy, ethers.MaxUint256);
  console.log(`Approval transaction hash: ${approveTx.hash}`);
  await approveTx.wait();
  console.log("USDC approved for proxy");

  // Check the allowance
  const allowance = await usdc.allowance(walletAddress, proxy);
  console.log(`USDC allowance for proxy: ${allowance.toString()}`);

  // Add try-catch around the mint function to capture detailed errors
  try {
    // Call the mint function on CryptoCuvee contract
    const mintTx = await cryptoCuvee.mint(walletAddress, 1, 1);
    console.log(`Mint transaction hash: ${mintTx.hash}`);
    await mintTx.wait();
    console.log("Minting completed");
  } catch (error) {
    console.error("Error during minting:", error);
  }
}

// Execute the main function and handle errors
main().catch((error) => {
  console.error("Error in script execution:", error);
  process.exitCode = 1;
});
