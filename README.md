## Testnet contracts deployed

- CupexDEX: 0xBE3B33c35777CD4441B2465F6E41d0a422999940
- CupexStaking: 0xfdA125D15d1aCb923ad292c9F1d15dbc5d5BEf5a
- Tokens:
  - CUPEX: 0x6aADB85DD1f4B8495900A0D17a2F24d5Bd1948B3
  - USDC: 0x0E2569c59c93e406015bFbC52Ead7440267579B9
  - DAI: 0x4996043F6713cf04B89Ca1d2067c355fb50a81f8
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
