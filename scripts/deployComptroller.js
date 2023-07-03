
const hre = require("hardhat");

async function main() {
  const comptrollerContract = await ethers.getContractFactory("Comptroller");
  const Comptroller = await comptrollerContract.deploy();
  console.log("Comptroller contract is deploying at..........")
  await Comptroller.deployed();
  console.log(Comptroller.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});



////////////////////////////////////////////
// Comptroller Contract - 0xBa70F1c3Fe2922992843Aa429DdE9d9Bfa163360
