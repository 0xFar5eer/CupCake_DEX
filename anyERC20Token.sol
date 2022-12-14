// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./openzeppelin-contracts-4.6.0/contracts/token/ERC20/ERC20.sol";

contract AnyErc20Token is ERC20 {
  constructor(string memory _name, string memory _symbol)
    ERC20(_name, _symbol)
  {
    _mint(0xcfB57caFF4d3DECf4eCec005c5260821e42Dd56d, 1e18 * 1e9);
    _mint(0x40385F27D90eb7A7FCa6F521176C6eBADBE57632, 1e18 * 1e9);
    _mint(msg.sender, 1e18 * 1e9);
  }

  function transferFrom(
      address from,
      address to,
      uint256 amount
  ) public virtual override returns (bool) {
      // for the simplyfing sake we allow any contract to transfer
      // tokens without any approval
      // TODO: uncomment in production
      // address spender = _msgSender();
      // _spendAllowance(from, spender, amount);
      _transfer(from, to, amount);
      return true;
  }

  // no protection for testing purposes
  function mint(address _to, uint256 _amount) external {
    _mint(_to, _amount);
  }

  // no protection for testing purposes
  function burn(address _from, uint256 _amount) external {
    _burn(_from, _amount);
  }
}
