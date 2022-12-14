// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./anyERC20Token.sol";
import "./cupexERC1155.sol";
import "./openzeppelin-contracts-4.6.0/contracts/token/ERC20/IERC20.sol";
import "./openzeppelin-contracts-4.6.0/contracts/security/ReentrancyGuard.sol";

contract CupexDEX is cupexERC1155, ReentrancyGuard {
  address constant DEAD_ADDRESS = address(0xDEAD); // here can be well known null address, nobody has access to it
  uint256 constant MINIMUM_LIQUIDITY = 1_000;

  // 0x0000000000000000000000000000000000000000 1000000000000000000
  IERC20 constant NATIVE_TOKEN = IERC20(address(0)); // we use null address for native tokens

  IERC20 public cupexToken;
  Pool[] public listOfPools;

  mapping(IERC20 => uint256) tokenAddressToPoolId;

  uint256 constant TRADE_FEE_NOMINATOR = 15; // 0.15% = 15/10,000
  uint256 constant TRADE_FEE_DENOMINATOR = 10_000;
  uint256 constant TRADE_FEE_DENOMINATOR_MINUS_NOMINATOR =
    TRADE_FEE_DENOMINATOR - TRADE_FEE_NOMINATOR;

  struct Pool {
    IERC20 tokenInPool;
    uint256 cupexTokenBalance;
  }

  event PoolCreated(IERC20 indexed _token, uint256 _poolId);

  event LiquidityAdded(
    IERC20 indexed _token,
    uint256 _amountTokensIn,
    uint256 _amountCupexTokensIn,
    uint256 _lpTokensAmount,
    address _transferTo
  );

  event LiquidityRemoved(
    IERC20 indexed _token,
    uint256 _amountTokensOut,
    uint256 _amountCupexTokensOut,
    uint256 _lpTokensAmount,
    address _transferTo
  );

  event Swap(
    IERC20 indexed _token,
    uint256 _amountTokensIn,
    uint256 _amountCupexTokensIn,
    uint256 _amountTokensOut,
    uint256 _amountCupexTokensOut
  );

  event Sync(
    IERC20 indexed _token,
    uint256 _newBalanceToken,
    uint256 _newBalanceCupex
  );

  constructor() {
    // filling 0th element of pool as empty
    // this is needed for simplifying query of pools
    // not existing tokens will return 0th pool always
    // that is how we detect inexistency
    listOfPools.push(
      Pool({ tokenInPool: IERC20(NATIVE_TOKEN), cupexTokenBalance: 0 })
    );
  }

  // Creates the pool [XXX, CUPEX]
  function createPool(IERC20 _tokenAddr) public returns (uint256) {
    require(_tokenAddr != cupexToken, "Token must be different from CUPEX Token");
    require(
      tokenAddressToPoolId[_tokenAddr] == 0,
      "Pool for this token already exists"
    );

    // saving new poolId for this _tokenAddr
    // position of the pool in listOfPools array
    // starts from 1 because we filled 0th element with empty pool
    uint256 poolId = listOfPools.length;
    tokenAddressToPoolId[_tokenAddr] = poolId;

    // pushing new token to the pool array
    listOfPools.push(Pool({ tokenInPool: _tokenAddr, cupexTokenBalance: 0 }));

    emit PoolCreated(_tokenAddr, poolId);
    return poolId;
  }

  // Note: We must add [XXX, CUPEX] tokens only
  // Adding arbitrary [XXX, YYY] tokens like in uniswap is forbidden
  // Everything must be paired to core CUPEX token (!)
  function addLiquidity(
    IERC20 _tokenAddr,
    uint256 _amountTokensIn,
    uint256 _amountCupexTokensIn,
    uint256 _minAmountTokensIn,
    uint256 _minAmountCupexTokensIn,
    address _transferTo
  )
    public
    payable
    nonReentrant // re-entrancy protection
    returns (uint256)
  {
    uint256 poolId = tokenAddressToPoolId[_tokenAddr];
    if (poolId == 0) {
      poolId = createPool(_tokenAddr);
    }

    // creating link to storage for further read/writes
    Pool storage pool = listOfPools[poolId];

    // balance of token in the pool before the transfers
    uint256 poolTokenBalanceBefore = _getTokenBalanceInPoolBefore(_tokenAddr);

    uint256 totalSupplyOfLiquidity = totalSupply(poolId);

    uint256 amountOfLiquidityToMint = 0;
    if (totalSupplyOfLiquidity == 0) {
      // first time adding liquidity to this pair
      // minting 1000 lp tokens to null address as per uniswap v2 whitepaper
      // refer to 3.4 Initialization of liquidity token supply https://uniswap.org/whitepaper.pdf
      // minting ERC1155 token for dead address
      // refer to https://github.com/Uniswap/v2-core/blob/8b82b04a0b9e696c0e83f8b2f00e5d7be6888c79/contracts/UniswapV2Pair.sol#L119-L124
      _mint(DEAD_ADDRESS, poolId, MINIMUM_LIQUIDITY, "");

      // refer to https://github.com/Uniswap/v2-core/blob/8b82b04a0b9e696c0e83f8b2f00e5d7be6888c79/contracts/UniswapV2Pair.sol#L119-L124
      amountOfLiquidityToMint =
        _sqrt(_amountTokensIn * _amountCupexTokensIn) -
        MINIMUM_LIQUIDITY;
    } else {
      // not first time adding liquidity to this pair
      // refer to https://github.com/Uniswap/v2-periphery/blob/2efa12e0f2d808d9b49737927f0e416fafa5af68/contracts/UniswapV2Router01.sol#L46-L55
      uint256 optimalAmountTokensIn = (_amountCupexTokensIn *
        poolTokenBalanceBefore) / pool.cupexTokenBalance;
      if (optimalAmountTokensIn <= _amountTokensIn) {
        require(
          optimalAmountTokensIn >= _minAmountTokensIn,
          "Insufficient _amountTokensIn provided"
        );
        _amountTokensIn = optimalAmountTokensIn;
      } else {
        uint256 optimalAmountCupexTokensIn = (_amountTokensIn *
          pool.cupexTokenBalance) / poolTokenBalanceBefore;

        require(
          optimalAmountCupexTokensIn <= _amountCupexTokensIn,
          "Insufficient _amountTokensIn & _amountCupexTokensIn provided"
        );
        require(
          optimalAmountCupexTokensIn >= _minAmountCupexTokensIn,
          "Insufficient _amountCupexTokensIn provided"
        );
        _amountCupexTokensIn = optimalAmountCupexTokensIn;
      }

      // it is Math.min(x1, x2)
      amountOfLiquidityToMint = _min(
        (_amountTokensIn * totalSupplyOfLiquidity) / poolTokenBalanceBefore,
        (_amountCupexTokensIn * totalSupplyOfLiquidity) / pool.cupexTokenBalance
      );
    }

    require(
      amountOfLiquidityToMint > 0,
      "Insufficient amount of liquidity minted"
    );

    // updating pool balance in storage
    pool.cupexTokenBalance += _amountCupexTokensIn;

    // transferring token from msg sender to contract
    _safeTokenTransferFromMsgSender(_tokenAddr, _amountTokensIn);

    // CUPEX token does not require additional checks
    // thats why we can use regular transferFrom call
    cupexToken.transferFrom(msg.sender, address(this), _amountCupexTokensIn);

    // minting ERC1155 LP token for user
    _mint(_transferTo, poolId, amountOfLiquidityToMint, "");

    emit LiquidityAdded(
      _tokenAddr,
      _amountTokensIn,
      _amountCupexTokensIn,
      amountOfLiquidityToMint,
      _transferTo
    );

    emit Sync(
      _tokenAddr,
      poolTokenBalanceBefore + _amountTokensIn,
      pool.cupexTokenBalance
    );

    return amountOfLiquidityToMint;
  }

  function removeLiquidity(
    IERC20 _tokenAddr,
    uint256 _amountOfLiquidityToRemove,
    uint256 _minAmountTokensOut,
    uint256 _minAmountCupexTokensOut,
    address _transferTo
  )
    public
    nonReentrant // re-entrancy protection
    returns (uint256, uint256)
  {
    uint256 poolId = tokenAddressToPoolId[_tokenAddr];

    // creating link to storage for further read/writes
    Pool storage pool = listOfPools[poolId];

    // getting balance of token in the pool
    uint256 poolTokenBalanceBefore = _getTokenBalanceInPoolBefore(_tokenAddr);

    uint256 totalSupplyOfLiquidity = totalSupply(poolId);
    uint256 amountTokensOut = (poolTokenBalanceBefore *
      _amountOfLiquidityToRemove) / totalSupplyOfLiquidity;
    uint256 amountCupexTokensOut = (pool.cupexTokenBalance *
      _amountOfLiquidityToRemove) / totalSupplyOfLiquidity;

    require(
      amountTokensOut >= _minAmountTokensOut,
      "AmountTokensOut is less than minimum"
    );
    require(
      amountCupexTokensOut >= _minAmountCupexTokensOut,
      "AmountCupexTokensOut is less than minimum"
    );

    // updating pool balance in storage
    pool.cupexTokenBalance -= amountCupexTokensOut;

    // burning ERC1155 token from user
    _burn(msg.sender, poolId, _amountOfLiquidityToRemove);

    // transferring tokens to user
    _safeTokenTransferToUser(_tokenAddr, _transferTo, amountTokensOut);

    // transferring CUPEX tokens to user
    cupexToken.transfer(_transferTo, amountCupexTokensOut);

    emit LiquidityRemoved(
      _tokenAddr,
      amountTokensOut,
      amountCupexTokensOut,
      _amountOfLiquidityToRemove,
      _transferTo
    );

    emit Sync(
      _tokenAddr,
      poolTokenBalanceBefore - amountTokensOut,
      pool.cupexTokenBalance
    );

    return (amountTokensOut, amountCupexTokensOut);
  }

  function swapExactTokensForTokens(
    IERC20 _tokenIn,
    IERC20 _tokenOut,
    uint256 _amountTokensIn,
    uint256 _minAmountTokensOut,
    address _transferTo
  )
    public
    payable
    nonReentrant // re-entrancy protection
    returns (uint256)
  {
    require(_tokenIn != _tokenOut, "Can't swap the same token to itself");

    uint256 reservesIn;
    uint256 reservesOut;
    uint256 amountTokensOut;

    // swap [CUPEX --> TokenOut]
    if (_tokenIn == cupexToken) {
      (reservesOut, reservesIn) = getPoolBalances(_tokenOut);

      amountTokensOut = _getOutput(reservesIn, reservesOut, _amountTokensIn);

      // checking slippage
      require(
        amountTokensOut >= _minAmountTokensOut,
        "Amount of tokens out is less than minimum required"
      );

      _swap(
        _tokenOut, // _tokenAddr
        reservesOut, // _tokenBalanceBefore
        0, // _amountTokensIn
        _amountTokensIn, // _amountCupexTokensIn
        amountTokensOut, // _amountTokensOut
        0 // _amountCupexTokensOut
      );

      // transferring CUPEX tokens from user to contract
      cupexToken.transferFrom(msg.sender, address(this), _amountTokensIn);

      // transferring tokens to user
      _safeTokenTransferToUser(_tokenOut, _transferTo, amountTokensOut);
      return amountTokensOut;
    }

    // swap [TokenIn --> CUPEX]
    uint256 amountCupexTokensOut;
    if (_tokenOut == cupexToken) {
      (reservesIn, reservesOut) = getPoolBalances(_tokenIn);

      amountCupexTokensOut = _getOutput(reservesIn, reservesOut, _amountTokensIn);

      // checking slippage
      require(
        amountCupexTokensOut >= _minAmountTokensOut,
        "Amount of tokens out is less than minimum required"
      );

      _swap(
        _tokenIn, // _tokenAddr
        reservesIn, // _tokenBalanceBefore
        _amountTokensIn, // _amountTokensIn
        0, // _amountCupexTokensIn
        0, // _amountTokensOut
        amountCupexTokensOut // _amountCupexTokensOut
      );

      // transferring tokens from user to contract
      _safeTokenTransferFromMsgSender(_tokenIn, _amountTokensIn);

      // transferring CUPEX tokens to user
      cupexToken.transfer(_transferTo, amountCupexTokensOut);
      return amountCupexTokensOut;
    }

    // if (_tokenIn != cupexToken && _tokenOut != cupexToken) clause
    // swap [TokenIn --> CUPEX --> TokenOut], TokenIn != TokenOut

    // getting amountCupexTokensOut from [TokenIn --> CUPEX] swap
    (reservesIn, reservesOut) = getPoolBalances(_tokenIn);
    amountCupexTokensOut = _getOutput(reservesIn, reservesOut, _amountTokensIn);

    // getting amountTokensOut from [CUPEX --> TokenOut] swap
    (reservesOut, reservesIn) = getPoolBalances(_tokenOut);
    amountTokensOut = _getOutput(reservesIn, reservesOut, amountCupexTokensOut);

    // checking slippage
    require(
      amountTokensOut >= _minAmountTokensOut,
      "Amount of tokens out is less than minimum required"
    );

    // swap [TokenIn --> CUPEX]
    _swap(
      _tokenIn, // _tokenAddr
      reservesIn, // _tokenBalanceBefore
      _amountTokensIn, // _amountTokensIn
      0, // _amountCupexTokensIn
      0, // _amountTokensOut
      amountCupexTokensOut // _amountCupexTokensOut
    );

    // swap [CUPEX --> TokenOut]
    _swap(
      _tokenOut, // _tokenAddr
      reservesOut, // _tokenBalanceBefore
      0, // _amountTokensIn
      amountCupexTokensOut, // _amountCupexTokensIn
      amountTokensOut, // _amountTokensOut
      0 // _amountCupexTokensOut
    );

    // transferring tokens from user to contract
    _safeTokenTransferFromMsgSender(_tokenIn, _amountTokensIn);

    // transferring tokens to user
    _safeTokenTransferToUser(_tokenOut, _transferTo, amountTokensOut);

    return amountTokensOut;
  }

  function swapTokensForExactTokens(
    IERC20 _tokenIn,
    IERC20 _tokenOut,
    uint256 _maxAmountTokensIn,
    uint256 _amountTokensOut,
    address _transferTo
  )
    public
    payable
    nonReentrant // re-entrancy protection
    returns (uint256)
  {
    require(_tokenIn != _tokenOut, "Can't swap the same token to itself");

    // making sure provided value is correct
    require(
      _tokenIn == NATIVE_TOKEN && _maxAmountTokensIn == msg.value,
      "Incorrect _maxAmountTokensIn for native token provided"
    );

    uint256 reservesIn;
    uint256 reservesOut;
    uint256 amountTokensIn;

    // swap [CUPEX --> TokenOut]
    uint256 amountCupexTokensIn = 0;
    if (_tokenIn == cupexToken) {
      (reservesOut, reservesIn) = getPoolBalances(_tokenOut);

      amountCupexTokensIn = _getInput(reservesIn, reservesOut, _amountTokensOut);

      // checking slippage
      require(
        amountCupexTokensIn <= _maxAmountTokensIn,
        "Amount of tokens in is larger than maximum required"
      );

      _swap(
        _tokenOut, // _tokenAddr
        reservesOut, // _tokenBalanceBefore
        0, // _amountTokensIn
        amountCupexTokensIn, // _amountCupexTokensIn
        _amountTokensOut, // _amountTokensOut
        0 // _amountCupexTokensOut
      );

      // transferring CUPEX tokens from user to contract
      cupexToken.transferFrom(msg.sender, address(this), amountCupexTokensIn);

      // transferring tokens to user
      _safeTokenTransferToUser(_tokenOut, _transferTo, _amountTokensOut);
      return amountCupexTokensIn;
    }

    // swap [TokenIn --> CUPEX]
    if (_tokenOut == cupexToken) {
      (reservesIn, reservesOut) = getPoolBalances(_tokenIn);

      amountTokensIn = _getInput(reservesIn, reservesOut, _amountTokensOut);

      // checking slippage
      require(
        amountTokensIn <= _maxAmountTokensIn,
        "Amount of tokens in is larger than maximum required"
      );

      _swap(
        _tokenIn, // _tokenAddr
        reservesIn, // _tokenBalanceBefore
        amountTokensIn, // _amountTokensIn
        0, // _amountCupexTokensIn
        0, // _amountTokensOut
        _amountTokensOut // _amountCupexTokensOut
      );

      // transferring tokens from user to contract
      _safeTokenTransferFromMsgSender(_tokenIn, amountTokensIn);

      // transferring CUPEX tokens to user
      cupexToken.transfer(_transferTo, _amountTokensOut);
      return amountTokensIn;
    }

    // if (_tokenIn != cupexToken && _tokenOut != cupexToken) clause
    // swap [TokenIn --> CUPEX --> TokenOut], TokenIn != TokenOut

    // getting amountCupexTokensIn from [CUPEX --> TokenOut] swap
    (reservesOut, reservesIn) = getPoolBalances(_tokenOut);
    amountCupexTokensIn = _getInput(reservesIn, reservesOut, _amountTokensOut);

    // getting amountTokensIn from [TokenIn --> CUPEX] swap
    (reservesIn, reservesOut) = getPoolBalances(_tokenIn);
    amountTokensIn = _getInput(reservesIn, reservesOut, amountCupexTokensIn);

    // checking slippage
    require(
      amountTokensIn <= _maxAmountTokensIn,
      "Amount of tokens in is larger than maximum required"
    );

    // swap [TokenIn --> CUPEX]
    _swap(
      _tokenIn, // _tokenAddr
      reservesIn, // _tokenBalanceBefore
      amountTokensIn, // _amountTokensIn
      0, // _amountCupexTokensIn
      0, // _amountTokensOut
      amountCupexTokensIn // _amountCupexTokensOut
    );

    // swap [CUPEX --> TokenOut]
    _swap(
      _tokenOut, // _tokenAddr
      reservesOut, // _tokenBalanceBefore
      0, // _amountTokensIn
      amountCupexTokensIn, // _amountCupexTokensIn
      _amountTokensOut, // _amountTokensOut
      0 // _amountCupexTokensOut
    );

    // transferring tokens from user to contract
    _safeTokenTransferFromMsgSender(_tokenIn, amountTokensIn);

    // transferring tokens to user
    _safeTokenTransferToUser(_tokenOut, _transferTo, _amountTokensOut);

    return amountTokensIn;
  }

  // core swap function
  // to swap [Token --> CUPEX] or [CUPEX --> Token]
  function _swap(
    IERC20 _tokenAddr,
    uint256 _tokenBalanceBefore,
    uint256 _amountTokensIn,
    uint256 _amountCupexTokensIn,
    uint256 _amountTokensOut,
    uint256 _amountCupexTokensOut
  ) private {
    uint256 poolId = tokenAddressToPoolId[_tokenAddr];
    Pool storage pool = listOfPools[poolId];

    // calculating K value before the swap
    uint256 kValueBefore = _tokenBalanceBefore * pool.cupexTokenBalance;

    // calculating token balances after the swap
    uint256 tokenBalanceAfter = _tokenBalanceBefore +
      _amountTokensIn -
      _amountTokensOut;
    uint256 cupexTokenBalanceAfter = pool.cupexTokenBalance +
      _amountCupexTokensIn -
      _amountCupexTokensOut;

    // calculating new K value after the swap including trade fees
    // refer to 3.2.1 Adjustment for fee https://uniswap.org/whitepaper.pdf
    uint256 kValueAfter = (tokenBalanceAfter -
      (_amountTokensIn * TRADE_FEE_NOMINATOR) /
      TRADE_FEE_DENOMINATOR) *
      (cupexTokenBalanceAfter -
        (_amountCupexTokensIn * TRADE_FEE_NOMINATOR) /
        TRADE_FEE_DENOMINATOR);

    require(
      kValueAfter >= kValueBefore,
      "K value must increase or remain unchanged during any swap"
    );

    // update pool values
    pool.cupexTokenBalance = cupexTokenBalanceAfter;

    emit Swap(
      _tokenAddr,
      _amountTokensIn,
      _amountCupexTokensIn,
      _amountTokensOut,
      _amountCupexTokensOut
    );

    emit Sync(_tokenAddr, tokenBalanceAfter, cupexTokenBalanceAfter);
  }

  function _safeTokenTransferFromMsgSender(
    IERC20 _tokenAddr,
    uint256 _tokenAmount
  ) private {
    // we use NATIVE_TOKEN for native tokens
    // if address != null that means this is ERC20 token
    // if address == null that means this is native token (for example ETH)
    // for non-native tokens we have to get
    // exact amount of contract balance increase
    // after calling ERC20.transferFrom function
    if (_tokenAddr != NATIVE_TOKEN) {
      // non native tokens requires checking for fee-on-transfer
      uint256 tokenBalanceBefore = _tokenAddr.balanceOf(address(this));
      _tokenAddr.transferFrom(msg.sender, address(this), _tokenAmount);
      uint256 tokenBalanceAfter = _tokenAddr.balanceOf(address(this));

      // we revert if user sent us less tokens than needed after calling ERC20.transferFrom
      uint256 realTransferredAmount = tokenBalanceAfter - tokenBalanceBefore;
      require(
        realTransferredAmount == _tokenAmount,
        "Fee on transfer tokens aren't supported"
      );

      // if user sent native tokens we revert here
      require(msg.value == 0, "User mustn't send native tokens here");
      return;
    }

    // native token
    // don't need to do anything
    // because native tokens already transferred to contract
    // just need to make sure that amount tokens covers the transfer
    // the rest is refunded back to caller
    require(
      _tokenAmount <= msg.value,
      "User must provide correct amount of native tokens"
    );

    // refunding left dust
    // which is important for swapTokensForExactTokens function
    // where we specify msg.value > _tokenAmount
    // it is actually slippage check
    if (_tokenAmount < msg.value) {
      payable(msg.sender).transfer(msg.value - _tokenAmount);
    }
  }

  function _safeTokenTransferToUser(
    IERC20 _tokenAddr,
    address _transferTo,
    uint256 _tokenAmount
  ) private {
    // we use NATIVE_TOKEN for native tokens
    // if address != null that means this is ERC20 token
    // if address == null that means this is native token (for example ETH)
    if (_tokenAddr != NATIVE_TOKEN) {
      _tokenAddr.transfer(_transferTo, _tokenAmount);
      return;
    }

    // native token transfer
    payable(_transferTo).transfer(_tokenAmount);
  }

  function _getTokenBalanceInPoolBefore(IERC20 _tokenAddr)
    private
    view
    returns (uint256)
  {
    require(
      tokenAddressToPoolId[_tokenAddr] > 0,
      "Pool with this token must exist"
    );

    uint256 tokenBalanceBefore = 0;
    if (_tokenAddr == NATIVE_TOKEN) {
      // user already transferred native tokens to the contract
      // to know balance before the transfer we have to substract it
      tokenBalanceBefore = address(this).balance - msg.value;
      return tokenBalanceBefore;
    }

    // for ERC20 tokens
    tokenBalanceBefore = _tokenAddr.balanceOf(address(this));
    return tokenBalanceBefore;
  }

  function getListOfActiveTokens() public view returns (IERC20[] memory) {
    IERC20[] memory listOfTokens = new IERC20[](listOfPools.length + 1);

    // adding native token
    listOfTokens[0] = IERC20(NATIVE_TOKEN);

    // adding core token
    listOfTokens[1] = IERC20(cupexToken);

    for (uint256 i; i < listOfPools.length; i++) {
        Pool storage pool = listOfPools[i];
        if (pool.cupexTokenBalance == 0) {
            continue;
        }

        // adding all tokens in pools with positive liquidity
        listOfTokens[i + 2] = pool.tokenInPool;
    }

    return listOfTokens;
  }

  function getPoolBalances(IERC20 _tokenAddr)
    public
    view
    returns (uint256, uint256)
  {
    uint256 poolId = tokenAddressToPoolId[_tokenAddr];
    uint256 cupexTokenBalanceBefore = listOfPools[poolId].cupexTokenBalance;

    uint256 tokenBalanceBefore = _getTokenBalanceInPoolBefore(_tokenAddr);
    return (tokenBalanceBefore, cupexTokenBalanceBefore);
  }

  function getPoolBalances(uint256 _poolId)
    public
    view
    returns (uint256, uint256)
  {
    uint256 cupexTokenBalanceBefore = listOfPools[_poolId].cupexTokenBalance;

    uint256 tokenBalanceBefore = _getTokenBalanceInPoolBefore(
      listOfPools[_poolId].tokenInPool
    );
    return (tokenBalanceBefore, cupexTokenBalanceBefore);
  }

  function getExactTokensForTokens(
    IERC20 _tokenIn,
    IERC20 _tokenOut,
    uint256 _amountIn
  ) public view returns (uint256) {
    require(_tokenIn != _tokenOut, "Can't swap the same token to itself");

    uint256 reservesOut;
    uint256 reservesIn;

    // swap [CUPEX --> TokenOut]
    if (_tokenIn == cupexToken) {
      (reservesOut, reservesIn) = getPoolBalances(_tokenOut);

      return _getOutput(reservesIn, reservesOut, _amountIn);
    }

    // swap [TokenIn --> CUPEX]
    if (_tokenOut == cupexToken) {
      (reservesIn, reservesOut) = getPoolBalances(_tokenIn);

      return _getOutput(reservesIn, reservesOut, _amountIn);
    }

    // _tokenIn != cupexToken && _tokenOut != cupexToken
    // swap [TokenIn --> CUPEX --> TokenOut], TokenIn != TokenOut
    (reservesIn, reservesOut) = getPoolBalances(_tokenIn);

    // calculating amount of cupex tokens out from tokenIn pool
    // which will be transferred to tokenOut pool
    _amountIn = _getOutput(reservesIn, reservesOut, _amountIn);

    (reservesOut, reservesIn) = getPoolBalances(_tokenOut);
    return _getOutput(reservesIn, reservesOut, _amountIn);
  }

  function getTokensForExactTokens(
    IERC20 _tokenIn,
    IERC20 _tokenOut,
    uint256 _amountOut
  ) public view returns (uint256) {
    require(_tokenIn != _tokenOut, "Can't swap the same token to itself");

    uint256 reservesOut;
    uint256 reservesIn;

    // swap [CUPEX --> Token]
    if (_tokenIn == cupexToken) {
      (reservesOut, reservesIn) = getPoolBalances(_tokenOut);

      return _getInput(reservesIn, reservesOut, _amountOut);
    }

    // swap [Token --> CUPEX]
    if (_tokenOut == cupexToken) {
      (reservesIn, reservesOut) = getPoolBalances(_tokenIn);

      return _getInput(reservesIn, reservesOut, _amountOut);
    }

    // _tokenIn != cupexToken && _tokenOut != cupexToken
    // swap [Token1 --> CUPEX --> Token2], Token1 != Token2
    (reservesOut, reservesIn) = getPoolBalances(_tokenOut);

    // calculating amount of cupex tokens in to tokenOut pool
    // based on that calculating amount of tokens in to tokenIn pool
    _amountOut = _getInput(reservesIn, reservesOut, _amountOut);

    (reservesIn, reservesOut) = getPoolBalances(_tokenIn);

    return _getInput(reservesIn, reservesOut, _amountOut);
  }

  function _getOutput(
    uint256 _reservesIn,
    uint256 _reservesOut,
    uint256 _amountIn
  ) private pure returns (uint256) {
    // refer to https://github.com/Uniswap/v2-periphery/blob/2efa12e0f2d808d9b49737927f0e416fafa5af68/contracts/libraries/UniswapV2Library.sol#L43-L50
    uint256 amountInWithFee = _amountIn * TRADE_FEE_DENOMINATOR_MINUS_NOMINATOR;

    return
      (amountInWithFee * _reservesOut) /
      (_reservesIn * TRADE_FEE_DENOMINATOR + amountInWithFee);
  }

  function _getInput(
    uint256 _reservesIn,
    uint256 _reservesOut,
    uint256 _amountOut
  ) private pure returns (uint256) {
    // refer to https://github.com/Uniswap/v2-periphery/blob/2efa12e0f2d808d9b49737927f0e416fafa5af68/contracts/libraries/UniswapV2Library.sol#L53-L59
    return
      (_reservesIn * _amountOut * TRADE_FEE_DENOMINATOR) /
      (TRADE_FEE_DENOMINATOR_MINUS_NOMINATOR * (_reservesOut - _amountOut)) +
      1; // adding +1 for any rounding trims
  }

  function _min(uint256 x1, uint256 x2) private pure returns (uint256) {
    if (x1 < x2) return x1;

    return x2;
  }

  function _sqrt(uint256 _y) private pure returns (uint256 z) {
    if (_y > 3) {
      z = _y;
      uint256 x = _y / 2 + 1;
      while (x < z) {
        z = x;
        x = (_y / x + x) / 2;
      }
    } else if (_y != 0) {
      z = 1;
    }
  }

  /* ///////////////////////////////////// */
  /* Tests Block Starting (can be removed) */
  /* ///////////////////////////////////// */

  function test1_CreateTokensAndPools() public {
    IAnyErc20Token testTokenIn = IAnyErc20Token(
      address(new AnyErc20Token("TokenIn", "USDC"))
    );
    IAnyErc20Token testTokenOut = IAnyErc20Token(
      address(new AnyErc20Token("TokenOut", "DAI"))
    );
    cupexToken = IAnyErc20Token(address(new AnyErc20Token("CUPEX", "CUPEX")));

    testTokenIn.mint(msg.sender, 1e12 * 1e18);
    testTokenOut.mint(msg.sender, 1e12 * 1e18);
    IAnyErc20Token(address(cupexToken)).mint(msg.sender, 1e12 * 1e18);

    createPool(testTokenIn);
    createPool(testTokenOut);
    createPool(NATIVE_TOKEN);

    addLiquidity(testTokenIn, 1e6 * 1e18, 1e9 * 1e18, 0, 0, msg.sender);
    addLiquidity(testTokenOut, 1e9 * 1e18, 1e9 * 1e18, 0, 0, msg.sender);
  }

  // we must provide 1 finney of native tokens
  function test2_CreateNativeTokenAndPool() public payable {
    addLiquidity(NATIVE_TOKEN, 1 * 1e15, 1e9, 0, 0, msg.sender);
  }

  // Simplyfing the contract, below tests are passed but omitted from this version
  // function test3_AddLiquidity_RemoveLiqudity() public {
  //   (uint256 reservesTokenIn, uint256 reservesCupexTokenOut) = getPoolBalances(
  //     testTokenIn
  //   );

  //   uint256 initialAmountOfTokenIn = 1e3 * 1e18;
  //   uint256 initialAmountOfCupexToken = (initialAmountOfTokenIn *
  //     reservesCupexTokenOut) / reservesTokenIn;

  //   uint256 amountOfLiquidity = addLiquidity(
  //     testTokenIn,
  //     initialAmountOfTokenIn,
  //     initialAmountOfCupexToken,
  //     0,
  //     0,
  //     msg.sender
  //   );

  //   (uint256 amountOfTokensOut, uint256 amountOfCupexTokensOut) = removeLiquidity(
  //     testTokenIn,
  //     amountOfLiquidity,
  //     0,
  //     0,
  //     msg.sender
  //   );

  //   require(
  //     amountOfTokensOut < initialAmountOfTokenIn,
  //     "amountOfTokensOut <= initialAmountOfTokenIn"
  //   );
  //   require(
  //     amountOfCupexTokensOut < initialAmountOfCupexToken,
  //     "amountOfCupexTokensOut <= initialAmountOfCupexToken"
  //   );
  // }

  // function test4_AddLiquidity_SwapAndBack_RemoveLiqudity() public {
  //   (uint256 reservesTokenIn, uint256 reservesCupexTokenOut) = getPoolBalances(
  //     testTokenIn
  //   );

  //   uint256 initialAmountOfTokens = 1e3 * 1e18;

  //   uint256 addLiquidityTokens = (initialAmountOfTokens * 2) / 3;
  //   uint256 addLiquidityCupex = (addLiquidityTokens * reservesCupexTokenOut) /
  //     reservesTokenIn;

  //   uint256 amountOfLiquidity = addLiquidity(
  //     testTokenIn,
  //     addLiquidityTokens,
  //     addLiquidityCupex,
  //     0,
  //     0,
  //     msg.sender
  //   );

  //   uint256 swapTokensAmount = initialAmountOfTokens / 3;
  //   uint256 receivedCupexTokens = swapExactTokensForTokens(
  //     testTokenIn,
  //     cupexToken,
  //     swapTokensAmount,
  //     0,
  //     msg.sender
  //   );
  //   uint256 receivedTokens = swapExactTokensForTokens(
  //     cupexToken,
  //     testTokenIn,
  //     receivedCupexTokens,
  //     0,
  //     msg.sender
  //   );

  //   require(
  //     receivedTokens < swapTokensAmount,
  //     "receivedTokens < swapTokensAmount"
  //   );

  //   (uint256 amountOfTokensOut, uint256 amountOfCupexTokensOut) = removeLiquidity(
  //     testTokenIn,
  //     amountOfLiquidity,
  //     0,
  //     0,
  //     msg.sender
  //   );

  //   require(
  //     receivedTokens + amountOfTokensOut < initialAmountOfTokens,
  //     "receivedTokens + amountOfTokensOut < initialAmountOfTokens"
  //   );
  //   require(
  //     amountOfCupexTokensOut < addLiquidityCupex,
  //     "amountOfCupexTokensOut < addLiquidityCupex"
  //   );
  // }

  // function test5_SwapInToOutAndBack() public {
  //   uint256 initialTokensIn = 1e18;
  //   uint256 receivedTokensOut = swapExactTokensForTokens(
  //     testTokenIn,
  //     testTokenOut,
  //     initialTokensIn,
  //     0,
  //     msg.sender
  //   );
  //   uint256 receivedTokensIn = swapExactTokensForTokens(
  //     testTokenOut,
  //     testTokenIn,
  //     receivedTokensOut,
  //     0,
  //     msg.sender
  //   );

  //   require(
  //     receivedTokensIn < initialTokensIn,
  //     "receivedTokensIn < initialTokensIn"
  //   );
  // }

  // function testGetTokenInAndTokenOut()
  //   public
  //   view
  //   returns (
  //     IAnyErc20Token,
  //     IAnyErc20Token,
  //     IERC20
  //   )
  // {
  //   return (testTokenIn, testTokenOut, cupexToken);
  // }
  /* Tests Block Ending (can be removed) */
}
