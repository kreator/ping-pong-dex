pragma solidity ^0.5.0;

import "./ERC20.sol";

/**
 * @title SimpleToken
 * @dev Very simple ERC20 Token example, where all tokens are pre-assigned to the creator.
 * Note they can later distribute these tokens as they wish using `transfer` and other
 * `ERC20` functions.
 */
contract MockToken is ERC20 {
  string public constant name = "MockToken";
  string public constant symbol = "MCK";
  uint8 public constant decimals = 18;

  uint256 public constant INITIAL_SUPPLY = 100000 * (10 ** uint256(decimals));

  /**
   * @dev Constructor that gives msg.sender all of existing tokens.
   */
  constructor() public {
    _mint(msg.sender, INITIAL_SUPPLY);
  }

}
