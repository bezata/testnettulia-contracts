const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { expect } = require("chai");

describe("TuliaPool", function () {
  async function deployTuliaPoolFixture() {
    const [owner, borrower, otherAccount] = await ethers.getSigners();

    const Token = await ethers.getContractFactory("MockTokenCreator");
    const loanToken = await Token.deploy("Loan Token", "LT");
    const repaymentToken = await Token.deploy("Repayment Token", "RT");

    const TuliaPool = await ethers.getContractFactory("TuliaPool");
    const tuliaPool = await TuliaPool.deploy(
      owner.address,
      loanToken.address,
      repaymentToken.address,
      borrower.address,
      1000,
      500,
      60 * 24 * 60 * 60 // 60 days in seconds
    );

    await loanToken.mint(owner.address, 5000);
    await repaymentToken.mint(borrower.address, 5000);

    return {
      tuliaPool,
      owner,
      borrower,
      otherAccount,
      loanToken,
      repaymentToken,
    };
  }

  describe("Deployment", function () {
    it("Should correctly initialize all state variables", async function () {
      const { tuliaPool, owner, loanToken, repaymentToken } = await loadFixture(
        deployTuliaPoolFixture
      );
      console.log("Checking initialized values...");

      expect(await tuliaPool.owner()).to.equal(owner.address);
      expect(await tuliaPool.getLoanToken()).to.equal(loanToken.address);
      expect(await tuliaPool.getRepaymentToken()).to.equal(
        repaymentToken.address
      );

      const loanDetails = await tuliaPool.loanDetails();
      expect(loanDetails.loanAmount).to.equal(1000);
      console.log(`Loan amount is set to ${loanDetails.loanAmount.toString()}`);
    });
  });

  describe("Loan Funding and Activation", function () {
    it("Should allow the owner to fund the loan and move state to PENDING", async function () {
      const { tuliaPool, loanToken, owner } = await loadFixture(
        deployTuliaPoolFixture
      );
      console.log("Funding the loan...");

      await loanToken.connect(owner).approve(tuliaPool.address, 1000);
      await tuliaPool.connect(owner).fundLoan();
      console.log("Loan funded by owner.");

      const state = await tuliaPool.getLoanState();
      expect(state).to.equal(1); // Assuming state 1 is PENDING
      console.log(`Loan state after funding: ${state}`);
    });
    describe("Loan activateion", function () {
      it("Should activate the loan when conditions are met and move state to ACTIVE", async function () {
        const { tuliaPool, loanToken, borrower } = await loadFixture(
          deployTuliaPoolFixture
        );
        console.log("Activating the loan...");

        await loanToken.connect(borrower).approve(tuliaPool.address, 1000);
        await tuliaPool.connect(borrower).activateLoan();
        console.log("Loan activated by borrower.");

        const state = await tuliaPool.getLoanState();
        expect(state).to.equal(2); // Assuming state 2 is ACTIVE
        console.log(`Loan state after activation: ${state}`);
      });
    });
  });

  describe("Default Handling and Collateral Management", function () {
    it("Should handle defaults correctly and move state to DEFAULTED", async function () {
      const { tuliaPool, borrower } = await loadFixture(deployTuliaPoolFixture);
      console.log("Simulating loan default...");

      await time.increase(90 * 24 * 60 * 60); // 90 days
      await tuliaPool.connect(borrower).checkAndHandleDefault();
      console.log("Default handling triggered.");

      const state = await tuliaPool.getLoanState();
      expect(state).to.equal(3); // Assuming state 3 is DEFAULTED
      console.log(`Loan state after handling default: ${state}`);
    });

    it("Should manage collateral on repayment and move state to CLOSED", async function () {
      const { tuliaPool, borrower, repaymentToken } = await loadFixture(
        deployTuliaPoolFixture
      );
      console.log("Processing loan repayment...");

      await repaymentToken.connect(borrower).approve(tuliaPool.address, 1500); // Assuming enough to cover interest
      await tuliaPool.connect(borrower).repay();
      console.log("Loan repaid by borrower.");

      const state = await tuliaPool.getLoanState();
      expect(state).to.equal(4); // Assuming state 4 is CLOSED
      console.log(`Loan state after repayment: ${state}`);
    });
  });
});
