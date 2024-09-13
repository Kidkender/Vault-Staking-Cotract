import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

// Address token example
const tokenAddress = process.env.TOKEN_ADDRESS || "0x3F75E56495a31db40EaE9E29ceF3DaeC18fd7f83";
const TeraStakingModule = buildModule("TeraStakingModule", (m) => {
  const Terra = m.contract("StakingTerrabet", [
    tokenAddress,
  ]);

  return { Terra };
});

export default TeraStakingModule;
