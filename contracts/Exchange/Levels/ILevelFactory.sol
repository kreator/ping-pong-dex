pragma solidity ^0.5.0; // solhint-disable-line compiler-fixed, compiler-gt-0_5

/**
 @title Interface for level factory  
 @author Yoni Svechinsky (@svechinsky)
 */
contract ILevelFactory {
  function createCielLevel(uint rate, address token) public returns(
    address levelAddress
  );
  function createFloorLevel(uint rate, address token) public returns(
    address levelAddress
  );

}
