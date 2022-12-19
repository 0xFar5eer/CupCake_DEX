import { useState, useEffect } from "react";
import { useDebounce } from "use-debounce";
import {
  configureChains,
  createClient,
  WagmiConfig,
  useAccount,
  useSigner,
  useContract,
  useContractRead,
  useContractWrite,
  usePrepareContractWrite,
  usePrepareSendTransaction,
  useSendTransaction,
  useWaitForTransaction,
} from "wagmi";
import { signMessage } from "@wagmi/core";
import { ethers, BigNumber, FixedNumber } from "ethers";
import Web3 from "web3";
import DexAbi from "../constants/CupexDEX_ABI.json";
import TestAbi from "../constants/test.json";
import {
  getEtherBalance,
  getCustomTokensBalance,
  dexGetExactTokensForTokens,
  dexSwapExactTokensForTokens,
  stakeInformation,
  createStake,
} from "../utils/CupedexCalls";
import {
  CUPEDEX_ADDRESS,
  CUPEX_STAKING_ADDRESS,
  CUPEX_TOKEN_ADDRESS,
  USDC_TOKEN_ADDRESS,
  DAI_TOKEN_ADDRESS,
  NATIVE_TOKEN_ADDRESS,
} from "../constants";

function Stake() {
  const [topToken, setTopToken] = useState("0");
  const [BottomToken, setBottomToken] = useState("0");
  const [TopBalance, setTopBalance] = useState("0");
  const [BottomBalance, setBottomBalance] = useState("0");
  const [getLastChangedInput, setLastChangedInput] = useState(true);
  const metamaskProvider = new ethers.providers.Web3Provider(window.ethereum);
  useEffect(() => {
    (async () => {
      await updateBalance();
    })();
  }, []);

  async function updatedTopToken(event) {
    setLastChangedInput(true);
    setTopToken(event.target.value);
  }

  async function updatedBottomToken(event) {
    setLastChangedInput(false);
    setBottomToken(event.target.value);
  }

  async function updateBalance() {
    const myStakeInformation = await stakeInformation(
      metamaskProvider,
      (
        await metamaskProvider.listAccounts()
      )[0],
      metamaskProvider.getSigner()
    );
    setTopBalance(ethers.utils.formatEther(myStakeInformation[1]));
    setBottomToken(ethers.utils.formatEther(myStakeInformation[2]));

    setBottomBalance(
      ethers.utils.formatEther(
        await getCustomTokensBalance(
          metamaskProvider,
          window.ethereum.selectedAddress,
          CUPEX_TOKEN_ADDRESS
        )
      )
    );
  }

  async function stakeCupex() {
    console.log(await createStake(metamaskProvider.getSigner(), topToken));
    await updateBalance();
  }

  return (
    <div className="flex justify-center items-center flex-col h-screen">
      <div className="indicator">
        <span className="indicator-item indicator-top indicator-end badge bg-green-300 border-green-300 text-gray-700 shadow-xl shadow-green-300/10 mt-16">
          +10% each day
        </span>
        <div className="card w-96 bg-gradient-to-br from-base-300 via-base-200 to-zinc-900 shadow-xl drop-shadow-2xl shadow-xl mt-10">
          <figure>
            <img src="/pie-ge0b41eeba_1280.jpg" alt="cupcake" />
          </figure>
          <div className="card-body">
            <h2 className="text-3xl text-center text-success font-semibold mb-4">
              Stake your CUPEX
            </h2>
            <div className="stats shadow stats-vertical shadow">
              <div className="stat">
                <div className="stat-figure text-secondary">
                  <button
                    className="btn btn-success w-full"
                    onClick={() => stakeCupex()}
                  >
                    Unstake
                  </button>
                </div>
                <div className="stat-title">Stake </div>
                <div className="stat-value">{TopBalance}</div>
                <div className="stat-desc">
                  Interest: {Number(BottomToken).toFixed(5)}
                </div>
              </div>
            </div>
            <span className=" text-success">
              Wallet CUPEX Balance: {Number(BottomBalance).toFixed(5)}
            </span>
            <div className="form-control w-full max-w-xs">
              <input
                type=""
                placeholder="0.00"
                className="input input-bordered w-full max-w-xs text-success font-normal text-xl"
                value={topToken}
                onChange={(event) => updatedTopToken(event)}
              />
            </div>
            <div className="card-actions justify-end">
              <button
                className="btn btn-success w-full"
                onClick={() => stakeCupex()}
              >
                Stake
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

export default Stake;
