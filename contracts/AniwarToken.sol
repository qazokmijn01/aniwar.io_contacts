// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract AniwarToken is ERC20, Pausable, AccessControl, ERC20Burnable {
  bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
  address private owner;

  constructor() ERC20("Aniwar Token", "ANIW") {
    owner = msg.sender;
    _setupRole(PAUSER_ROLE, msg.sender);
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _mint(msg.sender, 1000000000 * 10**18);
  }

  function pause() public onlyRole(PAUSER_ROLE) {
    _pause();
  }

  function unpause() public onlyRole(PAUSER_ROLE) {
    _unpause();
  }

  function _transfer(
    address sender,
    address recipient,
    uint256 amount
  ) internal virtual override {
    // require(tokenDenylist[msg.sender] == false, "Address in deny list");
    require(amount > 0, "ERC20: transfer amount must be greater than zero");
    require(sender != address(0), "ERC20: transfer from the zero address");
    require(recipient != address(0), "ERC20: transfer to the zero address");

    uint256 amountToBurn = amount / 100;
    increaseAllowance(owner, amountToBurn);

    super._transfer(sender, recipient, amount - amountToBurn);
  }
}
