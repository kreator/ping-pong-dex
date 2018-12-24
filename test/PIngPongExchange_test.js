var chai = require("chai");
var chaiAsPromised = require("chai-as-promised");

chai.use(chaiAsPromised);

var assert = chai.assert;

var PingPongExchange = artifacts.require("PingPongExchange");
var MockToken = artifacts.require("MockToken");

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

contract("Ping Pong Exchange", async accounts => {
  let token;
  let exchange;
  let deadline;

  it("Initialize exchange and seeds liquidity", async () => {
    token = await MockToken.deployed();
    let initialTokenAmount = web3.utils.toWei("100");
    let initialEthAmount = web3.utils.toWei("10");

    exchange = await PingPongExchange.new(token.address, ZERO_ADDRESS);
    await token.approve(exchange.address, initialTokenAmount, {
      from: accounts[0]
    });

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
    deadline = Math.floor(Date.now() / 1000) + 500;
    await token.approve(exchange.address, tokenLiquidityToAdd);
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

    await token.approve(exchange.address, tokenLiquidityToAdd);

    assert.isRejected(
      exchange.addLiquidity(tokenLiquidityToAdd, deadline - 600, {
        from: accounts[0],
        value: ethLiquidityToAdd
      })
    );

    assert.isRejected(
      exchange.addLiquidity(10000, deadline, {
        from: accounts[0],
        value: ethLiquidityToAdd
      })
    );
  });

  it("Removes Liquidity", async () => {
    let liquiditySharesToBurn = web3.utils.toWei("10");
    let startTokenBalance = await token.balanceOf.call(accounts[0]);
    let ethLiquidityToRemove = web3.utils.toWei("10");
    let tokenLiquidityToRemove = web3.utils.toWei("100");

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
        tokenLiquidityToRemove,
        tokenLiquidityToRemove,
        deadline
      )
    );
  });
});
