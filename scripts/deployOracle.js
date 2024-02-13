
const hre = require("hardhat");

async function main() {
  const oracleContract = await ethers.getContractFactory("PriceOracle");
  const oracle = await oracleContract.deploy();
  console.log("oracle contract is deploying at..........")
  await oracle.deployed();
  console.log(oracle.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});


///////////////////////////////////////
// Oracle Address - 0x7e0298880224B8116F3462c50917249E94b3DC53