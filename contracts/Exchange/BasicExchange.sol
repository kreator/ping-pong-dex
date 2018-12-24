pragma solidity ^0.5.0; // solhint-disable-line compiler-fixed, compiler-gt-0_5
import "node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "../Token/IERC20.sol";
import "./IPingPongRegistry.sol";

/**
@title Basic Exchange - Contains shared primitives between various exchange types
@author Yoni Svechinsky (@svechinsky)
 */
contract BasicExchange {
  using SafeMath for uint256;

  //STATE
  uint32 public swapFee; // In PPM
  IERC20 public token;
  IPingPongRegistry public registry;

  //CONSTANTS
  uint32 internal constant PPM_MAX = 1000000;

  //MODIFIERS
  modifier deadlineGuard(uint deadline) {
    require(deadline > block.timestamp, "Deadline expired");
    _;
  }

  modifier ppmGuard(uint32 value) {
    require(value <= PPM_MAX, "Value is bigger than 1M not PPM compliant");
    _;
  }

  constructor(
    address _token,
    address _registry,
    uint32 _swapFee
  ) internal ppmGuard(_swapFee) {
    swapFee = _swapFee;
    token = IERC20(_token);
    registry = IPingPongRegistry(_registry);
  }
}
