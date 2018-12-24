pragma solidity ^0.5.0; // solhint-disable-line compiler-fixed, compiler-gt-0_5

/**
 @title Interface for FloorMaster contract behind a level proxy 
 @author Yoni Svechinsky (@svechinsky)
 */
contract IFloorLevel {
   /**
    @dev This function is used to save gas when interacted with the ping pong dex.
    It assumes that the tokenAmount is sent to the contract prior to calling this function 
    this saves a transfer-approve-transfer sequence.
    Note that unlike the regular trade this function fails when it doesn't have enough eth for the trade
    @param recipient address to send the eth to
    @param tokenAmount tokens sent to the exchange
   */
  function approvedTrade(address payable recipient, uint tokenAmount) external;

}
