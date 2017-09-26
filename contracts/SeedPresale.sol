pragma solidity ^0.4.15;

import 'zeppelin-solidity/contracts/math/SafeMath.sol';
import 'zeppelin-solidity/contracts/ownership/Ownable.sol';
import 'zeppelin-solidity/contracts/lifecycle/Pausable.sol';

// SeedPresale Contract
// author Ashley Turing 
// pausable for emergency purposes only
contract SeedPreSale is Pausable {
  using SafeMath for uint;


  // priced in finney /  note this will not take into consideration price fluctuations of ether 
  uint constant PRESALE_PRICE = 0.0005 ether; // minimum price and unit of division
  uint constant PRESALE_BONUS_TOTAL_COUNT = 55000000;
  uint constant PRESALE_COUNT = 50000000;

  address seedTokenFactory;
  uint seedSoldCounter;  // how many have been sold counter 
  mapping(address => uint) balances; // balances of purchasers
  address[] purchasers; // array of purchasers
  uint startBlock;  // start block for the presale
  uint endBlock;  // end block for presale

  uint public salePeriod;

  function SeedPreSale(address _seedTokenFactory,uint _startBlock,uint _endBlock) {
    
    if (_seedTokenFactory == address(0)) {
          revert();
    }

    if (_endBlock <= _startBlock) {
          revert();
    }

    // start presale
    salePeriod = now.add(50 hours);
    startBlock = _startBlock;
    endBlock = _endBlock;
    seedTokenFactory = _seedTokenFactory;
    seedSoldCounter = 0;
  }

  function () external whenNotPaused payable {

    if (now > salePeriod) {
          revert();
    }

    if (block.number < startBlock) {
          revert();
    }

    if (block.number > endBlock) {
          revert();
    }

    if (seedSoldCounter >= PRESALE_BONUS_TOTAL_COUNT) {
          revert();
    }

    if (msg.value < PRESALE_PRICE) {
          revert();
    }

    uint numTokens = msg.value.div(PRESALE_PRICE);

    if (numTokens < 1) {
          revert();
    }

    //1 bonus for every 10 bought
    uint discountTokens = numTokens.div(10);

    numTokens = numTokens.add(discountTokens);

    seedSoldCounter = seedSoldCounter.add(numTokens);

    if (seedSoldCounter > PRESALE_BONUS_TOTAL_COUNT) {
          revert();
    }

    //transfer money to seedTokenFactory MultisigWallet
    seedTokenFactory.transfer(msg.value);

    purchasers.push(msg.sender);
    
    balances[msg.sender] = balances[msg.sender].add(numTokens);
  }

  function getTotalPresaleSupply() external constant returns (uint256) {
    return PRESALE_BONUS_TOTAL_COUNT;
  }

  //@notice returns Seed tokens still available for presale
  function numberOfTokensLeft() constant returns (uint256) {
    uint tokensAvailableForSale = PRESALE_BONUS_TOTAL_COUNT.sub(seedSoldCounter);
    return tokensAvailableForSale;
  }

  function finalize() external whenNotPaused onlyOwner {
    if (block.number < endBlock && seedSoldCounter < PRESALE_COUNT) {
          revert();
    }

    seedTokenFactory.transfer(this.balance);
    paused = true;
  }

  function balanceOf(address owner) constant returns (uint) {
    return balances[owner];
  }

  function getPurchasers() onlyOwner whenPaused external returns (address[]) {
    return purchasers;
  }

  function numOfPurchasers() onlyOwner external constant returns (uint) {
    return purchasers.length;
  }

  function unpause() onlyOwner whenPaused returns (bool) {
    salePeriod = now.add(50 hours);
    super.unpause();
  }
}
