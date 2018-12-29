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
    let tokensToSell = web3.utils.toWei("1000");

    await level.placeOrder(tokensToSell, ZERO_ADDRESS, {
      from: accounts[0]
    });

    let withdrawTokens = web3.utils.fromWei(
      await level.withdrawTokens.call(accounts[0])
    );

    assert.equal(
      withdrawTokens,
      10,
      "Withdraw tokens not equal to amount/rate"
    );
  });

  it("Successfully trades eth for tokens", async () => {
    let ethToSell = web3.utils.toWei("2");
    let tokenBalancePre = await token.balanceOf.call(accounts[0]);
    let remainder = await level.trade.call(accounts[0], {
      value: ethToSell,
      from: accounts[0]
    });
    //console.log("Gas used to trade", remainder.receipt.gasUsed);
    await level.trade(accounts[0], { value: ethToSell, from: accounts[0] });

    assert.equal(remainder, 0, "Remainder not 0");
    let tokenBalancePost = await token.balanceOf.call(accounts[0]);
    assert.equal(
      web3.utils.fromWei(tokenBalancePost.sub(tokenBalancePre)),
      "200",
      "Tokens not transfered"
    );
  });

  it("Successfully withdraws eth after trade", async () => {
    let ethToWithdraw = web3.utils.toWei("1");
    let ethBalancePre = await web3.eth.getBalance(accounts[0]);
    let { receipt } = await level.withdraw(ethToWithdraw, {
      from: accounts[0],
      gasPrice: 1
    });
    let ethBalancePost = await web3.eth.getBalance(accounts[0]);

    let balanceDifferenceWithGas = ethBalancePost - ethBalancePre;

    balanceDifferenceWithGas += receipt.gasUsed;
    assert.approximately(
      +web3.utils.fromWei(balanceDifferenceWithGas.toString()),
      1,
      0.0000001,
      "eth not equal"
    );
  });

  it("Fails on trying to withdraw without tokens", async () => {
    let ethToWithdraw = web3.utils.toWei("1");
    assert.isRejected(level.withdraw(ethToWithdraw, { from: accounts[1] }));
  });

  it("Places an order with an approved withdrawer", async () => {
    let tokensToSell = web3.utils.toWei("1000");

    await level.placeOrder(tokensToSell, accounts[1], {
      from: accounts[0]
    });

    let withdrawTokens = web3.utils.fromWei(
      await level.withdrawTokens.call(accounts[0])
    );

    let approvedWithdrawer = await level.approvedWithdrawers(accounts[0]);
    assert.equal(
      withdrawTokens,
      19, // Beacuse of previous order
      "Withdraw tokens not equal to amount/rate"
    );

    assert.equal(approvedWithdrawer, accounts[1], "Withdrawer not as expected");
  });
  it("Allows approved withdrawer to withdraw", async () => {
    let ethToWithdraw = web3.utils.toWei("0.5");
    let preBalance = await web3.eth.getBalance(accounts[0]);
    await level.approvedWithdraw(ethToWithdraw, accounts[0], {
      from: accounts[1]
    });
    let postBalance = await web3.eth.getBalance(accounts[0]);
    assert.equal(
      web3.utils.fromWei((postBalance - preBalance).toString()),
      0.5,
      "Withdrawl failed"
    );
  });
  it("Fails when unapproved withdrawer tires to withdraw", async () => {
    assert.isRejected(
      level.approvedWithdraw(111, accounts[0], { from: accounts[2] })
    );
  });
});
