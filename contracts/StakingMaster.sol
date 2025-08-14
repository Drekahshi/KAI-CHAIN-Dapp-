// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

/**
 * @title StakingMaster
 * @dev Master contract for managing multiple staking pools including dual staking, insurance, and pension pools
 */
contract StakingMaster is 
    Initializable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant POOL_MANAGER_ROLE = keccak256("POOL_MANAGER_ROLE");
    bytes32 public constant REWARD_MANAGER_ROLE = keccak256("REWARD_MANAGER_ROLE");
    
    struct PoolInfo {
        IERC20Upgradeable stakingToken;     // Token to be staked
        IERC20Upgradeable rewardToken;      // Token used as reward
        uint256 rewardRate;                 // Rewards per second
        uint256 lastRewardTime;             // Last time rewards were calculated
        uint256 accRewardPerShare;          // Accumulated reward per share, times 1e18
        uint256 totalStaked;                // Total tokens staked in pool
        uint256 lockPeriod;                 // Lock period in seconds (0 for no lock)
        bool isActive;                      // Pool active status
        string poolType;                    // Pool type identifier
        uint256 minStakeAmount;             // Minimum stake amount
        uint256 maxStakeAmount;             // Maximum stake amount (0 for unlimited)
    }
    
    struct UserInfo {
        uint256 amount;                     // Amount staked by user
        uint256 rewardDebt;                 // Reward debt for accurate calculation
        uint256 lastStakeTime;              // Timestamp of last stake
        uint256 pendingRewards;             // Pending rewards to be claimed
        uint256 totalEarned;                // Total rewards earned historically
    }
    
    PoolInfo[] public poolInfo;
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    mapping(uint256 => uint256) public poolRewardBalance; // Track reward token balance per pool
    
    // Events
    event PoolAdded(
        uint256 indexed pid,
        address indexed stakingToken,
        address indexed rewardToken,
        uint256 rewardRate,
        string poolType
    );
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event ClaimReward(address indexed user, uint256 indexed pid, uint256 amount);
    event PoolUpdated(uint256 indexed pid, uint256 rewardRate, bool isActive);
    event RewardAdded(uint256 indexed pid, uint256 amount);
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    /**
     * @dev Initialize the staking master contract
     * @param admin Address that will receive admin roles
     */
    function initialize(address admin) public initializer {
        require(admin != address(0), "StakingMaster: admin cannot be zero address");
        
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);
        _grantRole(POOL_MANAGER_ROLE, admin);
        _grantRole(REWARD_MANAGER_ROLE, admin);
    }
    
    /**
     * @dev Add a new staking pool
     * @param _stakingToken Token to be staked
     * @param _rewardToken Token used as reward
     * @param _rewardRate Rewards per second
     * @param _lockPeriod Lock period in seconds
     * @param _poolType Pool type identifier
     * @param _minStakeAmount Minimum stake amount
     * @param _maxStakeAmount Maximum stake amount (0 for unlimited)
     */
    function addPool(
        IERC20Upgradeable _stakingToken,
        IERC20Upgradeable _rewardToken,
        uint256 _rewardRate,
        uint256 _lockPeriod,
        string calldata _poolType,
        uint256 _minStakeAmount,
        uint256 _maxStakeAmount
    ) external onlyRole(POOL_MANAGER_ROLE) {
        require(address(_stakingToken) != address(0), "StakingMaster: staking token cannot be zero");
        require(address(_rewardToken) != address(0), "StakingMaster: reward token cannot be zero");
        require(_rewardRate > 0, "StakingMaster: reward rate must be positive");
        
        poolInfo.push(PoolInfo({
            stakingToken: _stakingToken,
            rewardToken: _rewardToken,
            rewardRate: _rewardRate,
            lastRewardTime: block.timestamp,
            accRewardPerShare: 0,
            totalStaked: 0,
            lockPeriod: _lockPeriod,
            isActive: true,
            poolType: _poolType,
            minStakeAmount: _minStakeAmount,
            maxStakeAmount: _maxStakeAmount
        }));
        
        emit PoolAdded(
            poolInfo.length - 1,
            address(_stakingToken),
            address(_rewardToken),
            _rewardRate,
            _poolType
        );
    }
    
    /**
     * @dev Update pool settings
     * @param _pid Pool ID
     * @param _rewardRate New reward rate
     * @param _isActive New active status
     */
    function updatePool(
        uint256 _pid, 
        uint256 _rewardRate, 
        bool _isActive
    ) external onlyRole(POOL_MANAGER_ROLE) {
        require(_pid < poolInfo.length, "StakingMaster: pool does not exist");
        
        _updatePoolRewards(_pid);
        
        poolInfo[_pid].rewardRate = _rewardRate;
        poolInfo[_pid].isActive = _isActive;
        
        emit PoolUpdated(_pid, _rewardRate, _isActive);
    }
    
    /**
     * @dev Add reward tokens to a pool
     * @param _pid Pool ID
     * @param _amount Amount of reward tokens to add
     */
    function addRewardTokens(
        uint256 _pid, 
        uint256 _amount
    ) external onlyRole(REWARD_MANAGER_ROLE) {
        require(_pid < poolInfo.length, "StakingMaster: pool does not exist");
        require(_amount > 0, "StakingMaster: amount must be positive");
        
        PoolInfo storage pool = poolInfo[_pid];
        pool.rewardToken.safeTransferFrom(msg.sender, address(this), _amount);
        poolRewardBalance[_pid] += _amount;
        
        emit RewardAdded(_pid, _amount);
    }
    
    /**
     * @dev Update reward variables for a pool
     * @param _pid Pool ID
     */
    function _updatePoolRewards(uint256 _pid) internal {
        PoolInfo storage pool = poolInfo[_pid];
        
        if (block.timestamp <= pool.lastRewardTime) {
            return;
        }
        
        if (pool.totalStaked == 0) {
            pool.lastRewardTime = block.timestamp;
            return;
        }
        
        uint256 timePassed = block.timestamp - pool.lastRewardTime;
        uint256 reward = timePassed * pool.rewardRate;
        
        // Check if we have enough rewards in the pool
        if (reward > poolRewardBalance[_pid]) {
            reward = poolRewardBalance[_pid];
        }
        
        if (reward > 0) {
            pool.accRewardPerShare += (reward * 1e18) / pool.totalStaked;
            poolRewardBalance[_pid] -= reward;
        }
        
        pool.lastRewardTime = block.timestamp;
    }
    
    /**
     * @dev Stake tokens in a pool
     * @param _pid Pool ID
     * @param _amount Amount to stake
     */
    function deposit(uint256 _pid, uint256 _amount) external nonReentrant whenNotPaused {
        require(_pid < poolInfo.length, "StakingMaster: pool does not exist");
        require(_amount > 0, "StakingMaster: amount must be positive");
        
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        
        require(pool.isActive, "StakingMaster: pool is not active");
        require(_amount >= pool.minStakeAmount, "StakingMaster: below minimum stake");
        
        if (pool.maxStakeAmount > 0) {
            require(
                user.amount + _amount <= pool.maxStakeAmount,
                "StakingMaster: exceeds maximum stake"
            );
        }
        
        _updatePoolRewards(_pid);
        
        // Calculate pending rewards before updating user balance
        if (user.amount > 0) {
            uint256 pending = (user.amount * pool.accRewardPerShare) / 1e18 - user.rewardDebt;
            user.pendingRewards += pending;
        }
        
        // Transfer staking tokens
        pool.stakingToken.safeTransferFrom(msg.sender, address(this), _amount);
        
        // Update pool and user data
        pool.totalStaked += _amount;
        user.amount += _amount;
        user.lastStakeTime = block.timestamp;
        user.rewardDebt = (user.amount * pool.accRewardPerShare) / 1e18;
        
        emit Deposit(msg.sender, _pid, _amount);
    }
    
    /**
     * @dev Withdraw staked tokens from a pool
     * @param _pid Pool ID
     * @param _amount Amount to withdraw
     */
    function withdraw(uint256 _pid, uint256 _amount) external nonReentrant {
        require(_pid < poolInfo.length, "StakingMaster: pool does not exist");
        require(_amount > 0, "StakingMaster: amount must be positive");
        
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        
        require(user.amount >= _amount, "StakingMaster: insufficient balance");
        require(
            block.timestamp >= user.lastStakeTime + pool.lockPeriod,
            "StakingMaster: tokens are locked"
        );
        
        _updatePoolRewards(_pid);
        
        // Calculate pending rewards
        uint256 pending = (user.amount * pool.accRewardPerShare) / 1e18 - user.rewardDebt;
        user.pendingRewards += pending;
        
        // Update pool and user data
        pool.totalStaked -= _amount;
        user.amount -= _amount;
        user.rewardDebt = (user.amount * pool.accRewardPerShare) / 1e18;
        
        // Transfer tokens back to user
        pool.stakingToken.safeTransfer(msg.sender, _amount);
        
        emit Withdraw(msg.sender, _pid, _amount);
    }
    
    /**
     * @dev Claim pending rewards from a pool
     * @param _pid Pool ID
     */
    function claimRewards(uint256 _pid) external nonReentrant {
        require(_pid < poolInfo.length, "StakingMaster: pool does not exist");
        
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        
        _updatePoolRewards(_pid);
        
        uint256 pending = (user.amount * pool.accRewardPerShare) / 1e18 - user.rewardDebt;
        uint256 totalRewards = user.pendingRewards + pending;
        
        if (totalRewards > 0) {
            user.pendingRewards = 0;
            user.totalEarned += totalRewards;
            user.rewardDebt = (user.amount * pool.accRewardPerShare) / 1e18;
            
            pool.rewardToken.safeTransfer(msg.sender, totalRewards);
            emit ClaimReward(msg.sender, _pid, totalRewards);
        }
    }
    
    /**
     * @dev Emergency withdraw without caring about rewards (in case of emergency)
     * @param _pid Pool ID
     */
    function emergencyWithdraw(uint256 _pid) external nonReentrant {
        require(_pid < poolInfo.length, "StakingMaster: pool does not exist");
        
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        
        uint256 amount = user.amount;
        require(amount > 0, "StakingMaster: no tokens to withdraw");
        
        pool.totalStaked -= amount;
        user.amount = 0;
        user.rewardDebt = 0;
        user.pendingRewards = 0;
        
        pool.stakingToken.safeTransfer(msg.sender, amount);
        
        emit EmergencyWithdraw(msg.sender, _pid, amount);
    }
    
    /**
     * @dev Get pending rewards for a user in a pool
     * @param _pid Pool ID
     * @param _user User address
     */
    function pendingReward(uint256 _pid, address _user) external view returns (uint256) {
        if (_pid >= poolInfo.length) return 0;
        
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        
        uint256 accRewardPerShare = pool.accRewardPerShare;
        
        if (block.timestamp > pool.lastRewardTime && pool.totalStaked > 0) {
            uint256 timePassed = block.timestamp - pool.lastRewardTime;
            uint256 reward = timePassed * pool.rewardRate;
            
            // Check available rewards
            if (reward > poolRewardBalance[_pid]) {
                reward = poolRewardBalance[_pid];
            }
            
            accRewardPerShare += (reward * 1e18) / pool.totalStaked;
        }
        
        return user.pendingRewards + (user.amount * accRewardPerShare) / 1e18 - user.rewardDebt;
    }
    
    /**
     * @dev Get number of pools
     */
    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }
    
    /**
     * @dev Pause the contract
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    
    /**
     * @dev Unpause the contract
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
    
    /**
     * @dev Authorize contract upgrades
     */
    function _authorizeUpgrade(address newImplementation) 
        internal 
        onlyRole(UPGRADER_ROLE) 
        override 
    {
        // Additional upgrade logic can be added here
    }
}