// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "../contracts/PriceFetcher.sol";

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

contract AstterFi {
  using SafeMath for uint256;
  address owner;
  uint regNo;
  uint interestRate;
  uint transferId;
  PriceConverter pf;
  IERC20 USDT;

  mapping(address => uint) credit_limit;
  mapping(address => uint) borrowed;
  mapping(string => uint) treasury;
  mapping(address => bool) registeredUser;
  mapping(address => uint) deposit;

  event CreditLimitIncreased(address indexed user, uint indexed newLimit);
  event CreditTrasnfered(uint indexed transferId, address indexed seller, address indexed borrower, uint amount);

  modifier onlyOwner{
     require(msg.sender == owner, "Only owner can make changes");
     _;
  }

  constructor() {
    owner = msg.sender;
    regNo = 0;
    treasury["USDT"] = 0;
    treasury["MATIC"] = 0;
    pf = PriceConverter(0x868DF7B30D931Bf0a48755C9D94d0e4618a25cf2);
    //USDT = IERC20();
  }

  fallback() external{}

  receive() external payable { 
      uint limit = credit_limit[msg.sender];
      uint rate = uint(pf.getDerivedPrice(0xd0D5e3DB44DE05E9F294BB0a3bEEaF030DE24Ada, 0x0FCAa9c899EC5A91eBc3D5Dd869De833b06fB046, 8));
      limit = limit.add(msg.value.mul(rate));
      credit_limit[msg.sender] = limit;

      deposit[msg.sender] = deposit[msg.sender].add(msg.value); 
      treasury["MATIC"] = treasury["MATIC"].add(msg.value);
  }

  function setInterestRate(uint rate) external {
      interestRate = rate;
  } 

  function approveBorrow(address seller, uint amount) external {
      require(amount < (credit_limit[msg.sender] - borrowed[msg.sender]), "Exceeded Credit Limit");
      require(registeredUser[seller] == true, "Seller not registered");
      require(registeredUser[msg.sender] == true, "User not registered");

      borrowed[msg.sender] = borrowed[msg.sender].add(amount);
      treasury["USDT"] = treasury["USDT"].sub(amount);

      USDT.transfer(seller, amount);
  }

  function getLimit() external view returns(uint){
     return credit_limit[msg.sender];
  }

  function getDeposit() external view returns(uint) {
     return deposit[msg.sender];
  }

  function withdrawDeposit() external {
    require(borrowed[msg.sender] == 0, "Amount borrowed yet to be repayed");
    //require(registeredUser[msg.sender] == true, "User must be registered to withdraw funds");
    credit_limit[msg.sender] = 0;

    msg.sender.call{value: deposit[msg.sender]}("");
  }
  //1% per month
}
