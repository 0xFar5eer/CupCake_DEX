// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./openzeppelin-contracts-4.6.0/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

abstract contract cupexERC1155 is ERC1155Supply {
  string contractName = "CupCake_DEX";
  string contractSymbol = "CUPEX";
  string urlPrefix;

  constructor() ERC1155("") {}

  function name() external view returns (string memory) {
    return contractName;
  }

  function symbol() external view returns (string memory) {
    return contractSymbol;
  }

  function decimals() external pure returns (uint256) {
    return 18;
  }
}
