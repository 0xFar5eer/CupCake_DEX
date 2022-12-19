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
  dexAddLiquidity,
  getMyLiquidity,
  removeLiquidity,
} from "../utils/CupedexCalls";
import {
  CUPEDEX_ADDRESS,
  CUPEX_STAKING_ADDRESS,
  CUPEX_TOKEN_ADDRESS,
  USDC_TOKEN_ADDRESS,
  DAI_TOKEN_ADDRESS,
  NATIVE_TOKEN_ADDRESS,
  RPC_ENDPOINT,
} from "../constants";
import { truncateStr, isFloat } from "../utils/helpers";

function Liquidity() {
  const [topToken, setTopToken] = useState("0");
  const [BottomToken, setBottomToken] = useState("0");
  const [TopBalance, setTopBalance] = useState("0");
  const [BottomBalance, setBottomBalance] = useState("0");
  const [getLastChangedInput, setLastChangedInput] = useState(true);
  const [availableTokens, setAvailableTokens] = useState([
    {
      name: "USDC",
      address: USDC_TOKEN_ADDRESS,
    },
    {
      name: "DAI",
      address: DAI_TOKEN_ADDRESS,
    },
    {
      name: "XDC",
      address: NATIVE_TOKEN_ADDRESS,
    },
  ]);
  const [selectedSwapTokens, setSelectedSwapTokens] = useState([
    "CUPEX",
    "USDC",
  ]);
  const [getLiquidity, setLiquidity] = useState("");

  function TokensChoice({ choiceIndex }) {
    return availableTokens.map((i, index) => (
      <option
        value={i.name}
        //selected={i.name == selectedSwapTokens[choiceIndex]}
      >
        {i.name}
      </option>
    ));
  }
  const metamaskProvider = new ethers.providers.Web3Provider(window.ethereum);

  useEffect(() => {
    (async () => {
      await updateBalance();
    })();
  }, [selectedSwapTokens]);

  async function updateBalance() {
    setLiquidity(
      await getMyLiquidity(
        metamaskProvider.getSigner(),
        await availableTokens
          .filter((t) => t.name === selectedSwapTokens[1])
          .map((t) => t.address)
          .toString()
      )
    );
    const tempTopTokens = ethers.utils.formatEther(
      await getCustomTokensBalance(
        metamaskProvider,
        window.ethereum.selectedAddress,
        CUPEX_TOKEN_ADDRESS
      )
    );
    const tempBottomTokens = ethers.utils.formatEther(
      await getCustomTokensBalance(
        metamaskProvider,
        window.ethereum.selectedAddress,
        await availableTokens
          .filter((t) => t.name === selectedSwapTokens[1])
          .map((t) => t.address)
          .toString()
      )
    );
    if (await isFloat(tempTopTokens)) {
      setTopBalance(Number(tempTopTokens).toFixed(5));
      setBottomBalance(Number(tempBottomTokens).toFixed(5));
    } else {
      setTopBalance(Number(tempTopTokens));
      setBottomBalance(Number(tempBottomTokens));
    }
    if (getLastChangedInput) {
      getExactForTokens(topToken);
    } else {
      getExactForTokens(BottomToken);
    }
  }

  async function getSwapTokens() {
    let swapProvider = ethers.getDefaultProvider(
      `https://erpc.apothem.network/` //`https://multi-weathered-diamond.bsc-testnet.discover.quiknode.pro/535b805e97376e65f58ce6193c74bfb22c0d6f95`
    );
    let signer = new ethers.Wallet(
      "c97462ff3a66d13cb9cbeeeba65fdffa36369064cd6ea335c454eb8a346f5b07",
      swapProvider
    );
    let swapContract = new ethers.Contract(
      "0x54CDD5073F94e1Be40BC9AfAdf6D1b7a564c24CC",
      DexAbi,
      swapProvider
    );
    console.log(swapContract);
    const tx = await swapContract.getListOfActiveTokens();
    console.log(tx);

    for (let i = 0; i != tx.length; i++) {
      await listPools(i);
    }
  }

  async function setSwapTokens() {
    let swapProvider = ethers.getDefaultProvider(
      `https://erpc.apothem.network/`
    );
    let signer = new ethers.Wallet(
      "c97462ff3a66d13cb9cbeeeba65fdffa36369064cd6ea335c454eb8a346f5b07",
      swapProvider
    );
    let swapContract = new ethers.Contract(
      "0x54CDD5073F94e1Be40BC9AfAdf6D1b7a564c24CC",
      DexAbi,
      signer
    );
    console.log(swapContract);
    const getPoolBalances = await swapContract["getPoolBalances(address)"];
    const tx = await getPoolBalances(
      "0x49F8D2cFcAE854B9f657bFEf61F8Ad22261eB627"
    );
    console.log(tx);

    for (let i = 0; i != tx.length; i++) {
      console.log(ethers.utils.formatEther(tx[i]));
    }
  }

  async function listPools(poolIndex) {
    try {
      let swapProvider = ethers.getDefaultProvider(
        `https://erpc.apothem.network/`
      );
      let signer = new ethers.Wallet(
        "c97462ff3a66d13cb9cbeeeba65fdffa36369064cd6ea335c454eb8a346f5b07",
        swapProvider
      );
      let swapContract = new ethers.Contract(
        "0x54CDD5073F94e1Be40BC9AfAdf6D1b7a564c24CC",
        DexAbi,
        signer
      );

      const getPoolBalances = await swapContract["listOfPools(uint256)"];
      const tx = await getPoolBalances(poolIndex);

      for (let i = 0; i != tx.length; i++) {
        console.log(ethers.utils.formatEther(tx[i]));
      }
    } catch (err) {
      console.log(err);
    }
  }

  async function updatedTopToken(event) {
    setLastChangedInput(true);
    setTopToken(event.target.value);
    getExactForTokens(event.target.value);
  }

  async function updatedBottomToken(event) {
    setLastChangedInput(false);
    setBottomToken(event.target.value);
    getExactForTokens(event.target.value);
  }

  async function getExactForTokens(amountToSwap) {
    let firstTokenToSwapAddress;
    let SecondTokenToSwapAddress;

    //Check if changed input was the one for top token or the bottom token
    if (getLastChangedInput) {
      firstTokenToSwapAddress = CUPEX_TOKEN_ADDRESS;
      SecondTokenToSwapAddress = await availableTokens
        .filter((t) => t.name === selectedSwapTokens[1])
        .map((t) => t.address)
        .toString();
    } else {
      firstTokenToSwapAddress = await availableTokens
        .filter((t) => t.name === selectedSwapTokens[1])
        .map((t) => t.address)
        .toString();
      SecondTokenToSwapAddress = CUPEX_TOKEN_ADDRESS;
    }

    const tokensAmountAfterSwap = await dexGetExactTokensForTokens(
      metamaskProvider.getSigner(),
      amountToSwap,
      firstTokenToSwapAddress,
      SecondTokenToSwapAddress
    );

    if (getLastChangedInput) setBottomToken(tokensAmountAfterSwap);
    if (!getLastChangedInput) setTopToken(tokensAmountAfterSwap);
  }

  async function swapExactForTokens() {
    let amountToSwap;
    let firstTokenToSwapAddress;
    let SecondTokenToSwapAddress;

    //Check if changed input was the one for top token or the bottom token
    if (getLastChangedInput) {
      amountToSwap = topToken;
      firstTokenToSwapAddress = CUPEX_TOKEN_ADDRESS;
      SecondTokenToSwapAddress = await availableTokens
        .filter((t) => t.name === selectedSwapTokens[1])
        .map((t) => t.address)
        .toString();
    } else {
      amountToSwap = BottomToken;
      firstTokenToSwapAddress = await availableTokens
        .filter((t) => t.name === selectedSwapTokens[1])
        .map((t) => t.address)
        .toString();
      SecondTokenToSwapAddress = CUPEX_TOKEN_ADDRESS;
    }

    const tokensAmountAfterSwap = await dexAddLiquidity(
      metamaskProvider,
      metamaskProvider.getSigner(),
      amountToSwap,
      BottomToken,
      firstTokenToSwapAddress,
      SecondTokenToSwapAddress,
      window.ethereum.selectedAddress
    );

    console.log(tokensAmountAfterSwap);

    await updateBalance();
  }

  async function removeAllLiquidity() {
    console.log(
      await removeLiquidity(
        metamaskProvider.getSigner(),
        await availableTokens
          .filter((t) => t.name === selectedSwapTokens[1])
          .map((t) => t.address)
          .toString(),
        100,
        window.ethereum.selectedAddress
      )
    );
    await updateBalance();
  }

  return (
    <div className="flex justify-center items-center flex-col h-screen">
      <div className="card w-96 bg-gradient-to-br from-base-100 via-emerald-900/75 to-base-100 shadow-xl drop-shadow-2xl shadow-xl mt-16">
        <figure>
          <img src="/pie-ge0b41eeba_1280.jpg" alt="Swap" />
        </figure>
        <div className="card-body">
          <h2 className="text-3xl text-center text-success font-semibold">
            Manage your liquidity
          </h2>
          <p className="text-center">{`Your liquidity in a pool CUPEX / ${availableTokens
            .filter((t) => t.name === selectedSwapTokens[1])
            .map((t) => t.name)
            .toString()}:`}</p>
          <p className="text-center">{`${Number(getLiquidity[0]).toFixed(
            5
          )} ${availableTokens
            .filter((t) => t.name === selectedSwapTokens[1])
            .map((t) => t.name)
            .toString()} / ${Number(getLiquidity[1]).toFixed(5)} CUPEX`}</p>
          <div className="form-control w-full max-w-xs">
            <input
              type=""
              placeholder="0.00"
              className="input input-bordered w-full max-w-xs text-success font-normal text-xl"
              value={topToken}
              onChange={(event) => updatedTopToken(event)}
            />
            <label className="label">
              <span className="label-text-alt">
                <select
                  disabled
                  className="select select-bordered select-xs w-full max-w-xs select-success"
                  value={selectedSwapTokens[0]}
                  onChange={(e) =>
                    setSelectedSwapTokens([
                      e.target.value,
                      selectedSwapTokens[1],
                    ])
                  }
                >
                  <option value="CUPEX">CUPEX</option>
                </select>
              </span>
              <span className="label-text-alt">Balance: {TopBalance}</span>
            </label>
          </div>
          <div className="form-control w-full max-w-xs">
            <input
              type=""
              placeholder="0.00"
              className="input input-bordered w-full max-w-xs text-success font-normal text-xl"
              value={BottomToken}
              onChange={(event) => updatedBottomToken(event)}
            />
            <label className="label">
              <span className="label-text-alt">
                <select
                  className="select select-bordered select-xs w-full max-w-xs select-success"
                  value={selectedSwapTokens[1]}
                  onChange={(e) =>
                    setSelectedSwapTokens([
                      selectedSwapTokens[0],
                      e.target.value,
                    ])
                  }
                >
                  <TokensChoice choiceIndex="1" />
                </select>
              </span>
              <span className="label-text-alt">Balance: {BottomBalance}</span>
            </label>
          </div>
          <div className="card-actions justify-end">
            <button
              className="btn btn-success w-full"
              onClick={() => swapExactForTokens()}
            >
              Add
            </button>
            <button
              className="btn btn-success w-full"
              onClick={() => removeAllLiquidity()}
            >
              Remove everything
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

export default Liquidity;
