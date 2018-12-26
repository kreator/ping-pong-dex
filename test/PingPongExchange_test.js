var chai = require("chai");
var chaiAsPromised = require("chai-as-promised");

chai.use(chaiAsPromised);

var assert = chai.assert;

var PingPongExchange = artifacts.require("PingPongExchange");
var MockToken = artifacts.require("MockToken");
var LevelFactory = artifacts.require("LevelFactory");
var FloorLevel = artifacts.require("FloorMaster");
var CielLevel = artifacts.require("CielMaster");

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

contract("Ping Pong Exchange", async accounts => {
  let token;
  let levelFactory;
  let exchange;
  const deadline = Math.floor(Date.now()) + 500;

  before("Load instances", async () => {
    token = await MockToken.deployed();
    levelFactory = await LevelFactory.deployed();
  });

  it("Deployes an exchange and approve token access", async () => {
    let largeAmount = web3.utils.toWei("100000");
    exchange = await PingPongExchange.new(
      token.address,
      ZERO_ADDRESS,
      levelFactory.address
    );

    await token.approve(exchange.address, largeAmount, { from: accounts[0] });
    assert(true);
  });

  it("Initialize exchange and seeds liquidity", async () => {
    let initialTokenAmount = web3.utils.toWei("100");
    let initialEthAmount = web3.utils.toWei("10");

    await exchange.initializeExchange(initialTokenAmount, {
      from: accounts[0],
      value: initialEthAmount
    });
    let totalSupply = await exchange.totalSupply.call();
    assert(web3.utils.fromWei(totalSupply) == 10, "Total supply is not 10");

    let senderBalance = await exchange.balanceOf.call(accounts[0]);
    assert.equal(
      web3.utils.fromWei(senderBalance),
      10,
      "Sender balance is not 10"
    );

    let contractTokenBalance = await token.balanceOf.call(exchange.address);
    assert.equal(
      web3.utils.fromWei(contractTokenBalance),
      100,
      "Tokens not transfered to exchange"
    );
  });

  it("Adds Liquidity", async () => {
    let ethLiquidityToAdd = web3.utils.toWei("10");
    let tokenLiquidityToAdd = web3.utils.toWei("100");

    await exchange.addLiquidity(tokenLiquidityToAdd, deadline, {
      from: accounts[0],
      value: ethLiquidityToAdd
    });

    let totalSupply = await exchange.totalSupply.call();
    assert(web3.utils.fromWei(totalSupply) == 20, "Total supply is not 20");

    let senderBalance = await exchange.balanceOf.call(accounts[0]);
    assert.equal(
      web3.utils.fromWei(senderBalance),
      20,
      "Sender balance is not 20"
    );

    let contractTokenBalance = await token.balanceOf.call(exchange.address);
    assert.equal(
      web3.utils.fromWei(contractTokenBalance),
      200,
      "Tokens not transfered to exchange"
    );
  });

  it("Removes Liquidity", async () => {
    let liquiditySharesToBurn = web3.utils.toWei("10");
    let startTokenBalance = await token.balanceOf.call(accounts[0]);
    let ethLiquidityToRemove = web3.utils.toWei("10");
    let tokenLiquidityToRemove = web3.utils.toWei("100");
    let tooMuchLiquidityToRemove = web3.utils.toWei("10000");

    await exchange.removeLiquidity(
      liquiditySharesToBurn,
      ethLiquidityToRemove,
      tokenLiquidityToRemove,
      deadline
    );

    let endTokenBalance = await token.balanceOf.call(accounts[0]);
    assert.equal(
      endTokenBalance.sub(startTokenBalance),
      tokenLiquidityToRemove,
      "Liquidity not properly removed"
    );

    assert.isRejected(
      exchange.removeLiquidity(
        liquiditySharesToBurn,
        tooMuchLiquidityToRemove,
        tooMuchLiquidityToRemove,
        deadline
      )
    );
  });

  it("Adds eth to ciel", async () => {
    let currentCielPrice = await exchange.currentCielPrice.call();
    let cielAddress = await exchange.ciels.call(currentCielPrice);
    console.log(cielAddress);
    let ciel = await CielLevel.at(cielAddress);

    let ethToSell = web3.utils.toWei("3");

    await ciel.placeOrder(ZERO_ADDRESS, {
      from: accounts[0],
      value: ethToSell
    });

    let withdrawTokens = web3.utils.fromWei(
      await ciel.withdrawTokens.call(accounts[0])
    );
    
 
    assert.approximately(
      // Approximately beacuse big numbers
      +withdrawTokens,
      3 * web3.utils.fromWei(currentCielPrice),
      0.00000001,
      "Withdraw tokens not equal to amount/rate"
    );
  });

  it("Sells 10 tokens for eth", async () => {
    let tokenAmount = web3.utils.toWei("10");

    await exchange.tokenToEthInput(tokenAmount, 1, deadline, accounts[0], {
      from: accounts[0]
    });

  });
});