// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

/**
 * @title KAICENTS
 * @dev Utility token for gas fees, ecosystem utility, and prediction markets
 * @dev Fixed supply of 1 billion tokens with governance voting capabilities
 */
contract KAICENTS is 
    Initializable,
    ERC20VotesUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
    bytes32 public constant GAS_MANAGER_ROLE = keccak256("GAS_MANAGER_ROLE");
    
    uint256 public constant MAX_SUPPLY = 1_000_000_000 ether; // 1 billion tokens
    
    event TokensTransferred(address indexed from, address indexed to, uint256 amount);
    event GasPayment(address indexed payer, uint256 amount, bytes32 indexed txHash);
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    /**
     * @dev Initializes the contract
     * @param defaultAdmin Address that will receive admin roles
     * @param initialHolder Address that will receive the total supply
     */
    function initialize(
        address defaultAdmin, 
        address initialHolder
    ) public initializer {
        require(defaultAdmin != address(0), "KAICENTS: admin cannot be zero address");
        require(initialHolder != address(0), "KAICENTS: holder cannot be zero address");
        
        __ERC20_init("KAI CENTS", "KAI");
        __ERC20Permit_init("KAI CENTS");
        __ERC20Votes_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(UPGRADER_ROLE, defaultAdmin);
        _grantRole(GOVERNOR_ROLE, defaultAdmin);
        _grantRole(GAS_MANAGER_ROLE, defaultAdmin);
        
        // Pre-mint the entire supply to the initial holder
        _mint(initialHolder, MAX_SUPPLY);
        
        emit TokensTransferred(address(0), initialHolder, MAX_SUPPLY);
    }
    
    /**
     * @dev Returns the total supply cap
     */
    function cap() public pure returns (uint256) {
        return MAX_SUPPLY;
    }
    
    /**
     * @dev Pay for gas using KAI tokens - burns tokens from sender
     * @param amount Amount of KAI tokens to burn for gas payment
     * @param txHash Transaction hash for tracking
     */
    function payGas(uint256 amount, bytes32 txHash) external nonReentrant {
        require(amount > 0, "KAICENTS: amount must be greater than 0");
        require(balanceOf(msg.sender) >= amount, "KAICENTS: insufficient balance");
        
        _burn(msg.sender, amount);
        emit GasPayment(msg.sender, amount, txHash);
    }
    
    /**
     * @dev Emergency gas payment by authorized gas manager
     * @param user User whose gas is being paid
     * @param amount Amount to burn
     * @param txHash Transaction hash for tracking
     */
    function payGasFor(
        address user, 
        uint256 amount, 
        bytes32 txHash
    ) external onlyRole(GAS_MANAGER_ROLE) nonReentrant {
        require(user != address(0), "KAICENTS: user cannot be zero address");
        require(amount > 0, "KAICENTS: amount must be greater than 0");
        require(balanceOf(user) >= amount, "KAICENTS: insufficient user balance");
        
        _burn(user, amount);
        emit GasPayment(user, amount, txHash);
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