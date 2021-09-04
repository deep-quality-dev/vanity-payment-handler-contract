const { expect } = require("chai");

describe("VNYPaymentHandler", function() {
  it("Should return the new greeting once it's changed", async function() {
    const VNYPaymentHandler = await ethers.getContractFactory("VNYPaymentHandler");
    const cts = await VNYPaymentHandler.deploy();

    await cts.deployed();
  });
});
