pragma solidity ^0.5.0; // solhint-disable-line compiler-fixed, compiler-gt-0_5

import "node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./IPingPongRegistry.sol";
import "./AMMExchange.sol";
import "./FPOExchange.sol";
import "./BasicExchange.sol";

contract PingPongExchange is BasicExchange, AMMExchange, FPOExchange {
  using SafeMath for uint256;
  //STATE

  //CONSTANTS

  //EVENTS
  event Logger(uint num);
  event AddressLogger(address ad);
  //MODIFIERS

  // CONSTRUCTOR
  /**
    @notice Initializes an empty Ping Pong Exchange
    @param _token Token of the exchange 
    @param _registry The exchange registry
   */
  constructor(
    address _token,
    address _registry,
    address _levelFactory
  ) public BasicExchange(_token, _registry, 20000) FPOExchange(50000, _levelFactory) {

  }
  // EXTERNAL FUNCTIONS

  /**
    @notice This function converts tokens to eth by taking an amount of tokens the sender wishes to sell
    It goes through a recursive function so gas price goes up with very large orders.
    @param tokenAmount Amount of tokens to sell
    @param minReturn minimum amount of eth that has to be returned from the swap
    @param deadline time limit on the transaction
    @param recipient address to recive the eth
    @return Eth purchased
   */
  function tokenToEthInput(
    uint tokenAmount,
    uint minReturn,
    uint deadline,
    address payable recipient
  ) external deadlineGuard(deadline) returns(uint) {
    // Start running the recursive handling function
    uint tokenReserve = token.balanceOf(address(this));
    (uint ammAmount, uint totalETH) = handleTokensToEth(
      tokenAmount,
      recipient,
      tokenReserve,
      false,
      currentCielPrice
    );

    // Now that we finished this nasty recursion we only have AMM tokens to take care of
    // If we don't have AMM tokens, i.e. the whole order was fulfilled through the FPO then hooray
    if (ammAmount == 0) {
      require(totalETH >= minReturn, "Not enough eth returned in swap");
      return totalETH;
    }

    // If we do have AMM tokens
    uint ammETH = AMMExchange.tokenToEthInput(ammAmount);

    // Validate total eth requirement
    totalETH += ammETH;
    require(totalETH >= minReturn, "Not enough eth returned in swap");

    // AMM Transfers
    token.transferFrom(msg.sender, address(this), ammAmount);
    recipient.transfer(ammETH);
    return totalETH;
  }

  /**
    @notice This function converts tokens to eth by taking an amount of eth the sender wishes to buy
    It goes through a recursive function so gas price goes up with very large orders.
    @param ethAmount Amount of eth to buy
    @param maxTokens maximum amount of tokens that can be used in the tx
    @param deadline time limit on the transaction
    @param recipient address to recive the eth
    @return Tokens sold
   */
  function tokenToEthOutput(
    uint ethAmount,
    uint maxTokens,
    uint deadline,
    address payable recipient
  ) external deadlineGuard(deadline) returns(uint) {
    // Start running the recursive handling function
    uint ethReserve = address(this).balance;
    (uint ammAmount, uint totalTokens) = handleTokensToEth(
      ethAmount,
      recipient,
      ethReserve,
      true,
      currentCielPrice
    );

    // Now that we finished this nasty recursion we only have AMM tokens to take care of
    // If we don't have AMM tokens, i.e. the whole order was fulfilled through the FPO then hooray
    if (ammAmount == 0) {
      require(totalTokens <= maxTokens, "Requiring to many tokens");
      return totalTokens;
    }

    // If we do have AMM tokens
    uint ammTokens = AMMExchange.tokenToEthOutput(ammAmount);

    // Validate total eth requirement
    totalTokens += ammTokens;
    require(totalTokens <= maxTokens, "Too much tokens required to swap");

    // AMM Transfers
    token.transferFrom(msg.sender, address(this), ammTokens);
    recipient.transfer(ammAmount);
    return totalTokens;
  }

  /**
    @notice This function converts eth to tokens by taking the msg.value that the sender wishes to sell
    It goes through a recursive function so gas price goes up with very large orders.
    @param minReturn minimum amount of tokens that has to be returned from the swap
    @param deadline time limit on the transaction
    @param recipient address to recive the tokens
    @return Eth purchased
   */
  function ethToTokenInput(
    uint minReturn,
    uint deadline,
    address payable recipient
  ) external payable deadlineGuard(deadline) returns(uint tokensBought) {
    // Start running the recursive handling function
    require(msg.value > 0);
    uint ethReserve = address(this).balance;
    (uint ammAmount, uint totalTokens) = handleEthToTokens(
      msg.value,
      recipient,
      ethReserve,
      true,
      currentFloorPrice
    );
    
    // Now that we finished this nasty recursion we only have AMM tokens to take care of
    // If we don't have AMM tokens, i.e. the whole order was fulfilled through the FPO then hooray
    if (ammAmount == 0) {
      require(totalTokens >= minReturn, "Too little tokens returned");
      return totalTokens;
    }

    // If we do have AMM tokens
    uint ammTokens = AMMExchange.ethToTokenInput(ammAmount);

    // Validate total eth requirement
    totalTokens += ammTokens;
    require(totalTokens >= minReturn, "Too little tokens returned");

    // AMM Transfers
    token.transfer(recipient, ammTokens);
    return totalTokens;
  }

   /**
    @notice This function converts eth to tokens by taking the the token amount that the seller wishes to buy
    and refunds her the redundent eth she sent
    It goes through a recursive function so gas price goes up with very large orders.
    @param tokenAmount Amount of tokens desired from the buy
    @param deadline time limit on the transaction
    @param recipient address to recive the tokens
    @return Eth purchased
   */
  function ethToTokenOutput(
    uint tokenAmount,
    uint deadline,
    address payable recipient
  ) external payable deadlineGuard(deadline) returns(uint) {
    // Start running the recursive handling function
    require(msg.value > 0, "No ETH sent to function");
    uint tokenReserve = token.balanceOf(address(this));
    (uint ammAmount, uint totalETH) = handleEthToTokens(
      msg.value,
      recipient,
      tokenReserve,
      false,
      currentFloorPrice
    );

    // Now that we finished this nasty recursion we only have AMM tokens to take care of
    // If we don't have AMM tokens, i.e. the whole order was fulfilled through the FPO then hooray
    if (ammAmount == 0) {
      require(totalETH <= msg.value, "Too much eth required");
      if (totalETH < msg.value) {
        msg.sender.transfer(msg.value - totalETH);
      }
      return totalETH;
    }

    // If we do have AMM tokens
    uint ammETH = AMMExchange.ethToTokenOutput(ammAmount);

    // Validate total eth requirement
    totalETH += ammETH;
    require(totalETH <= msg.value, "Too much eth required");
    if (totalETH < msg.value) {
      msg.sender.transfer(msg.value - totalETH);
    }

    // AMM Transfers
    token.transfer(recipient, tokenAmount);
    return totalETH;
  }

  // PUBLIC FUNCTIONS
  /**
    @notice Initializes the exchange after construction by seeding the liquidity and setting up minimal orderbooks
    @param tokenAmount The amount of tokens to match the msg.value and create the initial rate
   */
  function initializeExchange(uint tokenAmount) public payable {
    AMMExchange.initializeExchange(tokenAmount);
    FPOExchange.initializeExchange(tokenAmount);
  }

  /**
  @notice This function gets the amount of tokens that will be in the contract when it hits a certain rate
  @param rate rate to calculate token reserve for
  @return The amount of tokens at the floor
   */
  function getTokenReserveAtRate(uint rate) public view returns(
    uint tokenReserveAtCiel
  ) {
    (uint ethReserve, uint tokenReserve) = getCurrentReserveInfo();
    tokenReserveAtCiel = sqrt(
      tokenReserve.mul(ethReserve).mul(rate).div(RATE_DECIMALS)
    );
  }

  /**
  @notice This function gets the amount of eth that will be in the contract when it hits a certain rate
  @param rate rate to calculate eth reserve for
  @return The amount of eth at the floor
   */
  function getEthReserveAtRate(uint rate) public view returns(
    uint ethReserveAtCiel
  ) {
    (uint ethReserve, uint tokenReserve) = getCurrentReserveInfo();
    ethReserveAtCiel = sqrt(
      ethReserve.mul(tokenReserve).mul(RATE_DECIMALS).div(rate)
    );
  }

  // INTERNAL FUNCTIONS

  /**
  @dev This function handles transfering and selling tokens at the FPO.
  @param tokenAmount exact amount of tokens to trade, function will revert if not enough tokens in the level
  @param recipient recipient of the eth from the transaction
  @param cielPrice price of the level where the transaction is done
   */
  function sellTokensToFPO(
    uint tokenAmount,
    address payable recipient,
    uint cielPrice
  ) internal {
    token.transferFrom(msg.sender, address(ciels[cielPrice]), tokenAmount);
    ciels[cielPrice].approvedTrade(recipient, tokenAmount);
  }

  /**
  @dev This function handles transfering and selling eth at the FPO.
  @param ethAmount exact amount of eth to trade
  @param recipient recipient of the eth from the transaction
  @param floorPrice price of the level where the transaction is done
   */
  function sellEthToFPO(
    uint ethAmount,
    address payable recipient,
    uint floorPrice
  ) internal {
    floors[floorPrice].trade.value(ethAmount)(recipient);
  }

  /**
  @dev Handles selling a token at the ping pong exchange.
  It works via:
  1. Checking the amount that can be sold in AMM
  2. Selling the rest in FPO
  3. Repeat untill no more tokens to sell using recursion.
  @param amount amount of (tokens left to sell| eth left to buy)
  @param recipient recipient of funds 
  @param reserve (token|eth) reserve in the AMM
  @param ethOrToken signfies if amount and reserve are eth or token
  @return A tuple of (depending on ethOrToken):
  - The overall amount of (eth to buy| tokens to sell) at the AMM 
  - The total amount of (tokens sold | eth bought) in the FPO
   */
  function handleTokensToEth(
    uint amount,
    address payable recipient,
    uint reserve,
    bool ethOrToken,
    uint cielPrice
  ) internal returns(uint ammAmount, uint fpoAmount) {
    uint reserveAtCiel = ethOrToken ? getEthReserveAtRate(
      cielPrice
    ) : getTokenReserveAtRate(cielPrice);
    uint assetsTillCiel = ethOrToken ? reserve.sub(
      reserveAtCiel
    ) : reserveAtCiel.sub(reserve);
    uint fpoReturn;
    uint fpoRemainder;

    // AMM Check - short circuit
    if (assetsTillCiel >= amount) {
      return (amount, 0);
    }
    // Run through FPO
    ammAmount = assetsTillCiel;
    // We use a help function here to send the exact amount of tokens
    (fpoReturn, fpoRemainder) = ethOrToken ? FPOExchange.tokenToEthOutput(
      amount - ammAmount,
      cielPrice
    ) : FPOExchange.tokenToEthInput(amount - ammAmount, cielPrice);

    //Do FPO trade without remainder
    ethOrToken ? sellTokensToFPO(
      fpoReturn,
      recipient,
      cielPrice
    ) : sellTokensToFPO(
      amount - ammAmount - fpoRemainder,
      recipient,
      cielPrice
    );
    fpoAmount = fpoReturn;
    if (fpoRemainder == 0) {
      //If Remainder is 0 that means that the trade was a success and
      // loop is done
      // Now we check and check and change the price levels accordingly
      if (cielPrice != currentCielPrice) {
        currentCielPrice = cielPrice;
        currentFloorPrice = calculateStepDown(cielPrice, priceSpread);
      }
      return (ammAmount, fpoAmount);

    } else {
      // recursion :_(
      (uint additionAMM, uint additionFPO) = handleTokensToEth(
        fpoRemainder,
        recipient,
        reserveAtCiel,
        ethOrToken,
        calculateStepUp(cielPrice, priceSpread) // We've went up a level
      );
      return (ammAmount + additionAMM, fpoAmount + additionFPO);
    }

  }

  /**
  @dev Handles selling eth at the ping pong exchange.
  It works via:
  1. Checking the amount that can be sold in AMM
  2. Selling the rest in FPO
  3. Repeat untill no more eth to sell using recursion.
  @param amount amount of (eth left to sell| tokens left to buy)
  @param recipient recipient of funds 
  @param reserve (eth|token) reserve in the AMM
  @param ethOrToken signfies if amount and reserve are eth or token
  @return A tuple of (depending on ethOrToken):
  - The overall amount of (eth to sell| tokens to buy) at the AMM 
  - The total amount of (eth sold | tokens bought) in the FPO
   */
  function handleEthToTokens(
    uint amount,
    address payable recipient,
    uint reserve,
    bool ethOrToken,
    uint floorPrice
  ) internal returns(uint ammAmount, uint fpoAmount) {
    uint reserveAtFloor = ethOrToken ? getEthReserveAtRate(
      floorPrice
    ) : getTokenReserveAtRate(floorPrice);
    uint assetsTillFloor =  ethOrToken ? reserveAtFloor.sub(
      reserve
    ) : reserve.sub(reserveAtFloor);
    uint fpoReturn;
    uint fpoRemainder;
    
    // AMM Check - short circuit
    if (assetsTillFloor >= amount) {
      return (amount, 0);
    }
    // Run through FPO
    ammAmount = assetsTillFloor;
    // We use a help function here to send the exact amount of tokens
   
    (fpoReturn, fpoRemainder) = ethOrToken ? FPOExchange.ethToTokenInput(
      amount - ammAmount,
      floorPrice
    ) : FPOExchange.ethToTokenOutput(amount - ammAmount, floorPrice);

    //Do FPO trade without remainder
    ethOrToken ? sellEthToFPO(
      amount - ammAmount - fpoRemainder,
      recipient,
      floorPrice
    ) : sellEthToFPO(fpoReturn, recipient, floorPrice);
    fpoAmount = fpoReturn;
    if (fpoRemainder == 0) {
      //If Remainder is 0 that means that the trade was a success and
      // loop is done
      // Now we check and check and change the price levels accordingly
      if (floorPrice != currentFloorPrice) {
        currentFloorPrice = floorPrice;
        currentCielPrice = calculateStepUp(floorPrice, priceSpread);
      }
      return (ammAmount, fpoAmount);

    } else {
      // recursion :_(
      (uint additionAMM, uint additionFPO) = handleEthToTokens(
        fpoRemainder,
        recipient,
        reserveAtFloor,
        ethOrToken,
        calculateStepDown(floorPrice, priceSpread) // We've went down a level
      );
      return (ammAmount + additionAMM, fpoAmount + additionFPO);
    }

  }

  // PRIVATE FUNCTIONS

  // Simple sqrt function
  function sqrt(uint x) private pure returns(uint y) {
    if (x == 0) return 0;
    else if (x <= 3) return 1;
    uint z = (x + 1) / 2;
    y = x;
    while (z < y) {
      y = z;
      z = (x / z + z) / 2;
    }
  }

  function goLevelDown() private {
    currentCielPrice = currentFloorPrice;
    currentFloorPrice = calculateStepDown(currentFloorPrice, priceSpread);
  }

  function goLevelUp() private {
    currentFloorPrice = currentCielPrice;
    currentCielPrice = calculateStepUp(currentCielPrice, priceSpread);
  }
  /**
  @dev Called after selling tokens at FPO and checks if the remainder is small enough to go with the AMM 
  or needs to hit another level
  @param remainder the remainder of tokens left after the FPO sell
   */
  function handleTokenSellRemainder(
    uint remainder,
    uint cielPrice
  ) private view returns(uint ammAmount) {
    (, uint tokenReserve) = getCurrentReserveInfo();
    uint tokenReserveAtCiel = getTokenReserveAtRate(cielPrice);
    if (remainder <= tokenReserve.sub(tokenReserveAtCiel)) {
      // If AMM seals the deal then hooray
      ammAmount = remainder;

    } else {
      // If not incerement accordingly and go back to the loop
      ammAmount = tokenReserve.sub(tokenReserveAtCiel);
    }
  }

}
