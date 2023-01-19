// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10; 
import "@openzeppelin/contracts/access/Ownable.sol";


interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);

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

contract ClaimAniwarToken is Ownable {

  mapping (address => bool) public users;
  uint256 public immutable CLAIM_AMOUNT = 15000 * 10 ** 18;
  uint256 public airdropRefAmount;

  IERC20 public immutable ANI_TOKEN;

  bool public claimEnable;

  event Claimed(address indexed user);

  modifier isClaimEnable{
    require(claimEnable);
    _;
  }

  constructor(address _ani_token) {
    require(_ani_token != address(0x0));
    ANI_TOKEN = IERC20(_ani_token);
    claimEnable = true;
  }

  function setUsers(address[] memory _users)public onlyOwner {
    require(_users.length > 0);
    for (uint i = 0; i < _users.length; i++) {
      users[_users[i]] = false;
    }
  }
  function toggleClaim() public onlyOwner {
    claimEnable = !claimEnable;
  }

  function claimTokens() public isClaimEnable {
    if(!users[msg.sender]) {
      users[msg.sender] = true;
      ANI_TOKEN.transfer(msg.sender, CLAIM_AMOUNT);
      emit Claimed(msg.sender); 
    } else {
      revert("Already Claim or Not Authorized!");
    }
  }
 
  function depositToken(uint amount) public {
    ANI_TOKEN.transferFrom(msg.sender, address(this), amount);
  }

  function withdrawToken(uint amount) public onlyOwner {
    ANI_TOKEN.transfer(msg.sender, amount);
  }
}