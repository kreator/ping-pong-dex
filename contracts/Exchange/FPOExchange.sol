pragma solidity ^0.5.0; // solhint-disable-line compiler-fixed, compiler-gt-0_5

import "node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "../Token/IERC20.sol";
import "./IPingPongRegistry.sol";
import "./BasicExchange.sol";
import "./Levels/ILevelFactory.sol";
import "./Levels/ICielLevel.sol";
import "./Levels/IFloorLevel.sol";

/**
@title FPOExchange - Fixed Price Orderbook Exchange Contract as part of the PingPongDex
@author Yoni Svechinsky (@svechinsky)
@notice Containing FPO level managment and limit order placing   
 */
contract FPOExchange is BasicExchange {
  using SafeMath for uint256;

  //STATE
  mapping(uint => ICielLevel) public ciels; // A rate to ciel addresses mapping
  mapping(uint => IFloorLevel) public floors; // A rate to floor addresses mapping
  ILevelFactory public levelFactory;
  uint public currentCielPrice; // In 18 decimal notation
  uint public currentFloorPrice; // In 18 decimal notation
  uint32 public priceSpread; // Price spread in ppm between the floor and the ciel

  //CONSTANTS
  uint internal constant RATE_DECIMALS = 10 ** 18;
  //EVENTS

  // CONSTRUCTOR
  /**
    @notice Initializes an empty Ping Pong Exchange
    @param _priceSpread Spread from floor to ciel i.e. ciel = floor*(1+spread) 
    @param _levelFactory factory to create new levels
   */
  constructor(
    uint32 _priceSpread,
    address _levelFactory
  ) public ppmGuard(_priceSpread) {
    priceSpread = _priceSpread;
    levelFactory = ILevelFactory(_levelFactory);
  }

  // EXTERNAL FUNCTIONS

  // PUBLIC FUNCTIONS

  /**
    @notice Initializes the FPO exchange by creating initial ciel and floor levels.
    @param tokenAmount The amount of tokens to match the msg.value and create the initial rate
   */
  function initializeExchange(uint tokenAmount) public payable {
    currentFloorPrice = tokenAmount.mul(PPM_MAX).mul(RATE_DECIMALS).div(
      msg.value
    ).div(PPM_MAX + priceSpread / 2);
    currentCielPrice = calculateStepUp(currentFloorPrice, priceSpread);

    addCielLevel(currentCielPrice);
    addFloorLevel(currentFloorPrice);
  }

  // INTERNAL FUNCTIONS

  function calculateStepUp(uint amount, uint32 step) internal pure returns(
    uint
  ) {
    return amount.mul(PPM_MAX + step).div(PPM_MAX);
  }

  function calculateStepDown(uint amount, uint32 step) internal pure returns(
    uint
  ) {
    return amount.mul(PPM_MAX).div(PPM_MAX + step);
  }

  function addCielLevel(uint rate) internal {
    ciels[rate] = ICielLevel(
      levelFactory.createCielLevel(rate, address(token))
    );
  }
  function addFloorLevel(uint rate) internal {
    floors[rate] = IFloorLevel(
      levelFactory.createFloorLevel(rate, address(token))
    );

  }

  /**
    @dev Calculates the amount of eth recieved from a selling tokenAmount at the FPO
    At the current floor level
    @param tokenAmount The amount of tokens used to purchase ETH
    @return A tuple of the eth recieved and the reaminder of tokens
   */
  function tokenToEthInput(uint tokenAmount, uint rate) internal view returns(
    uint ethAmount,
    uint remainder
  ) {
    address floorAddress = address(floors[rate]);
    if (floorAddress == address(0)) {
      return (0, tokenAmount);
    }
    uint ethAtFloor = floorAddress.balance;
    uint ethFromTokens = tokenAmount.mul(RATE_DECIMALS).div(rate);
    if (ethFromTokens > ethAtFloor) {
      ethAmount = ethAtFloor;
      remainder = (ethFromTokens - ethAtFloor).mul(rate).div(RATE_DECIMALS);
    } else {
      ethAmount = ethFromTokens;
      remainder = 0;
    }
  }

  /**
    @dev Calculates the amount of tokens needed to recieve ethAmount eth at the FPO
    At the current floor level
    @param ethAmount The amount of eth desired from the purchase
    @return A tuple of the tokens nessecary and the eth unfulfilled
   */
  function tokenToEthOutput(uint ethAmount, uint rate) internal view returns(
    uint tokenAmount,
    uint unfulfilled
  ) {
    address floorAddress = address(floors[rate]);
    if (floorAddress == address(0)) {
      return (0, ethAmount);
    }
    uint ethAtFloor = floorAddress.balance;
    if (ethAmount > ethAtFloor) {
      tokenAmount = ethAtFloor.mul(rate).div(RATE_DECIMALS);
      unfulfilled = ethAmount - ethAtFloor;
    } else {
      unfulfilled = 0;
      tokenAmount = ethAmount.mul(rate).div(RATE_DECIMALS);
    }
  }

  /**
    @dev Calculates the amount of tokens recieved from a selling ethAmount at the FPO
    At the current ciel level
    @param ethAmount The amount of etb used to purchase tokens
    @return A tuple of the tokens recieved and the reaminder of eth
   */
  function ethToTokenInput(uint ethAmount, uint rate) internal view returns(
    uint tokenAmount,
    uint remainder
  ) {
    address cielAddress = address(ciels[rate]);
    if (cielAddress == address(0)) {
      return (0, ethAmount);
    }
    uint tokensAtCiel = token.balanceOf(cielAddress);
    uint tokensFromEth = ethAmount.mul(rate).div(RATE_DECIMALS);
    if (tokensFromEth > tokensAtCiel) {
      tokenAmount = tokensAtCiel;
      remainder = (tokensFromEth - tokensAtCiel).mul(RATE_DECIMALS).div(rate);
    } else {
      tokenAmount = tokensFromEth;
      remainder = 0;
    }
  }

  /**
    @dev Calculates the amount of eth needed to recieve tokens eth at the FPO
    At the current ciel level
    @param tokenAmount The amount of tokens desired from the purchase
    @return A tuple of the eth nessecary and the tokens unfulfilled
   */
  function ethToTokenOutput(uint tokenAmount, uint rate) internal view returns(
    uint ethAmount,
    uint unfulfilled
  ) {
    address cielAddress = address(ciels[rate]);
    if (cielAddress == address(0)) {
      return (0, tokenAmount);
    }
    uint tokensAtCiel = token.balanceOf(address(ciels[rate]));
    if (tokenAmount > tokensAtCiel) {
      ethAmount = tokensAtCiel.mul(RATE_DECIMALS).div(rate);
      unfulfilled = tokenAmount - tokensAtCiel;
    } else {
      unfulfilled = 0;
      ethAmount = tokenAmount.mul(RATE_DECIMALS).div(rate);
    }
  }
 
}