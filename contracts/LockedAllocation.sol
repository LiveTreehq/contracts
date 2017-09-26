pragma solidity ^0.4.15;

import './SeedToken.sol';
import 'zeppelin-solidity/contracts/ownership/Ownable.sol';
import 'zeppelin-solidity/contracts/math/SafeMath.sol';


contract LockedAllocation is Ownable {
  using SafeMath for uint;
  
  
  uint unLockedDate;
  uint tokensAllocated;
  SeedToken sed;
  mapping (address => uint) allocationAddresses;

  uint tokensCreated = 0;

  /*
    Founding team 1 year
    Seed incentive programme lock 1 year
  */

  function LockedAllocation(uint _lockTime, address _allocatedTo, uint _tokensAllocated) {
    if (_lockTime == 0) {
          revert();
    }

    if (_allocatedTo == address(0)) {
          revert();
    }

    sed = SeedToken(msg.sender);
    uint lockTime = _lockTime * 1 years;
    unLockedDate = now.add(lockTime);
    tokensAllocated = _tokensAllocated;
    allocationAddresses[_allocatedTo] = _tokensAllocated;
  }

  function getTotalAllocation()returns(uint) {
      return tokensAllocated;
  }

  function unlock() external payable {
    if (now < unLockedDate) {
          revert();
    }

    if (tokensCreated == 0) {
      tokensCreated = sed.balanceOf(this);
    }

    var allocation = allocationAddresses[msg.sender];
    allocationAddresses[msg.sender] = 0;
    var toTransfer = (tokensCreated.mul(allocation)).div(tokensAllocated);
    sed.transfer(msg.sender, toTransfer);
  }
}
