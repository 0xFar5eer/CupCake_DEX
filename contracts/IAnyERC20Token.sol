// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./openzeppelin-contracts-4.6.0/contracts/token/ERC20/IERC20.sol";

interface IAnyErc20Token is IERC20 {
    function mint(address _to, uint256 _amount) external;
    function burn(address _from, uint256 _amount) external;
}