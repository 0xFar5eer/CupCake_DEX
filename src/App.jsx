import { useState, useEffect } from "react";
import {
  createBrowserRouter,
  createRoutesFromElements,
  RouterProvider,
  Route,
  Link,
} from "react-router-dom";
import Swap from "./pages/Swap";
import Stake from "./pages/Stake";
import Liquidity from "./pages/Liquidity";
import Navbar from "./components/Navbar";
import Web3ModalProvider from "./contexts/Web3ModalProvider";

function App() {
  const router = createBrowserRouter(
    createRoutesFromElements(
      <Route path="/" element={<Navbar />}>
        <Route path="swap" element={<Swap />} />
        <Route path="stake" element={<Stake />} />
        <Route path="liquidity" element={<Liquidity />} />
      </Route>
    )
  );

  useEffect(() => {
    (async () => {})();
  }, []);

  return (
    <>
      <Web3ModalProvider>
        <RouterProvider router={router} />
      </Web3ModalProvider>
    </>
  );
}

export default App;
