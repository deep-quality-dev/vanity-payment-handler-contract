const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log(
    "Deploying contracts with the account:",
    deployer.address
  );

  const VNYPaymentHandler = await ethers.getContractFactory("VNYPaymentHandler");
  const VAN = await VNYPaymentHandler.deploy();
  VAN.deployed();
  console.log("Contract Address:", VAN.address);
}

main()
  .then(() =>  process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
  