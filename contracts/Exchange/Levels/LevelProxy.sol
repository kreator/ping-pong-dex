pragma solidity ^0.5.0; // solhint-disable-line compiler-fixed, compiler-gt-0_5

import "node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "../../Token/IERC20.sol";

/**
 @title Contract storing the data of each level, used to access the logic contract 
 @author Yoni Svechinsky (@svechinsky)
 */
contract LevelProxy {
  using SafeMath for uint;

  //STATE
  uint public rate; //18 decimal rate from 1 eth to token
  IERC20 public token;
  mapping(address => uint) public withdrawTokens;
  mapping(address => address) public approvedWithdrawers;
  address public approvedTrader; //Special class of traders meant for pingpong exchange
  address public logicContract;

  constructor(
    uint _rate,
    address _token,
    address _approvedTrader,
    address _logicContract
  ) public {
    rate = _rate;
    token = IERC20(_token);
    logicContract = _logicContract;
    approvedTrader = _approvedTrader;
  }

  function() external payable {
    address target = logicContract;
    assembly {
      calldatacopy(0x0, 0x0, calldatasize)
      let success := delegatecall(sub(gas, 10000), target, 0x0, calldatasize, 0, 0)
      let retSz := returndatasize
      returndatacopy(0, 0, retSz)
      switch success
      case 0 {
        revert(0, retSz)
      }
      default {
        return(0, retSz)
      }
    }
  }
}
