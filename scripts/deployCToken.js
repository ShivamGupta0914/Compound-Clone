
const hre = require("hardhat");

async function main() {
  const cQodContract = await ethers.getContractFactory("CQod");
  const CQOD = await cQodContract.deploy();
  await CQOD.deployed();
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});



////////////////////////////////////////////
// Ctoken Address 1 (QOD)- 0x34F3e6A812DaaB15803Aa9C38A22699d1Dfdc88A
// CToken Address 2 (SHIVA)- 0x144301235b35811C7eb7a838565F842766AE6B49
