import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import {
  firstVault,
  secondVault,
  thirdVault,
  fourthVault,
  token,
} from "../../data/argDeploy.json";

const VaultStakingModule = buildModule("VaultModule", (m) => {
  const FirstVault = m.contract(
    "VaultStaking",
    [token, firstVault.timelock, firstVault.tier],
    { id: "firstVault" }
  );

  const SecondVault = m.contract(
    "VaultStaking",
    [token, secondVault.timelock, secondVault.tier],
    { id: "secondVault" }
  );

  const ThirdVault = m.contract(
    "VaultStaking",
    [token, thirdVault.timelock, thirdVault.tier],
    { id: "thirdVault" }
  );

  const FourthVault = m.contract(
    "VaultStaking",
    [token, fourthVault.timelock, fourthVault.tier],
    { id: "fourthVault" }
  );

  return {
    FirstVault,
    SecondVault,
    ThirdVault,
    FourthVault,
  };
});

export default VaultStakingModule;
