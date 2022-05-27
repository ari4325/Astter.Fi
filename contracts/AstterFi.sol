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
  //mapping(address => bool) registeredUser;
  mapping(address => uint) deposit;
  mapping(address => mapping(uint => uint)) repayment;
  mapping(address => mapping(uint => bool)) repaymentStatus;
  mapping(address => bool) hasBorrowed;
  mapping(address => mapping(uint => uint)) repayAmount;

  event CreditLimitIncreased(address indexed user, uint indexed newLimit);
  event CreditTrasnfered(uint indexed transferId, address indexed seller, address indexed borrower, uint amount);

  modifier onlyOwner{
     require(msg.sender == owner, "Only owner can make changes");
     _;
  }

  constructor() {
    owner = msg.sender;
    regNo = 0;
    treasury["USDT"] = 1000000000;
    treasury["MATIC"] = 0;
    pf = PriceConverter(0x868DF7B30D931Bf0a48755C9D94d0e4618a25cf2);
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

  function setTokenAddress(address _addr) external {
     USDT = IERC20(_addr);
  }

  function approveBorrow(address seller, uint amount) external {
      require(hasBorrowed[msg.sender] != true, "User has an existing credit usage");
      require(amount < credit_limit[msg.sender], "Exceeded Credit Limit");

      borrowed[msg.sender] = borrowed[msg.sender].add(amount);
      treasury["USDT"] = treasury["USDT"].sub(amount);

      hasBorrowed[msg.sender] = true;

      //0x83EFDd0E859412c4Ba4E383EA3A9DA09f909F2fC

      uint installment = amount.div(3);

      repayAmount[msg.sender][0] = installment;
      repayAmount[msg.sender][1] = installment;
      repayAmount[msg.sender][2] = installment;

      repayment[msg.sender][0] = block.timestamp + 30 days;
      repayment[msg.sender][1] = block.timestamp + 60 days;
      repayment[msg.sender][2] = block.timestamp + 90 days;

      repaymentStatus[msg.sender][0] = false;
      repaymentStatus[msg.sender][1] = false;
      repaymentStatus[msg.sender][2] = false;

      USDT.transfer(seller, amount);
  }

  function getLimit() external view returns(uint){
     return credit_limit[msg.sender];
  }

  function getDeposit() external view returns(uint) {
     return deposit[msg.sender];
  }

  function withdrawDeposit() external {
    require(deposit[msg.sender] != 0, "User does not have any deposit"); 
    require(borrowed[msg.sender] == 0, "Amount borrowed yet to be repayed");
    //require(registeredUser[msg.sender] == true, "User must be registered to withdraw funds");
    uint transferAmt = deposit[msg.sender];
    deposit[msg.sender] = 0;
    credit_limit[msg.sender] = 0;

    msg.sender.call{value: transferAmt}("");
  }
  //1% per month

  function getDeadline() external view returns(uint[3] memory) {
      uint[3] memory deadline = [repayment[msg.sender][0], repayment[msg.sender][1], repayment[msg.sender][2]];
      return deadline;
  }

  function DeadlineStatus(uint n) external view returns(bool) {
      return repaymentStatus[msg.sender][n];
  }

  function repay(uint n) external payable {
      USDT.transferFrom(msg.sender, address(this), repayAmount[msg.sender][n]);
  }
}
