pragma solidity ^0.5.0; // solhint-disable-line compiler-fixed, compiler-gt-0_5

import "./LevelProxy.sol";
/**
 @title Factory contract the deployes proxies pointing either at the floor master or the ciel master contracts  
 @author Yoni Svechinsky (@svechinsky)
 */
contract LevelFactory {
  address public floorMaster;
  address public cielMaster;

  constructor(address _floorMaster, address _cielMaster) public {
    floorMaster = _floorMaster;
    cielMaster = _cielMaster;
  }

  function createCielLevel(uint rate, address token) public returns(
    address levelAddress
  ) {
    levelAddress = address(new LevelProxy(rate, token, msg.sender, cielMaster));
  }

  function createFloorLevel(uint rate, address token) public returns(
    address levelAddress
  ) {
    levelAddress = address(new LevelProxy(rate, token, msg.sender, floorMaster));
  }

}
