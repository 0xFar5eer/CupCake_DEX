## Testnet contracts deployed

XDC Testnet:

- CupexDEX: 0x54CDD5073F94e1Be40BC9AfAdf6D1b7a564c24CC
- CupexStaking: 0x9D7719BA8A28043016a779b51b2DF3a53378c02b
- Tokens:
  - CUPEX: 0xf79FE1F343304d634ec21f75c28A58d8518549fD
  - USDC: 0x49F8D2cFcAE854B9f657bFEf61F8Ad22261eB627
  - DAI: x049D50E7e4FE6ed60365De20b0871770D12A1F57
  - NATIVE: 0x0000000000000000000000000000000000000000

## Useful functions

- ERC20.balanceOf(wallet)
- cupexStaking:
  - function createStake(uint256 \_amount) public
  - function unStake() public
  - function getStakeInformation() public view returns (StakeInformation memory)
    struct StakeInformation {
    uint256 timestampStaked;
    uint256 amountStaked;
    uint256 interest;
    }
- cupexDEX:
  - function getListOfActiveTokens() public view returns (IERC20[] memory)
  - function addLiquidity(
    IERC20 \_tokenAddr,
    uint256 \_amountTokensIn,
    uint256 \_amountCupexTokensIn,
    uint256 \_minAmountTokensIn,
    uint256 \_minAmountCupexTokensIn,
    address \_transferTo
    )
    public
    payable
    returns (uint256)
  - function removeLiquidity(
    IERC20 \_tokenAddr,
    uint256 \_amountOfLiquidityToRemove,
    uint256 \_minAmountTokensOut,
    uint256 \_minAmountCupexTokensOut,
    address \_transferTo
    )
    public
    returns (uint256, uint256)
  - Swap 100 USDC --> YYY DAI: function swapExactTokensForTokens(
    IERC20 \_tokenIn,
    IERC20 \_tokenOut,
    uint256 \_amountTokensIn,
    uint256 \_minAmountTokensOut,
    address \_transferTo
    )
    public
    payable
    returns (uint256)
  - Swap XXX USDC --> 100 DAI: function swapTokensForExactTokens(
    IERC20 \_tokenIn,
    IERC20 \_tokenOut,
    uint256 \_maxAmountTokensIn,
    uint256 \_amountTokensOut,
    address \_transferTo
    )
    public
    payable
    returns (uint256)
  - get XXX, 100 USDC --> XXX DAI: function getExactTokensForTokens(
    IERC20 \_tokenIn,
    IERC20 \_tokenOut,
    uint256 \_amountIn
    ) public view returns (uint256)
  - get YYY, YYY USDC --> 100 DAI:
    function getTokensForExactTokens(
    IERC20 \_tokenIn,
    IERC20 \_tokenOut,
    uint256 \_amountOut
    ) public view returns (uint256)
