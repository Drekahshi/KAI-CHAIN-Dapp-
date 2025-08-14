// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

/**
 * @title GAMI
 * @dev SocialFi rewards and meme token, also functions as LP and LST token
 * @dev Fixed supply of 10 billion tokens distributed through staking rewards
 */
contract GAMI is 
    Initializable,
    ERC20VotesUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
    bytes32 public constant REWARD_DISTRIBUTOR_ROLE = keccak256("REWARD_DISTRIBUTOR_ROLE");
    bytes32 public constant LP_MANAGER_ROLE = keccak256("LP_MANAGER_ROLE");
    
    uint256 public constant MAX_SUPPLY = 10_000_000_000 ether; // 10 billion tokens
    uint256 public totalDistributed;
    
    // Tracking for different token usages
    mapping(address => uint256) public lpBalance; // LP token balance
    mapping(address => uint256) public lstBalance; // LST balance
    mapping(address => uint256) public socialRewards; // SocialFi rewards earned
    
    event TokensTransferred(address indexed from, address indexed to, uint256 amount);
    event SocialRewardEarned(address indexed user, uint256 amount, string activity);
    event LPTokensStaked(address indexed user, uint256 amount);
    event LSTTokensStaked(address indexed user, uint256 amount);
    event RewardDistributed(address indexed to, uint256 amount, string reason);
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    /**
     * @dev Initializes the contract
     * @param defaultAdmin Address that will receive admin roles
     * @param rewardDistributor Address authorized to distribute rewards (staking contract)
     */
    function initialize(
        address defaultAdmin,
        address rewardDistributor
    ) public initializer {
        require(defaultAdmin != address(0), "GAMI: admin cannot be zero address");
        require(rewardDistributor != address(0), "GAMI: distributor cannot be zero address");
        
        __ERC20_init("GAMI", "GAMI");
        __ERC20Permit_init("GAMI");
        __ERC20Votes_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(UPGRADER_ROLE, defaultAdmin);
        _grantRole(GOVERNOR_ROLE, defaultAdmin);
        _grantRole(REWARD_DISTRIBUTOR_ROLE, rewardDistributor);
        _grantRole(LP_MANAGER_ROLE, defaultAdmin);
        
        // Initial mint to admin for initial distribution setup
        uint256 initialMint = 1_000_000_000 ether; // 1 billion for initial setup
        _mint(defaultAdmin, initialMint);
        totalDistributed = initialMint;
        
        emit TokensTransferred(address(0), defaultAdmin, initialMint);
    }
    
    /**
     * @dev Returns the total supply cap
     */
    function cap() public pure returns (uint256) {
        return MAX_SUPPLY;
    }
    
    /**
     * @dev Returns remaining tokens available for distribution
     */
    function remainingSupply() public view returns (uint256) {
        return MAX_SUPPLY - totalSupply();
    }
    
    /**
     * @dev Distribute GAMI tokens as staking rewards
     * @param to Recipient address
     * @param amount Amount to distribute
     * @param reason Reason for distribution
     */
    function distributeReward(
        address to, 
        uint256 amount, 
        string calldata reason
    ) external onlyRole(REWARD_DISTRIBUTOR_ROLE) nonReentrant {
        require(to != address(0), "GAMI: cannot distribute to zero address");
        require(amount > 0, "GAMI: amount must be greater than 0");
        require(totalSupply() + amount <= MAX_SUPPLY, "GAMI: would exceed max supply");
        
        _mint(to, amount);
        totalDistributed += amount;
        
        emit RewardDistributed(to, amount, reason);
        emit TokensTransferred(address(0), to, amount);
    }
    
    /**
     * @dev Award social rewards for user interactions
     * @param user User earning the reward
     * @param amount Amount of reward
     * @param activity Activity that earned the reward
     */
    function awardSocialReward(
        address user, 
        uint256 amount, 
        string calldata activity
    ) external onlyRole(REWARD_DISTRIBUTOR_ROLE) nonReentrant {
        require(user != address(0), "GAMI: user cannot be zero address");
        require(amount > 0, "GAMI: amount must be greater than 0");
        require(totalSupply() + amount <= MAX_SUPPLY, "GAMI: would exceed max supply");
        
        _mint(user, amount);
        socialRewards[user] += amount;
        totalDistributed += amount;
        
        emit SocialRewardEarned(user, amount, activity);
        emit TokensTransferred(address(0), user, amount);
    }
    
    /**
     * @dev Stake GAMI as LP tokens
     * @param amount Amount to stake as LP
     */
    function stakeAsLP(uint256 amount) external nonReentrant {
        require(amount > 0, "GAMI: amount must be greater than 0");
        require(balanceOf(msg.sender) >= amount, "GAMI: insufficient balance");
        
        lpBalance[msg.sender] += amount;
        emit LPTokensStaked(msg.sender, amount);
    }
    
    /**
     * @dev Stake GAMI as LST tokens
     * @param amount Amount to stake as LST
     */
    function stakeAsLST(uint256 amount) external nonReentrant {
        require(amount > 0, "GAMI: amount must be greater than 0");
        require(balanceOf(msg.sender) >= amount, "GAMI: insufficient balance");
        
        lstBalance[msg.sender] += amount;
        emit LSTTokensStaked(msg.sender, amount);
    }
    
    /**
     * @dev Get user's social rewards earned
     * @param user User address
     */
    function getSocialRewards(address user) external view returns (uint256) {
        return socialRewards[user];
    }
    
    /**
     * @dev Get user's LP token balance
     * @param user User address
     */
    function getLPBalance(address user) external view returns (uint256) {
        return lpBalance[user];
    }
    
    /**
     * @dev Get user's LST token balance
     * @param user User address
     */
    function getLSTBalance(address user) external view returns (uint256) {
        return lstBalance[user];
    }
    
    /**
     * @dev Authorizes contract upgrades - only UPGRADER_ROLE can upgrade
     */
    function _authorizeUpgrade(address newImplementation) 
        internal 
        onlyRole(UPGRADER_ROLE) 
        override 
    {
        // Additional upgrade logic can be added here
    }
    
    /**
     * @dev Override _update to add event logging and handle voting power
     */
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20Upgradeable, ERC20VotesUpgradeable) {
        super._update(from, to, amount);
        
        if (from != address(0) && to != address(0)) {
            emit TokensTransferred(from, to, amount);
        }
    }
    
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
    
    /**
     * @dev Returns the current nonce for `owner`. Used for permit functionality.
     */
    function nonces(address owner)
        public
        view
        override(ERC20PermitUpgradeable, NoncesUpgradeable)
        returns (uint256)
    {
        return super.nonces(owner);
    }
}