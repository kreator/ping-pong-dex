var PingPongCore = artifacts.require("./Exchange/PingPongCore.sol");
var PingPongExchange = artifacts.require("./Exchange/PingPongExchange.sol");
var MockToken = artifacts.require("./Token/MockToken.sol");
var CielMaster = artifacts.require("./Exchange/Levels/CielMaster.sol");
var FloorMaster = artifacts.require("./Exchange/Levels/FloorMaster.sol");
var LevelFactory = artifacts.require("./Exchange/Levels/LevelFactory.sol");

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

module.exports = function(deployer) {
  deployer.deploy(MockToken);
  deployer.deploy(CielMaster);
  deployer.deploy(FloorMaster)//.then(() => {
    deployer
      .deploy(LevelFactory, FloorMaster.address, CielMaster.address)
   //   .then(() => {
        deployer.deploy(
          PingPongExchange,
          MockToken.address,
          ZERO_ADDRESS,
          LevelFactory.address
        );
//      });
//  });
};
