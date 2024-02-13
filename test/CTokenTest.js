const { expect } = require("chai");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { ethers } = require("hardhat");
const { BIGINT } = require("sequelize");

describe("Token contract", function () {
    const collateralFactor = BigInt(0.8e18);
    const underlyingPrice = BigInt(2608688983127312);
    const reserveFactor = BigInt(1e17);

    async function deployTokenFixture() {
        const [deployer, user1, user2] = await ethers.getSigners();

        const qodToken = await ethers.getContractFactory("Qod");
        const QOD = await qodToken.deploy("qodleaf", "QOD");
        await QOD.deployed();

        const shivaToken = await ethers.getContractFactory("Shiva");
        const SHIVA = await shivaToken.deploy("shiva", "SHIVA");
        await SHIVA.deployed();

        const oracleContract = await ethers.getContractFactory("PriceOracle");
        const PriceOracle = await oracleContract.deploy();
        await PriceOracle.deployed();

        const comptrollerContract = await ethers.getContractFactory("Comptroller");
        const Comptroller = await comptrollerContract.deploy();
        await Comptroller.deployed();

        const cQodToken = await ethers.getContractFactory("CQod");
        const CQOD = await cQodToken.deploy();
        await CQOD.deployed();

        const cShivaToken = await ethers.getContractFactory("CShiva");
        const CSHIVA = await cShivaToken.deploy();
        await CSHIVA.deployed();

        const interestRateModelContract = await ethers.getContractFactory("InterestRateModel");
        const interestRateModel = await interestRateModelContract.deploy(0, 23782343987, 518455098934, BigInt(800000000000000000), deployer.address);
        await interestRateModel.deployed();

        return { QOD, SHIVA, CQOD, CSHIVA, PriceOracle, Comptroller, interestRateModel, deployer, user1, user2 };
    }

    it("To set values in price oracle", async function () {
        const { deployer, user1, CQOD, QOD, PriceOracle } = await loadFixture(deployTokenFixture);

        await expect(PriceOracle.getUnderlyingPrice(CQOD.address)).to.be.revertedWith("PRICE_NOT_SET");
        await expect(PriceOracle.connect(user1).setUnderlyingPrice(CQOD.address, BigInt(1000000000000))).to.be.revertedWith("NOT_AUTHORIZED");
        await expect(PriceOracle.connect(deployer).setUnderlyingPrice(QOD.address, BigInt(2608688983127312))).to.be.reverted;
        expect(await PriceOracle.setUnderlyingPrice(CQOD.address, BigInt(2608688983127312))).to.emit(PriceOracle, "PriceUpdated").withArgs(CQOD.address,);
        expect(await PriceOracle.getUnderlyingPrice(CQOD.address)).to.equal(BigInt(2608688983127312));
    });

    it("listing of markets through comptrollet should work properly", async function () {
        const { deployer, user1, CQOD, QOD, Comptroller, PriceOracle } = await loadFixture(deployTokenFixture);
        expect(await Comptroller.initialize(deployer.address, PriceOracle.address));
        await expect(Comptroller.connect(deployer).listMarket(QOD.address, BigInt(1000000000000000000))).to.be.reverted;
        await expect(Comptroller.connect(user1).listMarket(CQOD.address, BigInt(1000000000000000000))).to.be.revertedWith("NOT_AUTHORIZED");
        await expect(Comptroller.listMarket(CQOD.address, BigInt(1000000000000000000000000000000))).to.be.revertedWith("VERY_HIGH_COLLATERAL_FACTOR");
        await expect(Comptroller.listMarket(CQOD.address, BigInt(800000000000000000))).to.emit(Comptroller, "MarketListed").withArgs(CQOD.address, 800000000000000000n);
    });

    it("mint functions of CToken should work properly", async function () {
        const { deployer, user1, CQOD, QOD, Comptroller, PriceOracle, interestRateModel } = await loadFixture(deployTokenFixture);
        await Comptroller.initialize(deployer.address, PriceOracle.address);
        await PriceOracle.setUnderlyingPrice(CQOD.address, underlyingPrice);
        await CQOD.initialize("cQOD", "CQOD", reserveFactor, 2000000000000000000000000000n, QOD.address, Comptroller.address, interestRateModel.address);
        await QOD.connect(user1).mint(BigInt(10e18));
        await QOD.connect(user1).approve(CQOD.address, BigInt(10e18));

        const mintAmount = BigInt(10e18);
        expect(await CQOD.exchangeRate()).to.equal(2000000000000000000000000000n);
        await expect(CQOD.connect(user1).mintToken(mintAmount)).to.be.revertedWith("CAN_NOT_MINT_TOKENS");

        await Comptroller.listMarket(CQOD.address, collateralFactor);
        await expect(CQOD.connect(user1).mintToken(mintAmount)).to.emit(CQOD, "Mint").withArgs(user1.address, BigInt(5000000000));
        expect(await CQOD.balanceOf(user1.address)).to.equal(BigInt(5000000000));
    });

    it("redeem should work properly", async function () {
        const { deployer, user1, CQOD, QOD, Comptroller, PriceOracle, interestRateModel } = await loadFixture(deployTokenFixture);
        await Comptroller.initialize(deployer.address, PriceOracle.address);
        await PriceOracle.setUnderlyingPrice(CQOD.address, underlyingPrice);
        await CQOD.initialize("cQOD", "CQOD", reserveFactor, 2000000000000000000000000000n, QOD.address, Comptroller.address, interestRateModel.address);
        await QOD.connect(user1).mint(BigInt(10e18));
        await QOD.connect(user1).approve(CQOD.address, BigInt(10e18));

        const mintAmount = BigInt(10e18);
        expect(await CQOD.exchangeRate()).to.equal(2000000000000000000000000000n);
        await expect(CQOD.connect(user1).mintToken(mintAmount)).to.be.revertedWith("CAN_NOT_MINT_TOKENS");

        await Comptroller.listMarket(CQOD.address, collateralFactor);
        await CQOD.connect(user1).mintToken(mintAmount);

        await expect(CQOD.connect(user1).redeemToken(5000000000)).to.emit(CQOD, "Redeem").withArgs(user1.address, 5000000000);
        expect(await QOD.balanceOf(user1.address)).to.equal(BigInt(10e18));
    });

    it("exchange rate should work properly", async function () {
        const { deployer, user1, CQOD, QOD, Comptroller, PriceOracle, interestRateModel } = await loadFixture(deployTokenFixture);
        await Comptroller.initialize(deployer.address, PriceOracle.address);
        await Comptroller.listMarket(CQOD.address, collateralFactor);
        await PriceOracle.setUnderlyingPrice(CQOD.address, underlyingPrice);
        await CQOD.initialize("cQOD", "CQOD", reserveFactor, 2000000000000000000000000000n, QOD.address, Comptroller.address, interestRateModel.address);
        await QOD.connect(user1).mint(BigInt(10e18));
        await QOD.connect(user1).approve(CQOD.address, BigInt(10e18));

        const mintAmount = BigInt(10e18);
        expect(await CQOD.exchangeRate()).to.equal(2000000000000000000000000000n);
        await CQOD.connect(user1).mintToken(mintAmount);
        expect(await CQOD.exchangeRate()).to.equal(2000000000000000000000000000n);
    });

    it("borrowing should work properly", async function () {
        const { deployer, user1, user2, CQOD, QOD, CSHIVA, SHIVA, Comptroller, PriceOracle, interestRateModel } = await loadFixture(deployTokenFixture);
        await Comptroller.initialize(deployer.address, PriceOracle.address);
        await Comptroller.listMarket(CQOD.address, collateralFactor);
        await PriceOracle.setUnderlyingPrice(CQOD.address, underlyingPrice);

        await CQOD.initialize("cQOD", "CQOD", reserveFactor, 2000000000000000000000000000n, QOD.address, Comptroller.address, interestRateModel.address);
        await CSHIVA.initialize("cSHIVA", "CSHIVA", reserveFactor, 2000000000000000000000000000n, SHIVA.address, Comptroller.address, interestRateModel.address);

        await QOD.connect(user1).mint(BigInt(10e18));
        await QOD.connect(user1).approve(CQOD.address, BigInt(10e18));

        const mintAmount = BigInt(10e18);
        await CQOD.connect(user1).mintToken(mintAmount);
        
        await QOD.connect(user2).mint(BigInt(10e18));
        await QOD.connect(user2).approve(CQOD.address, BigInt(10e18));
        await CQOD.connect(user2).mintToken(mintAmount);

        await Comptroller.joinMarket(CQOD.address, user2.address);
        await expect( CSHIVA.borrow(BigInt(10e18))).to.be.revertedWith("MARKET_NOT_LISTED");

        await Comptroller.listMarket(CSHIVA.address, collateralFactor);
        await expect( CSHIVA.connect(user2).borrow(BigInt(10e18))).to.be.revertedWith("PRICE_NOT_SET");

        await PriceOracle.setUnderlyingPrice(CSHIVA.address, underlyingPrice);

        await expect(CSHIVA.connect(user2).borrow(BigInt(10e18))).to.be.revertedWith("BORROW_NOT_POSSIBLE");
        await expect(CSHIVA.connect(user2).borrow(BigInt(5e18))).to.be.revertedWith("INSUFFICIENT_UNDERLYING_CASH");

        await SHIVA.connect(user1).mint(BigInt(10e18));
        await SHIVA.connect(user1).approve(CSHIVA.address, BigInt(10e18));
        await CSHIVA.connect(user1).mintToken(mintAmount);

        await expect(CSHIVA.connect(user2).borrow(BigInt(5e18))).to.emit(CSHIVA, "Borrow").withArgs(user2.address, BigInt(5e18), BigInt(5e18), BigInt(5e18));
    });

    it.only("repay should work properly", async function () {
        const { deployer, user1, user2, CQOD, QOD, CSHIVA, SHIVA, Comptroller, PriceOracle, interestRateModel } = await loadFixture(deployTokenFixture);

        await Comptroller.initialize(deployer.address, PriceOracle.address);
        await Comptroller.listMarket(CQOD.address, collateralFactor);
        await PriceOracle.setUnderlyingPrice(CQOD.address, underlyingPrice);

        await CQOD.initialize("cQOD", "CQOD", reserveFactor, 2000000000000000000000000000n, QOD.address, Comptroller.address, interestRateModel.address);
        await CSHIVA.initialize("cSHIVA", "CSHIVA", reserveFactor, 2000000000000000000000000000n, SHIVA.address, Comptroller.address, interestRateModel.address);

        await QOD.connect(user1).mint(BigInt(10e18));
        await QOD.connect(user1).approve(CQOD.address, BigInt(10e18));

        const mintAmount = BigInt(10e18);
        await CQOD.connect(user1).mintToken(mintAmount);
        
        await QOD.connect(user2).mint(BigInt(10e18));
        await QOD.connect(user2).approve(CQOD.address, BigInt(10e18));
        await CQOD.connect(user2).mintToken(mintAmount);

        await Comptroller.joinMarket(CQOD.address, user2.address);

        await Comptroller.listMarket(CSHIVA.address, collateralFactor);

        await PriceOracle.setUnderlyingPrice(CSHIVA.address, underlyingPrice);

        await SHIVA.connect(user1).mint(BigInt(10e18));
        await SHIVA.connect(user1).approve(CSHIVA.address, BigInt(10e18));
        await CSHIVA.connect(user1).mintToken(mintAmount);

        await expect(CSHIVA.connect(user2).borrow(BigInt(5e18))).to.emit(CSHIVA, "Borrow").withArgs(user2.address, BigInt(5e18), BigInt(5e18), BigInt(5e18));

        await expect(CQOD.connect(user2).redeemToken(BigInt(5e18))).to.be.revertedWith("CAN_NOT_REDEEM_TOKENS");

        await SHIVA.connect(user2).approve(CSHIVA.address, BigInt(6e18));
        await SHIVA.connect(user2).mint(BigInt(1e18));
        expect(await CSHIVA.connect(user2).repayBorrow(BigInt(6e18)));
        console.log(await CSHIVA.getAccountSnapshot(user2.address));
    });

});
