pragma solidity ^0.5.0; // solhint-disable-line compiler-fixed, compiler-gt-0_5

import "node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "../../Token/IERC20.sol";

/**
 @title Floor level master contract 
 @author Yoni Svechinsky (@svechinsky)
 @notice Stores the logic for FloorLeve proxy contracts to use. Is used when the price of token decreases.
 Meaining either when user is buying eth or selling tokens
 */
contract FloorMaster {
  using SafeMath for uint;

  //STATE
  uint public rate; //18 decimal rate from 1 eth to token
  IERC20 public token;
  mapping(address => uint) public withdrawTokens;
  mapping(address => address) public approvedWithdrawers;
  address public approvedTrader; //Special class of trader meant for pingpong exchange

  //CONSTANTS
  uint internal constant RATE_DECIMALS = 10 ** 18;

  //EXTERNAL FUNCTIONS
  /**
  @notice Places a limit order trading msg.value for msg.value*rate tokens
  @param approvedWithdrawer address of approved withdrawer 
   */
  function placeOrder(address approvedWithdrawer) external payable {
    require(msg.value > 0, "No eth sent");
    withdrawTokens[msg.sender] += msg.value.mul(rate).div(RATE_DECIMALS);
    if (approvedWithdrawer != address(0)) {
      approvedWithdrawers[msg.sender] = approvedWithdrawer;
    }
  }

  /**
  @notice Changes the approved withdrawer, pass address(0) to remove
  @param approvedWithdrawer address of new approved withdrawer 
   */
  function changeApporvedWithdrawer(address approvedWithdrawer) external {
    approvedWithdrawers[msg.sender] = approvedWithdrawer;
  }

  /**
  @notice Trade tokens for eth at rate if not enough eth send back remainder of tokens
  @param recipient address to send the eth to
  @param tokenAmount tokens to trade
  @return The remainder of the trade i.e. how much was not fulfilled  
   */
  function trade(address payable recipient, uint tokenAmount) external returns(
    uint remainder
  ) {
    require(tokenAmount > 0, "tokenAmount can't be 0");
    uint ethBalance = address(this).balance;
    uint ethToSend = tokenAmount.mul(RATE_DECIMALS).div(rate);
    if (ethToSend > ethBalance) {
      remainder = ethToSend - ethBalance;
      recipient.transfer(ethBalance);
      uint tokensToPull = tokenAmount - remainder.mul(rate).div(RATE_DECIMALS);
      token.transferFrom(msg.sender, address(this), tokensToPull);

    } else {
      remainder = 0;
      recipient.transfer(ethToSend);
      token.transferFrom(msg.sender, address(this), tokenAmount);
    }

  }

  /**
    @dev This function is used to save gas when interacted with the ping pong dex.
    It assumes that the tokenAmount is sent to the contract prior to calling this function 
    this saves a transfer-approve-transfer sequence.
    Note that unlike the regular trade this function fails when it doesn't have enough eth for the trade
    @param recipient address to send the eth to
    @param tokenAmount tokens sent to the exchange
   */
  function approvedTrade(address payable recipient, uint tokenAmount) external {
    require(approvedTrader == msg.sender, "Sender not an approved trade");
    require(tokenAmount > 0, "tokenAmount can't be 0");
    uint ethBalance = address(this).balance;
    uint ethToSend = tokenAmount.mul(RATE_DECIMALS).div(rate);
    require(ethToSend <= ethBalance, "Not enough eth in level");

    recipient.transfer(ethToSend);

  }

  /**
  @notice Withdraw assets after a trade has happened
  @param tokenToWithdraw Amount of eth to withdraw
   */
  function withdraw(uint tokenToWithdraw) external {
    require(
      tokenToWithdraw <= withdrawTokens[msg.sender],
      "not enough withdrawl tokens"
    );
    require(
      tokenToWithdraw <= token.balanceOf(address(this)),
      "Not enough tokens in level to withdraw"
    );
    withdrawTokens[msg.sender] -= tokenToWithdraw;
    token.transfer(msg.sender, tokenToWithdraw);
  }

  /**
  @notice Withdraw on behalf of someone that has approved you
  @param tokenToWithdraw Amount of eth to withdraw
  @param recipient recipient of the withdrawl
   */
  function approvedWithdraw(
    uint tokenToWithdraw,
    address payable recipient
  ) external {
    require(
      tokenToWithdraw <= withdrawTokens[recipient],
      "not enough withdrawl tokens"
    );
    require(
      tokenToWithdraw <= token.balanceOf(address(this)),
      "Not enough tokens in level to withdraw"
    );
    require(
      approvedWithdrawers[recipient] == msg.sender,
      "Withdrawer not approved"
    );
    withdrawTokens[recipient] -= tokenToWithdraw;
    token.transfer(recipient, tokenToWithdraw);

  }

}
