
const hre = require("hardhat");

async function main(name, symbol) {
  const assetContract = await ethers.getContractFactory("Token");
  const asset = await assetContract.deploy(name, symbol);
  console.log( name + " asset contract is deploying at..........")
  await asset.deployed();
  console.log(asset.address);
}

main("qod", "QOD").then(() => {
    main("shiva", "SHIVA").catch((error) => {
        console.error(error);
        process.exitCode = 1;
    });
}).catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
/////////////////////////////////
// QOD Address -0x7Af833184Bc87F525D83276576a7B7ddBEeAaF34


/////////////////////////////////
// SHIVA Address - 0xF1B3d9666986E3b738D6C1Fb83594c497D097160

// Both verified