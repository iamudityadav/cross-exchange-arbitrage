const {assert, expect} = require("chai");
const {ethers} = require("hardhat");

describe("FlashLoan Contract", () => {
    const USDC = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
    const USDC_DECIMALS = 6;

    let FLASH_LOAN, BORROW_AMOUNT;

    before(async () => {
        const flashLoan = await ethers.getContractFactory("FlashLoan");
        FLASH_LOAN = await flashLoan.deploy();
        await FLASH_LOAN.deployed();

        const borrowAmount = "1";
        BORROW_AMOUNT = ethers.utils.parseUnits(borrowAmount, USDC_DECIMALS);
    });

    it("should deploy FlashLoan contract", async () => {
        expect(FLASH_LOAN.address).to.exist;
    });

    it("should execute the cross exchange arbitrage", async () => {
        const tx_arbitrage = await FLASH_LOAN.initiateArbitrage(USDC, BORROW_AMOUNT);
        assert(tx_arbitrage);

        const flashLoan_USDC_balance = await FLASH_LOAN.getBalanceOfToken(USDC);
        expect(flashLoan_USDC_balance).equal("0");
    });
})