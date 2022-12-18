## Testnet contracts deployed

The contract was built completely from scratch following uniswap v2 whitepaper.
Code was optimized for swaps.
The following results were achieved:

- swapping XDC --> CUPEX, costs 64,018 gas https://apothem.blocksscan.io/tx/0xf6bddf342fc8e606acfe6e5d3989b35db5f1dd0c31be77465ecc9f2dc1943fd3
- swapping CUPEX --> XDC, costs 70,803 gas https://apothem.blocksscan.io/tx/0x0ec27592a3665a1fbf5cff4013b7200dba92ab126e530f8421d5ddfa7ddab483
- swapping USDC --> DAI, costs 106,968 gas https://apothem.blocksscan.io/tx/0x5d8e3fa5e36a4d3c222727bb71898ff006166b4599f7c6edf3f03bf3a982b371

Comparing to uniswap v2 swaps which takes 110,000 per swap.
Cupcake DEX costs 3-41% cheaper.
The optimization is not final, gas usage can be reduced even further but for the simplicity of the contract some of the optimizations were omitted such as:

- using clone factory for new pairs which allows us to remove several fields from storage (gives additional 20-30% gas usage decrease)
- tightly fitting storage space (gives additional 1-5% gas usage decrease)
- instead of ERC20 token for Liquidity Providing, DEX uses ERC1155 tokens

The features of this DEX:

- native tokens XDC aren't converted to wrapped version WXDC
- all tokens are stored on the single main contract address which means no new pair contracts are created
- there is no router contract needed as everything fits in a single contract
- all ERC20 or native tokens must be paired with CUPEX token only which allows us to swap Any Token1 <--> Any Token2 using CUPEX Token in between (Token1 --> CUPEX --> Token2). This is hidden inside the contract logics for user's convenience.
- simple and convenient swapping interface functions for developers
- single DEX contract hosts ERC1155 Liquidity Provider tokens
- code is very well commented and should be simple to understand
- swap fee is static 0.15% per each swap
- MIT license allows anyone to continue development

Staking option:

- DEX supports simple staking operations such as createStake and unStake
- simple algorithm applied: 10% daily inflation for CUPEX tokens
- on createStake tokens are burned
- on unStake tokens are minted plus interest

Limitations:

- for testing purposes all Approvals were disabled in the ERC20 token contracts, in production it must be added back
- staking is calling unprotected mint/burn functions, in production whitelist protection must be added

## Testnet contracts deployed

XDC Testnet:

- CupexDEX: 0x54CDD5073F94e1Be40BC9AfAdf6D1b7a564c24CC
- CupexStaking: 0x9D7719BA8A28043016a779b51b2DF3a53378c02b
- Tokens:
  - CUPEX: 0xf79FE1F343304d634ec21f75c28A58d8518549fD
  - USDC: 0x49F8D2cFcAE854B9f657bFEf61F8Ad22261eB627
  - DAI: 0x049D50E7e4FE6ed60365De20b0871770D12A1F57
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
