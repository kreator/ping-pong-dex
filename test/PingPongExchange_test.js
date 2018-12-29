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

  it("Adds eth to 2 ciels", async () => {
    let currentCielPrice = await exchange.currentCielPrice.call();
    let priceSpread = await exchange.priceSpread.call();
    let nextCielPrice = await exchange.calculateStepUp(
      currentCielPrice,
      priceSpread
    );
    let cielAddress = await exchange.ciels.call(currentCielPrice);
    let ciel = await CielLevel.at(cielAddress);

    //create next ciel
    await exchange.addCielLevel(nextCielPrice);
    let nextCielAddress = await exchange.ciels.call(nextCielPrice);
    let nextCiel = await CielLevel.at(nextCielAddress);

    let ethToSell = web3.utils.toWei("2");

    await ciel.placeOrder(ZERO_ADDRESS, {
      from: accounts[0],
      value: ethToSell
    });

    await nextCiel.placeOrder(ZERO_ADDRESS, {
      from: accounts[0],
      value: ethToSell
    });

    let withdrawTokens = web3.utils.fromWei(
      await ciel.withdrawTokens.call(accounts[0])
    );

    assert.approximately(
      // Approximately beacuse big numbers
      +withdrawTokens,
      2 * web3.utils.fromWei(currentCielPrice),
      0.00000001,
      "Withdraw tokens not equal to amount/rate"
    );
  });

  it("Sells 10 tokens for eth", async () => {
    let tokenAmount = web3.utils.toWei("10");

    output = await exchange.tokenToEthInput.call(
      tokenAmount,
      1,
      deadline,
      accounts[0],
      {
        from: accounts[0]
      }
    );

    await exchange.tokenToEthInput(tokenAmount, 1, deadline, accounts[0], {
      from: accounts[0]
    });

    let FPOOnly = web3.utils.fromWei(web3.utils.toBN("976190476190476190"));
    let ammOnlyAmount = web3.utils.fromWei(
      web3.utils.toBN("909090909090909090")
    );
    let ethReturned = web3.utils.fromWei(output);
    assert(ethReturned > ammOnlyAmount, "Not better than AMM only");
    assert(ethReturned > FPOOnly, "Not better than FPO only");
  });
  it("buyes 1.5 eth for tokens and goes through a ciel level", async () => {
    //Should go through the level
    let ethAmount = web3.utils.toWei("1.5");

    output = await exchange.tokenToEthOutput.call(
      ethAmount,
      web3.utils.toWei("100"),
      deadline,
      accounts[0],
      {
        from: accounts[0]
      }
    );

    let startingCielPrice = await exchange.currentCielPrice.call();

    await exchange.tokenToEthOutput(
      ethAmount,
      web3.utils.toWei("100"),
      deadline,
      accounts[0],
      {
        from: accounts[0]
      }
    );
    let FPOOnly = web3.utils.fromWei(web3.utils.toBN("5121951219512195121"));
    let ammOnlyAmount = web3.utils.fromWei(
      web3.utils.toBN("5394969491974494466")
    );
    let tokensPulled = web3.utils.fromWei(output);
    assert(tokensPulled <= ammOnlyAmount, "Not better than AMM only");
    assert(tokensPulled <= FPOOnly, "Not better than FPO only");

    let finishingCielPrice = await exchange.currentCielPrice.call();

    assert(finishingCielPrice > startingCielPrice, "Ciel price didn't change");
  });
  it("Adds tokens to the next two floors", async () => {
    let currentFloorPrice = await exchange.currentFloorPrice.call();
    let priceSpread = await exchange.priceSpread.call();
    let nextFloorPrice = await exchange.calculateStepDown.call(
      currentFloorPrice,
      priceSpread
    );
    let nextFloorAddress = await exchange.floors.call(nextFloorPrice);
    let nextFloor = await FloorLevel.at(nextFloorAddress);

    //create next ciel
    await exchange.addFloorLevel(currentFloorPrice);
    let floorAddress = await exchange.floors.call(currentFloorPrice);
    let floor = await FloorLevel.at(floorAddress);

    let tokensToFloors = web3.utils.toWei("20");

    await token.approve(floor.address, tokensToFloors);
    await token.approve(nextFloor.address, tokensToFloors);

    await floor.placeOrder(tokensToFloors, ZERO_ADDRESS, {
      from: accounts[0]
    });

    await nextFloor.placeOrder(tokensToFloors, ZERO_ADDRESS, {
      from: accounts[0]
    });

    let withdrawTokens = web3.utils.fromWei(
      await floor.withdrawTokens.call(accounts[0])
    );

    assert.approximately(
      // Approximately beacuse big numbers
      +withdrawTokens,
      20 / web3.utils.fromWei(currentFloorPrice),
      0.00000001,
      "Withdraw tokens not equal to amount/rate"
    );
  });

  it("Sells 0.001 eth for tokens", async () => {
    let ethAmount = web3.utils.toWei("0.001");

    output = await exchange.ethToTokenInput.call(1, deadline, accounts[0], {
      from: accounts[0],
      value: ethAmount
    });

    await exchange.ethToTokenInput(1, deadline, accounts[0], {
      from: accounts[0],
      value: ethAmount
    });

    let FPOOnly = web3.utils.fromWei(web3.utils.toBN("10243902439024390"));
    let ammOnlyAmount = web3.utils.fromWei(
      web3.utils.toBN("10754982144487177")
    );
    let tokensReturned = web3.utils.fromWei(output);
    assert(tokensReturned >= ammOnlyAmount, "Not better than AMM only");
    assert(tokensReturned >= FPOOnly, "Not better than FPO only");
  });

  it("Buyes 40 tokens for for tokens and goes through a floor level", async () => {
    //Should go through the level
    let tokenAmount = web3.utils.toWei("50");

    output = await exchange.ethToTokenOutput.call(
      tokenAmount,
      deadline,
      accounts[0],
      {
        from: accounts[0],
        value: web3.utils.toWei("45")
      }
    );

    let startingFloorPrice = await exchange.currentFloorPrice.call();

    await exchange.ethToTokenOutput(tokenAmount, deadline, accounts[0], {
      from: accounts[0],
      value: web3.utils.toWei("45")
    });
    // let FPOOnly = web3.utils.fromWei(web3.utils.toBN("5121951219512195121"));
    // let ammOnlyAmount = web3.utils.fromWei(
    //   web3.utils.toBN("5394969491974494466")
    // );
    // let tokensPulled = web3.utils.fromWei(output);
    // assert(tokensPulled <= ammOnlyAmount, "Not better than AMM only");
    // assert(tokensPulled <= FPOOnly, "Not better than FPO only");

    let finishingFloorPrice = await exchange.currentFloorPrice.call();

    assert(startingFloorPrice != finishingFloorPrice, "Floor price didn't change");
  });
});
