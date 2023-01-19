// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10; 
import "@openzeppelin/contracts/access/Ownable.sol";


interface IERC20 {
    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    function decimals() external view returns (uint8);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

// File: contracts/Leverjbounty.sol

contract Airdrop is Ownable {

  mapping (address => bool) public users;
  mapping (address => bool) public usersRef;
  uint256 public airdropAmount;
  uint256 public airdropRefAmount;

  IERC20 public immutable ANIWAR_TOKEN;

  bool public dropEnabled;

  event Redeemed(address user, uint tokens);
  event RefRedeemed(address user, uint tokens);

  modifier canWithdraw(string memory _secret, bytes memory data) {
    require(dropEnabled);
    (address user, string memory secret, uint aniType) = decode(data);
    if (keccak256(abi.encodePacked((secret))) == keccak256(abi.encodePacked((_secret)))) { 
      require(users[]);
      _;
    }
  }
  constructor(address _token, uint256 _airdropAmount, uint256 _airdropRefAmount) {
    require(_token != address(0x0));
    ANIWAR_TOKEN = IERC20(_token);
    airdropAmount = _airdropAmount * 10 ** ANIWAR_TOKEN.decimals();
    airdropRefAmount = _airdropRefAmount * 10 ** ANIWAR_TOKEN.decimals();
  }

  function addUsers(address[] memory _users) public onlyOwner {
    require(_users.length > 0);
    for (uint i = 0; i < _users.length; i++) {
      users[_users[i]] = true;
    }
  }
  function addUsersRef(address[] memory _usersRef) public onlyOwner {
    require(_usersRef.length > 0);
    for (uint i = 0; i < _usersRef.length; i++) {
      usersRef[_usersRef[i]] = true;
    }
  }

  function removeUsers(address[] memory _users) public onlyOwner {
    require(_users.length > 0);
    for (uint i = 0; i < _users.length; i++) {
      users[_users[i]] = false;
    }
  }
  function removeUsersRef(address[] memory _usersRef) public onlyOwner {
    require(_usersRef.length > 0);
    for (uint i = 0; i < _usersRef.length; i++) {
      usersRef[_usersRef[i]] = false;
    }
  }
  function toggleDrop() public onlyOwner {
    dropEnabled = !dropEnabled;
  }

  function redeemTokens() public canWithdraw {
    if(users[msg.sender]) {
      users[msg.sender] = false;
      ANIWAR_TOKEN.transfer(msg.sender, airdropAmount);
      emit RefRedeemed(msg.sender, airdropAmount); 
    } else if(usersRef[msg.sender]) {
      usersRef[msg.sender] = false;
      ANIWAR_TOKEN.transfer(msg.sender, airdropRefAmount);
      emit RefRedeemed(msg.sender, airdropRefAmount); 
    } else {
      revert("Not authorized!");
    }
  }
 

  function transferTokens(address _address, uint256 _amount) public onlyOwner {
    ANIWAR_TOKEN.transfer(_address, _amount);
  }

  function depositToken(uint amount) public {
    ANIWAR_TOKEN.transferFrom(msg.sender, address(this), amount);
  }

  function withdrawToken(uint amount) public onlyOwner {
    ANIWAR_TOKEN.transfer(msg.sender, amount);
  }

  function encode(address _arg1, string memory _arg2, uint _agr3) public onlyOwner view returns (bytes memory) {
        return (_encode(_arg1, _arg2, _agr3));
  }
  
  function _encode(address _agr1, string memory _agr2, uint _agr3) private pure returns (bytes memory) {
        return (abi.encode(_agr1, _agr2, _agr3));
  }

  function decode(bytes memory data) private pure returns (address _agr1, string memory _agr2, uint _agr3) {
        (_agr1, _agr2, _agr3) = abi.decode(data, (address, string, uint));            
  }
}