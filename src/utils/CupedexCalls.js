import { ethers, Contract } from "ethers";
import {
  CUPEDEX_ADDRESS,
  CUPEX_STAKING_ADDRESS,
  CUPEX_TOKEN_ADDRESS,
  USDC_TOKEN_ADDRESS,
  DAI_TOKEN_ADDRESS,
  NATIVE_TOKEN_ADDRESS,
  RPC_ENDPOINT,
} from "../constants";
import DEX_ABI from "../constants/CupexDEX_ABI.json";
import TEST_ABI from "../constants/test.json";
import ERC20_ABI from "../constants/Erc20_abi.json";
import STAKE_ABI from "../constants/CupexStaking_abi.json";

/**
 * getEtherBalance: Retrieves the ether balance of the user or the contract
 */
export const getEtherBalance = async (provider, address, contract = false) => {
  try {
    // If the caller has set the `contract` boolean to true, retrieve the balance of
    // ether in the `exchange contract`, if it is set to false, retrieve the balance
    // of the user's address
    if (contract) {
      const balance = await provider.getBalance(CUPEDEX_ADDRESS);
      return balance;
    } else {
      const balance = await provider.getBalance(address);
      return balance;
    }
  } catch (err) {
    console.error(err);
    return 0;
  }
};

/**
 * getCDTokensBalance: Retrieves the Crypto Dev tokens in the account
 * of the provided `address`
 */
export const getCustomTokensBalance = async (
  provider,
  address,
  selectedToken
) => {
  try {
    if (selectedToken == NATIVE_TOKEN_ADDRESS) {
      return await getEtherBalance(provider, address);
    }
    const tokenContract = new Contract(selectedToken, ERC20_ABI, provider);
    console.log(await tokenContract.symbol());
    const balanceOfCryptoDevTokens = await tokenContract.balanceOf(address);
    return balanceOfCryptoDevTokens;
  } catch (err) {
    console.error(err);
  }
};

export const dexGetExactTokensForTokens = async (
  signer,
  amountToSwap,
  firstTokenToSwapAddress,
  SecondTokenToSwapAddress
) => {
  try {
    let swapContract = new ethers.Contract(CUPEDEX_ADDRESS, DEX_ABI, signer);
    const tx = await swapContract.getExactTokensForTokens(
      firstTokenToSwapAddress,
      SecondTokenToSwapAddress,
      ethers.utils.parseUnits(amountToSwap, 18)
    );
    console.log(ethers.utils.formatEther(tx));
    return ethers.utils.formatEther(tx);
  } catch (err) {
    console.log(
      `Got error during fetching token price for amount ${amountToSwap}\n${err}`
    );
    return 0.0;
  }
};

export const dexSwapExactTokensForTokens = async (
  provider,
  signer,
  amountToSwap,
  amountAfterSwap,
  firstTokenToSwapAddress,
  SecondTokenToSwapAddress,
  transferTo
) => {
  try {
    let swapContract = new ethers.Contract(CUPEDEX_ADDRESS, DEX_ABI, signer);
    let estimateGas = await swapContract.estimateGas.swapExactTokensForTokens(
      firstTokenToSwapAddress,
      SecondTokenToSwapAddress,
      ethers.utils.parseUnits(amountToSwap.toString(), 18),
      ethers.utils.parseUnits(amountAfterSwap.toString(), 18),
      transferTo
    );
    console.log(estimateGas.toNumber());
    const tx = await swapContract.swapExactTokensForTokens(
      firstTokenToSwapAddress,
      SecondTokenToSwapAddress,
      ethers.utils.parseUnits(amountToSwap, 18),
      ethers.utils.parseUnits(amountAfterSwap, 18),
      transferTo
    );
    console.log(tx);
    let receipt = await tx.wait();
    console.log(receipt);
    return tx;
  } catch (err) {
    console.log(
      `Got error during swap for amount ${amountToSwap}\n${err.toString()}`
    );
    console.log(JSON.stringify(err));
    return 0.0;
  }
};

//Stake functions

export const stakeInformation = async (provider, address, signer) => {
  try {
    const stakeContract = new Contract(
      CUPEX_STAKING_ADDRESS,
      STAKE_ABI,
      signer
    );
    const stakeInfo = await stakeContract.getStakeInformation();
    const walletToStake = await stakeContract.walletToStake(address);
    //return ethers.utils.formatEther(walletToStake[1]);
    return stakeInfo;
  } catch (err) {
    console.error(err);
  }
};

export const createStake = async (signer, amountToSwap) => {
  try {
    console.log(signer);
    let stakeContract = new ethers.Contract(
      CUPEX_STAKING_ADDRESS,
      STAKE_ABI,
      signer
    );
    const tx = await stakeContract.createStake(
      ethers.utils.parseUnits(amountToSwap, 18)
    );
    console.log(tx);
    let receipt = await tx.wait();
    console.log(receipt);
    return tx;
  } catch (err) {
    console.log(
      `Got error while trying to create stake for amount ${amountToSwap}\n${err}`
    );
    return 0.0;
  }
};

//Liquidity functions

export const getMyLiquidity = async (signer, token_addr) => {
  let swapContract = new ethers.Contract(CUPEDEX_ADDRESS, DEX_ABI, signer);

  let liquidityValues = [];

  const liquidityMyToken = await swapContract.getLiquidityByTokenAddr(
    token_addr
  );

  await liquidityValues.push(ethers.utils.formatEther(liquidityMyToken[0]));
  await liquidityValues.push(ethers.utils.formatEther(liquidityMyToken[1]));

  return liquidityValues;
};

export const removeLiquidity = async (
  signer,
  token_addr,
  amount,
  transferTo
) => {
  try {
    let dexContract = new ethers.Contract(CUPEDEX_ADDRESS, DEX_ABI, signer);

    let userLpBalance;
    if (token_addr == USDC_TOKEN_ADDRESS)
      userLpBalance = await dexContract.balanceOf(transferTo, 1);
    if (token_addr == DAI_TOKEN_ADDRESS)
      userLpBalance = await dexContract.balanceOf(transferTo, 2);
    if (token_addr == NATIVE_TOKEN_ADDRESS)
      userLpBalance = await dexContract.balanceOf(transferTo, 3);

    const tx = await dexContract.removeLiquidity(
      token_addr,
      userLpBalance,
      0,
      0,
      transferTo
    );

    console.log(tx);
    let receipt = await tx.wait();
    console.log(receipt);
    return tx;
  } catch (err) {
    console.log(`Got error in removing liquidity function`, err);
    return 0.0;
  }
};

export const dexAddLiquidity = async (
  provider,
  signer,
  amountToSwap,
  amountAfterSwap,
  firstTokenToSwapAddress,
  SecondTokenToSwapAddress,
  transferTo
) => {
  try {
    let minAmountToSwap = amountToSwap;
    let minAmountAfterSwap = amountAfterSwap;
    let swapContract = new ethers.Contract(CUPEDEX_ADDRESS, DEX_ABI, signer);

    const liquidityMyToken = await swapContract.getLiquidityByTokenAddr(
      SecondTokenToSwapAddress
    );
    const [reservesToken, reservesCupex] = await swapContract[
      "getPoolBalances(address)"
    ](SecondTokenToSwapAddress);
    console.log(amountToSwap, amountAfterSwap);
    console.log(liquidityMyToken, reservesToken, reservesCupex);
    const activeTokens = await swapContract.getListOfActiveTokens();
    console.log(activeTokens);
    for (
      let poolIndex = 1;
      poolIndex != activeTokens.length / 2 + 1;
      poolIndex++
    ) {
      console.log(
        poolIndex,
        await swapContract["listOfPools(uint256)"](poolIndex)
      );
    }

    const userLpBalance = await swapContract.balanceOf(transferTo, 1);
    let totalLpBalance;
    if (SecondTokenToSwapAddress == USDC_TOKEN_ADDRESS)
      totalLpBalance = await swapContract.totalSupply(1);
    if (SecondTokenToSwapAddress == DAI_TOKEN_ADDRESS)
      totalLpBalance = await swapContract.totalSupply(2);
    if (SecondTokenToSwapAddress == NATIVE_TOKEN_ADDRESS)
      totalLpBalance = await swapContract.totalSupply(3);
    console.log(userLpBalance, totalLpBalance);
    const userOwnsCupex = (reservesToken * userLpBalance) / totalLpBalance;
    const userOwnsTokens = (reservesCupex * userLpBalance) / totalLpBalance;
    console.log(userOwnsCupex, userOwnsTokens);

    const tx = await swapContract.addLiquidity(
      SecondTokenToSwapAddress,
      ethers.utils.parseUnits(amountAfterSwap, "ether"),
      ethers.utils.parseUnits(amountToSwap, "ether"),
      ethers.utils.parseUnits("0.0", "ether"),
      ethers.utils.parseUnits("0.0", "ether"),
      transferTo
    );
    console.log(tx);
    let receipt = await tx.wait();
    console.log(receipt);
    return tx;
  } catch (err) {
    console.log(
      `Got error trying to add liquidity with amount ${amountToSwap}\n${err.toString()}`
    );
    console.log(JSON.stringify(err));
    return 0.0;
  }
};
