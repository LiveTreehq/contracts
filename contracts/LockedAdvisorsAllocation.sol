pragma solidity ^0.4.15;
import './SeedToken.sol';


import 'zeppelin-solidity/contracts/ownership/Ownable.sol';
import 'zeppelin-solidity/contracts/math/SafeMath.sol';


contract LockedAdvisorsAllocation is Ownable {
  using SafeMath for uint;


  uint constant public FUNDING_ADVISORS_LOCKED_QUANTITY = 9375000e18;

  uint public unLockDate;
  SeedToken sed;
  mapping (address => uint) allocations;
  uint seedTokensAllocatedToThisContract = 0;
  
  address public fundingAdvisorsAddress = 0x3f5D90D5Cc0652AAa40519114D007Bf119Afe1Cf;


  function LockedAdvisorsAllocation() {
    sed = SeedToken(msg.sender);
 
    uint nineMonths = 9 * 30 days;  // approx 9 months
 
    unLockDate = now.add(nineMonths); 
 
    allocations[fundingAdvisorsAddress] = FUNDING_ADVISORS_LOCKED_QUANTITY;
  }

  function getTotalAllocation() returns (uint) {
      return FUNDING_ADVISORS_LOCKED_QUANTITY;
  }

  function unlock() external payable {
  
    if (now < unLockDate) {
          revert();
    }

    if (seedTokensAllocatedToThisContract == 0) {
      seedTokensAllocatedToThisContract = sed.balanceOf(this);
    }
    
    sed.transfer(fundingAdvisorsAddress, seedTokensAllocatedToThisContract);  // transfer funds to advisors address
  }
}
