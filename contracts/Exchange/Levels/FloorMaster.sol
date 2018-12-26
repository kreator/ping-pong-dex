pragma solidity ^0.5.0; // solhint-disable-line compiler-fixed, compiler-gt-0_5

import "node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "../../Token/IERC20.sol";

/**
 @title Floor level master contract 
 @author Yoni Svechinsky (@svechinsky)
 @notice Stores the logic for FloorLevel proxy contracts. Is used when the rate of eth to token decreases.
 Meaining either when user is selling eth or buying tokens
 */
contract FloorMaster {
  using SafeMath for uint;

  //STATE
  uint public rate; //18 decimal rate from 1 eth to token
  IERC20 public token;
  mapping(address => uint) public withdrawTokens;
  mapping(address => address) public approvedWithdrawers;
  address public approvedTrader; //Special class of traders meant for pingpong exchange

  //CONSTANTS
  uint internal constant RATE_DECIMALS = 10 ** 18;

  //EXTERNAL FUNCTIONS
  /**
  @notice Places a limit order trading tokenAmount for tokenAmount/rate eth
  @param tokenAmount amount of tokens to trade
  @param approvedWithdrawer address of approved withdrawer 
   */
  function placeOrder(uint tokenAmount, address approvedWithdrawer) external {
    withdrawTokens[msg.sender] += tokenAmount.mul(RATE_DECIMALS).div(rate);
    if (approvedWithdrawer != address(0)) {
      approvedWithdrawers[msg.sender] = approvedWithdrawer;
    }
    token.transferFrom(msg.sender, address(this), tokenAmount);
  }

  /**
  @notice Changes the approved withdrawer, pass address(0) to remove
  @param approvedWithdrawer address of new approved withdrawer 
   */
  function changeApporvedWithdrawer(address approvedWithdrawer) external {
    approvedWithdrawers[msg.sender] = approvedWithdrawer;
  }

  /**
  @notice Trade eth for token at rate if not enough tokens send back the remainder of eth
  @param recipient address to send the tokens to
  @return The remainder of the trade i.e. how much was not fulfilled  
   */
  function trade(address recipient) external payable returns(uint remainder) {
    require(msg.value > 0, "No eth sent");
    uint tokenBalance = token.balanceOf(address(this));
    uint tokensToSend = msg.value.mul(rate).div(RATE_DECIMALS);
    if (tokensToSend > tokenBalance) {
      remainder = tokensToSend - tokenBalance;
      token.transfer(recipient, tokenBalance);
      uint ethRemainder = remainder.mul(RATE_DECIMALS).div(rate);
      msg.sender.transfer(ethRemainder);
    } else {
      remainder = 0;
      token.transfer(recipient, tokensToSend);
    }
  }

  /**
  @notice Withdraw assets after a trade has happened
  @param ethToWithdraw Amount of eth to withdraw
   */
  function withdraw(uint ethToWithdraw) external {
    require(
      ethToWithdraw <= withdrawTokens[msg.sender],
      "not enough withdrawl tokens"
    );
    require(
      ethToWithdraw <= address(this).balance,
      "Not enough eth in level to withdraw"
    );
    withdrawTokens[msg.sender] -= ethToWithdraw;
    msg.sender.transfer(ethToWithdraw);
  }

  /**
  @notice Withdraw on behalf of someone that has approved you
  @param ethToWithdraw Amount of eth to withdraw
  @param recipient recipient of the withdrawl
   */
  function approvedWithdraw(
    uint ethToWithdraw,
    address payable recipient
  ) external {
    require(
      ethToWithdraw <= withdrawTokens[recipient],
      "not enough withdrawl tokens"
    );
    require(
      ethToWithdraw <= address(this).balance,
      "Not enough eth in level to withdraw"
    );
    require(
      approvedWithdrawers[recipient] == msg.sender,
      "Withdrawer not approved"
    );
    withdrawTokens[recipient] -= ethToWithdraw;
    recipient.transfer(ethToWithdraw);

  }

}
