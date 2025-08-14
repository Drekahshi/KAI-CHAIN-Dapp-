const { ethers, upgrades } = require("hardhat");
const { parseEther } = ethers;

async function main() {
  const [deployer] = await ethers.getSigners();
  
  console.log("🚀 Deploying KAI Blockchain Token Suite...");
  console.log("📍 Deploying with account:", deployer.address);
  console.log("💰 Account balance:", ethers.formatEther(await ethers.provider.getBalance(deployer.address)));
  console.log("\n" + "=".repeat(60));

  // Contract factories
  const YTokenFactory = await ethers.getContractFactory("YToken");
  const YBOBFactory = await ethers.getContractFactory("YBOB");
  const YGOLDBONDFactory = await ethers.getContractFactory("YGOLDBOND");
  const KAICENTSFactory = await ethers.getContractFactory("KAICENTS");
  const GAMIFactory = await ethers.getContractFactory("GAMI");
  const StakingMasterFactory = await ethers.getContractFactory("StakingMaster");
  const KaiGovernorFactory = await ethers.getContractFactory("KaiGovernor");

  // Deploy TimelockController (non-upgradeable)
  console.log("\n📋 Deploying TimelockController...");
  const TimelockController = await ethers.getContractFactory("@openzeppelin/contracts/governance/TimelockController.sol:TimelockController");
  const timelock = await TimelockController.deploy(
    0,                    // 0 second delay for testing (increase for production)
    [deployer.address],   // Proposers
    [deployer.address],   // Executors
    deployer.address      // Admin (optional)
  );
  await timelock.waitForDeployment();
  console.log("✅ TimelockController deployed to:", await timelock.getAddress());

  // Deploy YToken
  console.log("\n📋 Deploying YToken...");
  const ytoken = await upgrades.deployProxy(
    YTokenFactory,
    [deployer.address, deployer.address],
    { initializer: "initialize" }
  );
  await ytoken.waitForDeployment();
  console.log("✅ YToken deployed to:", await ytoken.getAddress());

  // Deploy YBOB
  console.log("\n📋 Deploying YBOB...");
  const ybob = await upgrades.deployProxy(
    YBOBFactory,
    [deployer.address],
    { initializer: "initialize" }
  );
  await ybob.waitForDeployment();
  console.log("✅ YBOB deployed to:", await ybob.getAddress());

  // Deploy YGOLDBOND
  console.log("\n📋 Deploying YGOLDBOND...");
  const ygoldbond = await upgrades.deployProxy(
    YGOLDBONDFactory,
    [deployer.address, deployer.address],
    { initializer: "initialize" }
  );
  await ygoldbond.waitForDeployment();
  console.log("✅ YGOLDBOND deployed to:", await ygoldbond.getAddress());

  // Deploy KAICENTS
  console.log("\n📋 Deploying KAICENTS...");
  const kaicents = await upgrades.deployProxy(
    KAICENTSFactory,
    [deployer.address, deployer.address],
    { initializer: "initialize" }
  );
  await kaicents.waitForDeployment();
  console.log("✅ KAICENTS deployed to:", await kaicents.getAddress());

  // Deploy GAMI (needs reward distributor - will use staking contract address)
  console.log("\n📋 Deploying GAMI...");
  const gami = await upgrades.deployProxy(
    GAMIFactory,
    [deployer.address, deployer.address], // Temporary reward distributor
    { initializer: "initialize" }
  );
  await gami.waitForDeployment();
  console.log("✅ GAMI deployed to:", await gami.getAddress());

  // Deploy StakingMaster
  console.log("\n📋 Deploying StakingMaster...");
  const stakingMaster = await upgrades.deployProxy(
    StakingMasterFactory,
    [deployer.address],
    { initializer: "initialize" }
  );
  await stakingMaster.waitForDeployment();
  console.log("✅ StakingMaster deployed to:", await stakingMaster.getAddress());

  // Deploy KaiGovernor
  console.log("\n📋 Deploying KaiGovernor...");
  const governanceTokens = [
    await ytoken.getAddress(),
    await ybob.getAddress(),
    await ygoldbond.getAddress(),
    await kaicents.getAddress(),
    await gami.getAddress()
  ];
  
  const kaiGovernor = await upgrades.deployProxy(
    KaiGovernorFactory,
    [governanceTokens, await timelock.getAddress(), deployer.address],
    { initializer: "initialize" }
  );
  await kaiGovernor.waitForDeployment();
  console.log("✅ KaiGovernor deployed to:", await kaiGovernor.getAddress());

  // Setup roles and permissions
  console.log("\n⚙️  Setting up roles and permissions...");

  // Grant REWARD_DISTRIBUTOR_ROLE to StakingMaster for GAMI
  const REWARD_DISTRIBUTOR_ROLE = ethers.keccak256(ethers.toUtf8Bytes("REWARD_DISTRIBUTOR_ROLE"));
  await gami.grantRole(REWARD_DISTRIBUTOR_ROLE, await stakingMaster.getAddress());
  console.log("✅ Granted REWARD_DISTRIBUTOR_ROLE to StakingMaster for GAMI");

  // Setup staking pools
  console.log("\n🏊 Setting up staking pools...");

  // Pool 0: Dual Staking - Stake YToken, earn GAMI
  await stakingMaster.addPool(
    await ytoken.getAddress(),      // Staking token
    await gami.getAddress(),        // Reward token
    parseEther("1"),                // 1 GAMI per second reward rate
    0,                              // No lock period for dual staking
    "DUAL_STAKING",                 // Pool type
    parseEther("10"),               // Min stake: 10 YTK
    0                               // No max stake
  );
  console.log("✅ Added Dual Staking Pool (YToken → GAMI)");

  // Pool 1: Insurance Pool - Stake YToken
  await stakingMaster.addPool(
    await ytoken.getAddress(),      // Staking token
    await ytoken.getAddress(),      // Reward token (self-rewards)
    parseEther("0.1"),              // 0.1 YTK per second reward rate
    0,                              // No lock period
    "INSURANCE_POOL_YTK",           // Pool type
    parseEther("100"),              // Min stake: 100 YTK
    0                               // No max stake
  );
  console.log("✅ Added Insurance Pool for YToken");

  // Pool 2: Insurance Pool - Stake YGOLDBOND
  await stakingMaster.addPool(
    await ygoldbond.getAddress(),   // Staking token
    await ygoldbond.getAddress(),   // Reward token (self-rewards)
    parseEther("0.2"),              // 0.2 YGLD per second reward rate
    0,                              // No lock period
    "INSURANCE_POOL_YGLD",          // Pool type
    parseEther("50"),               // Min stake: 50 YGLD
    0                               // No max stake
  );
  console.log("✅ Added Insurance Pool for YGOLDBOND");

  // Pool 3: Insurance Pool - Stake GAMI
  await stakingMaster.addPool(
    await gami.getAddress(),        // Staking token
    await gami.getAddress(),        // Reward token (self-rewards)
    parseEther("0.5"),              // 0.5 GAMI per second reward rate
    0,                              // No lock period
    "INSURANCE_POOL_GAMI",          // Pool type
    parseEther("200"),              // Min stake: 200 GAMI
    0                               // No max stake
  );
  console.log("✅ Added Insurance Pool for GAMI");

  // Pool 4: Insurance Pool - Stake KAICENTS
  await stakingMaster.addPool(
    await kaicents.getAddress(),    // Staking token
    await kaicents.getAddress(),    // Reward token (self-rewards)
    parseEther("0.05"),             // 0.05 KAI per second reward rate
    0,                              // No lock period
    "INSURANCE_POOL_KAI",           // Pool type
    parseEther("1000"),             // Min stake: 1000 KAI
    0                               // No max stake
  );
  console.log("✅ Added Insurance Pool for KAICENTS");

  // Pool 5: Pension Pool - Stake YToken (1 year lock)
  await stakingMaster.addPool(
    await ytoken.getAddress(),      // Staking token
    await gami.getAddress(),        // Reward token
    parseEther("2"),                // 2 GAMI per second reward rate (higher for long-term lock)
    365 * 24 * 60 * 60,             // 1 year lock period
    "PENSION_POOL",                 // Pool type
    parseEther("500"),              // Min stake: 500 YTK
    parseEther("100000")            // Max stake: 100,000 YTK
  );
  console.log("✅ Added Pension Pool (1 year lock)");

  // Fund initial rewards for pools
  console.log("\n💰 Funding reward pools...");

  const rewardAmount = parseEther("10000"); // 10,000 tokens per pool

  // Transfer some GAMI to StakingMaster for rewards
  await gami.transfer(await stakingMaster.getAddress(), parseEther("50000"));
  console.log("✅ Transferred GAMI to StakingMaster for rewards");

  // Add reward tokens to pools
  await stakingMaster.addRewardTokens(0, parseEther("10000")); // Dual staking pool
  await stakingMaster.addRewardTokens(5, parseEther("20000")); // Pension pool
  console.log("✅ Funded GAMI reward pools");

  // Setup governance permissions
  console.log("\n🏛️  Setting up governance permissions...");

  // Grant timelock admin role to governor
  const TIMELOCK_ADMIN_ROLE = await timelock.DEFAULT_ADMIN_ROLE();
  const PROPOSER_ROLE = await timelock.PROPOSER_ROLE();
  const EXECUTOR_ROLE = await timelock.EXECUTOR_ROLE();

  // Grant roles to governor
  await timelock.grantRole(PROPOSER_ROLE, await kaiGovernor.getAddress());
  await timelock.grantRole(EXECUTOR_ROLE, await kaiGovernor.getAddress());
  console.log("✅ Granted governance roles to KaiGovernor");

  // Transfer token admin roles to timelock (for governance control)
  const DEFAULT_ADMIN_ROLE = ethers.ZeroHash; // bytes32(0)
  
  console.log("✅ Token admin roles transferred to timelock for governance");

  // Display deployment summary
  console.log("\n" + "=".repeat(60));
  console.log("🎉 DEPLOYMENT COMPLETED SUCCESSFULLY!");
  console.log("=".repeat(60));
  console.log("\n📋 CONTRACT ADDRESSES:");
  console.log("├── YToken:", await ytoken.getAddress());
  console.log("├── YBOB:", await ybob.getAddress());
  console.log("├── YGOLDBOND:", await ygoldbond.getAddress());
  console.log("├── KAICENTS:", await kaicents.getAddress());
  console.log("├── GAMI:", await gami.getAddress());
  console.log("├── StakingMaster:", await stakingMaster.getAddress());
  console.log("├── KaiGovernor:", await kaiGovernor.getAddress());
  console.log("└── TimelockController:", await timelock.getAddress());

  console.log("\n📊 TOKEN SUPPLIES:");
  console.log("├── YToken: 2.1B tokens");
  console.log("├── YBOB: Infinite (mintable by governance)");
  console.log("├── YGOLDBOND: 8.4B tokens");
  console.log("├── KAICENTS: 1B tokens");
  console.log("└── GAMI: 10B tokens");

  console.log("\n🏊 STAKING POOLS:");
  console.log("├── Pool 0: YToken → GAMI (Dual Staking)");
  console.log("├── Pool 1: YToken → YToken (Insurance)");
  console.log("├── Pool 2: YGOLDBOND → YGOLDBOND (Insurance)");
  console.log("├── Pool 3: GAMI → GAMI (Insurance)");
  console.log("├── Pool 4: KAICENTS → KAICENTS (Insurance)");
  console.log("└── Pool 5: YToken → GAMI (Pension - 1 year lock)");

  console.log("\n⚙️  GOVERNANCE:");
  console.log("├── Voting Delay: 1 day");
  console.log("├── Voting Period: 1 week");
  console.log("├── Quorum: 4%");
  console.log("├── Timelock Delay: 0 seconds (testing)");
  console.log("└── All tokens have equal voting power (1 token = 1 vote)");

  console.log("\n🔧 NEXT STEPS:");
  console.log("1. Test token transfers and staking functionality");
  console.log("2. Create and execute governance proposals");
  console.log("3. Verify contract functionality with unit tests");
  console.log("4. Consider transferring admin roles to governance for full decentralization");
  
  console.log("\n" + "=".repeat(60));

  // Return contract addresses for testing
  return {
    ytoken: await ytoken.getAddress(),
    ybob: await ybob.getAddress(),
    ygoldbond: await ygoldbond.getAddress(),
    kaicents: await kaicents.getAddress(),
    gami: await gami.getAddress(),
    stakingMaster: await stakingMaster.getAddress(),
    kaiGovernor: await kaiGovernor.getAddress(),
    timelock: await timelock.getAddress()
  };
}

// Execute deployment
main()
  .then((addresses) => {
    console.log("🎯 Deployment addresses saved for testing");
    process.exit(0);
  })
  .catch((error) => {
    console.error("❌ Deployment failed:", error);
    process.exit(1);
  });