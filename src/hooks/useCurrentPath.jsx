import { matchRoutes, useLocation } from "react-router-dom";

const routes = [
  { path: "/" },
  { path: "/swap" },
  { path: "/stake" },
  { path: "/liquidity" },
];

export const useCurrentPath = () => {
  const location = useLocation();
  const [{ route }] = matchRoutes(routes, location);

  return route.path;
};
