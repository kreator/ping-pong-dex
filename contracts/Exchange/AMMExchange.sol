pragma solidity ^0.5.0; // solhint-disable-line compiler-fixed, compiler-gt-0_5

import "node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "../Token/IERC20.sol";
import "./IPingPongRegistry.sol";
import "./BasicExchange.sol";

/**
@title AMMExchange - Automated Market Maker Exchange Contract as part of the PingPongDex
@author Yoni Svechinsky (@svechinsky)
@notice Containing AMM liquidity addition functionality and pricing functions  
 */
contract AMMExchange is BasicExchange {
  using SafeMath for uint256;

  //STATE
  uint public previousInvariant;
  uint public totalSupply;
  mapping(address => uint) public liquidityShares;

  //EVENTS
  event LiquidityAdded(
    uint ethAmount,
    uint tokenAmount,
    uint sharesMinted,
    address liquidityProvider
  );

  event LiquidityRemoved(
    uint ethAmount,
    uint tokenAmount,
    uint sharesBurned,
    address liquidityProvider
  );

  event TokenPurchaseInAMM(uint tokensBought, uint ethSold, address buyer);

  event EthPurchaseInAMM(uint ethBough, uint tokensSold, address buyer);

  //MODIFIERS

  // CONSTRUCTOR
  /**
    @notice Initializes an empty Ping Pong Exchange
   */
  constructor() public {
    previousInvariant = 0;
    totalSupply = 0;
  }

  // EXTERNAL FUNCTIONS
  /**
   @notice Adds liquidity to the exchange, the amount of liquidity added is based on the eth sent with the tx
   @dev Must have an adequate amount of tokens approved beforehand
   @param maxTokens Max tokens to pull from the sender, used to protect against rate changes
   @param deadline Latest when the function can be executed 
   */
  function addLiquidity(
    uint maxTokens,
    uint deadline
  ) external payable deadlineGuard(deadline) {
    (uint ethReserve, uint tokenReserve) = getCurrentReserveInfo();

    uint tokensToPull = msg.value.mul(tokenReserve).div(ethReserve);
    require(tokensToPull <= maxTokens, "Trying to pull too many tokens");

    uint liquiditySharesToMint = msg.value.mul(totalSupply).div(ethReserve);

    liquidityShares[msg.sender] += liquiditySharesToMint;
    totalSupply += liquiditySharesToMint;

    require(
      token.transferFrom(msg.sender, address(this), tokensToPull),
      "Failed to transfer tokens"
    );

    emit LiquidityAdded(
      msg.value,
      tokensToPull,
      liquiditySharesToMint,
      msg.sender
    );
  }

  /**
   @notice Removes liquidity from the exchange
   @param sharesBurned Liquidity tokens to burn
   @param minEth Minimal expected amount of eth
   @param minTokens Minimal expected amount of tokens
   @param deadline Latest when the function can be executed 
   */
  function removeLiquidity(
    uint sharesBurned,
    uint minEth,
    uint minTokens,
    uint deadline
  ) external deadlineGuard(deadline) {
    require(sharesBurned > 0);
    liquidityShares[msg.sender] = liquidityShares[msg.sender].sub(sharesBurned);

    (uint ethReserve, uint tokenReserve) = getCurrentReserveInfo();

    uint ethDivested = sharesBurned.mul(ethReserve).div(totalSupply);
    uint tokensDivested = sharesBurned.mul(tokenReserve).div(totalSupply);
    require(
      ethDivested >= minEth && tokensDivested >= minTokens,
      "Not enough liquidity divested"
    );

    totalSupply = totalSupply.sub(sharesBurned);

    require(token.transfer(msg.sender, tokensDivested));
    msg.sender.transfer(ethDivested);
    emit LiquidityRemoved(
      ethDivested,
      tokensDivested,
      sharesBurned,
      msg.sender
    );
  }

  // PUBLIC FUNCTIONS
  function balanceOf(address account) public view returns(uint) {
    return liquidityShares[account];
  }
  /**
    @notice Initializes the AMM exchange by seeding the liquidity and minting intiial liquidit shares
    @param tokenAmount The amount of tokens to match the msg.value and create the initial rate
   */
  function initializeExchange(uint tokenAmount) public payable {
    require(totalSupply == 0, "Exchange initialized already");
    require(msg.value >= 0 && tokenAmount >= 0, "Eth or token amount is 0");

    liquidityShares[msg.sender] = msg.value;
    totalSupply = msg.value;
    token.transferFrom(msg.sender, address(this), tokenAmount);
  }

  // INTERNAL FUNCTIONS

  /**
    @notice Get's the current reserves of the exchange
   */

  function getCurrentReserveInfo() internal view returns(
    uint ethReserve,
    uint tokenBalance
  ) {
    ethReserve = address(this).balance - msg.value;
    tokenBalance = token.balanceOf(address(this));
  }

  /**
    @dev Gets the price of a swap where the input is specified
    @param inputAmount Input amount
    @param inputReserve Amount of input asset
    @param outputReserve Amount of output asset
   */
  function getInputPrice(
    uint inputAmount,
    uint inputReserve,
    uint outputReserve
  ) internal pure returns(uint) {
    require(inputReserve > 0 && outputReserve > 0, "Reserves are 0");
    uint numerator = inputAmount.mul(outputReserve);
    uint denominator = inputReserve.add(inputAmount);
    return numerator.div(denominator);
  }

  /**
    @dev Gets the price of a swap where the output is specified
    @param outputAmount Output amount
    @param inputReserve Amount of input asset
    @param outputReserve Amount of output asset
   */
  function getOutputPrice(
    uint outputAmount,
    uint inputReserve,
    uint outputReserve
  ) internal pure returns(uint) {
    require(inputReserve > 0 && outputReserve > 0, "Reserves are 0");
    uint numerator = outputAmount.mul(inputReserve);
    uint denominator = outputReserve.sub(outputAmount);
    return numerator.div(denominator);
  }

  /**
    @dev Calculates the amount of eth recieved from a selling tokenAmount at the AMM
    @param tokenAmount The amount of tokens used to purchase ETH
   */
  function tokenToEthInput(uint tokenAmount) internal view returns(
    uint ethAmount
  ) {
    (uint ethReserve, uint tokenReserve) = getCurrentReserveInfo();
    ethAmount = getInputPrice(tokenAmount, tokenReserve, ethReserve);
  }
  /**
    @dev Calculates the amount of tokens required to buy ethAmount of eth from the AMM
    @param ethAmount The amount of eth to purchase
   */
  function tokenToEthOutput(uint ethAmount) internal view returns(
    uint tokenAmount
  ) {
    (uint ethReserve, uint tokenReserve) = getCurrentReserveInfo();
    tokenAmount = getOutputPrice(ethAmount, tokenReserve, ethReserve);
  }

  /**
    @dev Calculates the amount of tokens recieved from a selling ethAmount at the AMM
    @param ethAmount The amount of tokens used to purchase ETH
   */
  function ethToTokenInput(uint ethAmount) internal view returns(
    uint tokenAmount
  ) {
    (uint ethReserve, uint tokenReserve) = getCurrentReserveInfo();
    tokenAmount = getInputPrice(ethAmount, ethReserve, tokenReserve);
  }

  /**
    @dev Calculates the amount of eth required to buy tokenAmount of tokens from the AMM
    @param tokenAmount The amount of tokens to purchase
   */
  function ethToTokenOutput(uint tokenAmount) internal view returns(
    uint ethAmount
  ) {
    (uint ethReserve, uint tokenReserve) = getCurrentReserveInfo();
    ethAmount = getOutputPrice(tokenAmount, ethReserve, tokenReserve);
  }

}
