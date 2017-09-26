pragma solidity ^0.4.15;

import './LockedAdvisorsAllocation.sol';
import './LockedAllocation.sol';
import 'zeppelin-solidity/contracts/math/SafeMath.sol';
import 'zeppelin-solidity/contracts/token/StandardToken.sol';
import 'zeppelin-solidity/contracts/ownership/Ownable.sol';
import 'zeppelin-solidity/contracts/lifecycle/Pausable.sol';

/// @title SeedToken - contract for seed token sale
/// @author Ashley Turing
contract SeedToken is StandardToken, Ownable {

    using SafeMath for uint;
    string public constant NAME = "SEED"; // public name of token
    string public constant SYMBOL = "SED"; // public three letter short code
    uint public constant DECIMALS = 18; // public decimal count

     
    uint public constant SEED_PRICE_ETHER  = 0.0005 ether;  // Ether note price fluctations may occur, however, it's fixed to simplify refund process


    uint constant public MIN_RAISED_SEED_QUANTITY             =   10000000e18;
    uint constant public MAX_PRESALE_SEED_QUANTITY            =   55000000e18;
    uint constant public MAX_SALE_SEED_QUANTITY               =  397500000e18;

    uint constant public SEED_INCENTIVE_RESERVE_QUANTITY      =   85000000e18;
    uint constant public FOUNDING_TEAM_RESERVE_QUANTITY       =   68750000e18; 
    uint constant public FUNDRAISER_ADVISERS_LOCKED_QUANTITY   =   9375000e18; 
    uint constant public FUNDRAISER_ADVISERS_UNLOCKED_QUANTITY =   9375000e18;

 
    uint constant TEN_YEARS = 10;   //Unsold, perhaps, destroy instead
    uint constant ONE_YEAR = 1;     // founding team and seed incentive program

  
    LockedAllocation public unsoldTokens;
    LockedAllocation public foundingTeamAllocation;
    LockedAllocation public seedIncentiveReserveAllocation;
    LockedAdvisorsAllocation public fundRaiserAdvisorsAllocation;


    address public fundRaiserAdvisorUnlockedAddress = 0x4162Ad6EEc341e438eAbe85f52a941B078210819;
    address public foundingTeamAddress = 0xe72bA5c6F63Ddd395DF9582800E2821cE5a05D75;
    address public seedIncentiveReserveAddress = 0xf0231160Bd1a2a2D25aed2F11B8360EbF56F6153;
    address unsoldAllocationAddress;

 
    address public seedTokenFactory;    // Multisigwallet where the proceeds will be stored.
    uint fundingStartBlock;
    uint fundingStopBlock;
    bool isFundingInProgress;      // flag crowdfund has started
    uint seedTokenSoldCounter;   //total used tokens
    uint presaleAllocationCounter = 0; // used as a sanity check for allocating presale

    event Refund(address indexed _from,uint256 _value);

    event Migrate(address indexed _from, address indexed _to, uint256 _value);
    
    event MoneyAddedForRefund(address _from, uint256 _value,uint256 _total);

    modifier isNotFundable() {
        if (isFundingInProgress) {
          revert();
        }
        _;
    }

    modifier isFundable() {
        if (!isFundingInProgress) {
          revert();
        }
        _;
    }

    //@notice  Constructor of SeedToken
    //@param `_seedTokenFactory` - multisigwallet address to store proceeds.
    //@param `_unsoldAllocationAddress` - Multisigwallet address to which unsold tokens are assigned. destroy instead?
    function SeedToken(address _seedTokenFactory, address _unsoldAllocationAddress) {
      if (_seedTokenFactory == address(0)) {
          revert();
      }
      if (_unsoldAllocationAddress == address(0)) {
          revert();
      }

      seedTokenFactory = _seedTokenFactory;
      seedTokenSoldCounter = 0;
     
      unsoldAllocationAddress = _unsoldAllocationAddress;

      //allot  9,375,000 tokens to advisors unlocked 
      balances[fundRaiserAdvisorUnlockedAddress] = FUNDRAISER_ADVISERS_UNLOCKED_QUANTITY;

      //allot  85,000,000  tokens to seed incentive reserve for 1 year inline with proof-of-concept release
      seedIncentiveReserveAllocation = new LockedAllocation(ONE_YEAR,seedIncentiveReserveAddress,SEED_INCENTIVE_RESERVE_QUANTITY);
      balances[address(seedIncentiveReserveAllocation)] = SEED_INCENTIVE_RESERVE_QUANTITY;

      //allocate tokens founding team reserve locked for 1 years inline with proof-of-concept release
      foundingTeamAllocation = new LockedAllocation(ONE_YEAR,foundingTeamAddress,FOUNDING_TEAM_RESERVE_QUANTITY);
      
      balances[address(foundingTeamAllocation)] = FOUNDING_TEAM_RESERVE_QUANTITY;

      isFundingInProgress = false;
    }

    //@notice Fallback function that accepts the ether and allocates tokens to
    //the msg.sender corresponding to msg.value
    function() payable isFundable external {
      purchase();
    }

    //@notice function that accepts the ether and allocates tokens to
    //the msg.sender corresponding to msg.value
    function purchase() payable isFundable {
      
      if (block.number < fundingStartBlock) {
          revert();
      }

      if (block.number > fundingStopBlock) {
          revert();
      }

      if (seedTokenSoldCounter >= MAX_SALE_SEED_QUANTITY) {
          revert();
      }

      if (msg.value < SEED_PRICE_ETHER) {
          revert();
      }

      uint numTokens = msg.value.div(SEED_PRICE_ETHER);
      if (numTokens < 1) {
          revert();
      }

      seedTokenFactory.transfer(msg.value);   //transfer funds to seedTokenFactory MultisigWallet

      uint tokens = numTokens.mul(1e18);

      seedTokenSoldCounter = seedTokenSoldCounter.add(tokens);
      
      if (seedTokenSoldCounter > MAX_SALE_SEED_QUANTITY) {
          revert();
      }

      balances[msg.sender] = balances[msg.sender].add(tokens);

    
      Transfer(0, msg.sender, tokens);   //event notification the transfer of tokens
    }

    //@notice Function returns number of tokens available for sale
    function numberOfSeedTokensAvailable() constant returns (uint256) {
      uint tokensAvailableForSale = MAX_SALE_SEED_QUANTITY.sub(seedTokenSoldCounter);
      return tokensAvailableForSale;
    }

    //@notice Finalize the ICO, send team allocation tokens
    //@notice send any remaining balance to the MultisigWallet
    //@notice unsold tokens to be destroyed
    function finalize() isFundable onlyOwner external {
      if (block.number <= fundingStopBlock) {
          revert();
      }

      if (seedTokenSoldCounter < MIN_RAISED_SEED_QUANTITY) {
          revert();
      }

      if (unsoldAllocationAddress == address(0)) {
          revert();
      }

  
      isFundingInProgress = false;      // disable funding

      //Allot team tokens to a smart contract which will frozen for 9 months
      fundRaiserAdvisorsAllocation = new LockedAdvisorsAllocation();
      balances[address(fundRaiserAdvisorsAllocation)] = FUNDRAISER_ADVISERS_LOCKED_QUANTITY;

      //allocate unsold tokens to iced storage
      uint totalUnSold = numberOfSeedTokensAvailable();
      if (totalUnSold > 0) {
        unsoldTokens = new LockedAllocation(TEN_YEARS,unsoldAllocationAddress,totalUnSold); // destroy???
        balances[address(unsoldTokens)] = totalUnSold;
      }

      //this should be 0?  transfer any balance available to Multisig Wallet
      seedTokenFactory.transfer(this.balance);
    }

    //@notice Used if fund raise isn't successful to be called by client
    function refund() isFundable external {
      
      if (block.number <= fundingStopBlock) {
          revert();
      }

      if (seedTokenSoldCounter >= MIN_RAISED_SEED_QUANTITY) {
          revert();
      }

      uint buyerSeedCount = balances[msg.sender];

      if (buyerSeedCount == 0) {
          revert();
      }

      balances[msg.sender] = 0;

      uint ethValue = buyerSeedCount.mul(SEED_PRICE_ETHER).div(1e18);

      msg.sender.transfer(ethValue);

      Refund(msg.sender, ethValue);
    }

    //@notice Function used for funding in case of refund.
    function allocateForRefund() external payable onlyOwner returns (uint) {
      //accepts and stores ether, nothing more
      MoneyAddedForRefund(msg.sender,msg.value,this.balance);
      return this.balance;
    }

    //@notice Function allocates tokens to a user
    //@param `_to` address
    //@param `_tokens` total count 
    //@notice Called by owner when funding not active
    function allocateTokens(address _to,uint _tokens) isNotFundable onlyOwner external {
      uint numOfTokens = _tokens.mul(1e18);
      presaleAllocationCounter = presaleAllocationCounter.add(numOfTokens);

      if (presaleAllocationCounter > MAX_PRESALE_SEED_QUANTITY) {
          revert();
      }

      balances[_to] = balances[_to].add(numOfTokens);
    }

    //@notice Function unpause sale called only by owner when funding is in progress
    function unPauseTokenSale() onlyOwner isNotFundable external returns (bool) {
      isFundingInProgress = true;
      return isFundingInProgress;
    }

    //@notice Function pauses sale called only by owner when funding is in progress
    function pauseTokenSale() onlyOwner isFundable external returns (bool) {
      isFundingInProgress = false;
      return !isFundingInProgress;
    }

    //@notice Function starts fundraise
    //@param `_fundingStartBlock` -starting block for fund start
    //@param `_fundingStopBlock` - ending block for close of fund raise
    function startTokenSale(uint _fundingStartBlock, uint _fundingStopBlock) onlyOwner isNotFundable external returns (bool) {
      if (_fundingStopBlock <= _fundingStartBlock) {
          revert();
      }

      fundingStartBlock = _fundingStartBlock;
      fundingStopBlock = _fundingStopBlock;
      isFundingInProgress = true;
      return isFundingInProgress;
    }

    //@notice Function returns if funding is in progress
    function fundingStatus() external constant returns (bool) {
      return isFundingInProgress;
    }
}
