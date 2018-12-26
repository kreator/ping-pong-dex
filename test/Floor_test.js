var chai = require("chai");
var chaiAsPromised = require("chai-as-promised");

chai.use(chaiAsPromised);

var assert = chai.assert;

var FloorMaster = artifacts.require("FloorMaster");
var LevelProxy = artifacts.require("LevelProxy");
var MockToken = artifacts.require("MockToken");

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

contract("Floor Level", async accounts => {
  const rate = web3.utils.toWei("100");

  let token;
  let master;
  let proxy;
  let level;

  before("Initialize level proxy", async () => {
    token = await MockToken.deployed();
    master = await FloorMaster.deployed();
    proxy = await LevelProxy.new(
      rate,
      token.address,
      ZERO_ADDRESS,
      master.address
      
    );
    level = await FloorMaster.at(proxy.address);
    await token.approve(level.address, web3.utils.toWei("100000"));
  });

  it("Places an order without a withdrawer", async () => {
    let ethToSell = web3.utils.toWei("10");

    await level.placeOrder(ZERO_ADDRESS, {
      from: accounts[0],
      value: ethToSell
    });

    let withdrawTokens = web3.utils.fromWei(
      await level.withdrawTokens.call(accounts[0])
    );

    assert.equal(
      withdrawTokens,
      1000,
      "Withdraw tokens not equal to amount/rate"
    );
  });

  it("Successfully trades tokens for eth", async () => {
    let tokensToSell = web3.utils.toWei("200");
    let ethBalancePre = await web3.eth.getBalance(accounts[0]);
    let remainder = await level.trade.call(accounts[0], tokensToSell, {
      from: accounts[0]
    });

    let { receipt } = await level.trade(accounts[0], tokensToSell, {
      from: accounts[0],
      gasPrice: 1
    });

    assert.equal(remainder, 0, "Remainder not 0");
    let ethBalancePost = await web3.eth.getBalance(accounts[0]);
    let ethDiff = ethBalancePost - ethBalancePre + receipt.gasUsed;
    assert.approximately(
      +web3.utils.fromWei(ethDiff.toString()),
      2,
      0.00000001,
      "Eth not traded"
    );
  });

  it("Successfully withdraws tokens after trade", async () => {
    let tokensToWithdraw = web3.utils.toWei("100");
    let tokenBalancePre = await token.balanceOf(accounts[0]);
    await level.withdraw(tokensToWithdraw, { from: accounts[0] });
    let tokenBalancePost = await token.balanceOf(accounts[0]);

    let balanceDifference = tokenBalancePost.sub(tokenBalancePre);

    assert.equal(
      +web3.utils.fromWei(balanceDifference),
      100,
      "tokens not withdrawn"
    );
  });

  it("Fails on trying to withdraw without withdrawl tokens", async () => {
    let tokensToWithdraw = web3.utils.toWei("1");
    assert.isRejected(level.withdraw(tokensToWithdraw, { from: accounts[2] }));
  });

  it("Places an order with an approved withdrawer", async () => {
    let ethToSell = web3.utils.toWei("1");

    await level.placeOrder(accounts[1], {
      from: accounts[0],
      value: ethToSell
    });

    let withdrawTokens = web3.utils.fromWei(
      await level.withdrawTokens.call(accounts[0])
    );

    let approvedWithdrawer = await level.approvedWithdrawers(accounts[0]);
    assert.equal(
      withdrawTokens,
      1000,
      "Withdraw tokens not equal to amount/rate"
    );

    assert.equal(approvedWithdrawer, accounts[1], "Withdrawer not as expected");
  });
  it("Allows approved withdrawer to withdraw", async () => {
    let tokensToWithdraw = web3.utils.toWei("100");
    let preBalance = await token.balanceOf(accounts[0]);
    await level.approvedWithdraw(tokensToWithdraw, accounts[0], {
      from: accounts[1]
    });
    let postBalance = await token.balanceOf(accounts[0]);
    assert.equal(
      web3.utils.fromWei(postBalance.sub(preBalance).toString()),
      100,
      "Withdrawl failed"
    );
  });
  it("Fails when unapproved withdrawer tires to withdraw", async () => {
    assert.isRejected(
      level.approvedWithdraw(111, accounts[0], { from: accounts[2] })
    );
  });
});
