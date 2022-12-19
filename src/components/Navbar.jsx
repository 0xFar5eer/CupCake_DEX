import { useState, useContext, useCallback, useEffect } from "react";
import {
  createBrowserRouter,
  RouterProvider,
  Route,
  Link,
  Routes,
} from "react-router-dom";
import { Web3Modal, Web3Button } from "@web3modal/react";
import Swap from "../pages/Swap";
import Stake from "../pages/Stake";
import Liquidity from "../pages/Liquidity";
import { Web3ModalContext } from "../contexts/Web3ModalProvider";
import { truncateStr, isFloat } from "../utils/helpers";
import { useCurrentPath } from "../hooks/useCurrentPath";

const Navbar = () => {
  const { account, connect, disconnect, chainId, web3 } =
    useContext(Web3ModalContext);
  const currentPath = useCurrentPath();

  const handleConnectWallet = useCallback(() => {
    connect();
  }, [connect]);

  const handleDisconnectWallet = useCallback(() => {
    disconnect();
  }, [disconnect]);

  useEffect(() => {
    (async () => {
      console.log(currentPath);
    })();
  }, []);

  return (
    <div className="overflow-hidden bg-gradient-to-br from-base-300 via-base-200 to-zinc-900">
      <div className="navbar bg-base-200/80 absolute drop-shadow-lg backdrop-blur-xl overflow-hidden">
        <div className="flex-1">
          <img
            src="/pie-ge0b41eeba_1280_no_bg.png"
            alt="dex_logo"
            className="w-16"
          />
          <a className="btn btn-ghost normal-case text-xl">CUPCAKE DEX</a>
        </div>
        <div className="flex-none">
          <ul className="menu menu-horizontal p-1 bg-base rounded-box mx-5">
            <li className="flex flex-col">
              <Link
                className={`rounded-lg hover:text-gray-700 hover:text-green-300/80 mx-2 active:bg-base-100 ${
                  currentPath == "/" || currentPath == "/swap"
                    ? "text-green-300 overline"
                    : ""
                }`}
                to="/swap"
              >
                Swap
              </Link>
            </li>
            <li>
              <Link
                className={`rounded-lg hover:text-gray-700 hover:text-green-300/80 mx-2 active:bg-base-100 ${
                  currentPath == "/stake" ? "text-green-300 overline" : ""
                }`}
                to="/stake"
              >
                Stake
              </Link>
            </li>
            <li>
              <Link
                className={`rounded-lg hover:text-gray-700 hover:text-green-300/80 mx-2 active:bg-base-100 ${
                  currentPath == "/liquidity" ? "text-green-300 overline" : ""
                }`}
                to="/liquidity"
              >
                Liquidity
              </Link>
            </li>
          </ul>
          <ul>
            <li>
              {!account ? (
                <button
                  className="btn btn-success w-full rounded-lg text-gray-700 hover:bg-green-300"
                  onClick={() => handleConnectWallet()}
                >
                  NOT CONNECTED
                </button>
              ) : (
                <button
                  className="btn btn-success w-full rounded-lg text-gray-700 hover:bg-green-300"
                  onClick={() => handleDisconnectWallet()}
                >
                  {truncateStr(account, 5)}
                </button>
              )}
            </li>
          </ul>
        </div>
      </div>
      <Routes>
        <Route path="/" element={<Swap />} />
        <Route path="swap" element={<Swap />} />
        <Route path="stake" element={<Stake />} />
        <Route path="liquidity" element={<Liquidity />} />
      </Routes>
    </div>
  );
};

export default Navbar;
