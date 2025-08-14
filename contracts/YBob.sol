// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

/**
 * @title YBOB
 * @dev Volatility hedge token with infinite supply (mintable by governance only)
 * @dev Supports governance voting and role-based minting
 */
contract YBOB is 
    Initializable,
    ERC20VotesUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    
    event TokensMinted(address indexed to, uint256 amount, address indexed minter);
    event TokensBurned(address indexed from, uint256 amount, address indexed burner);
    event MinterAdded(address indexed account);
    event MinterRemoved(address indexed account);
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    /**
     * @dev Initializes the contract
     * @param defaultAdmin Address that will receive admin roles and initial minting rights
     */
    function initialize(address defaultAdmin) public initializer {
        require(defaultAdmin != address(0), "YBOB: admin cannot be zero address");
        
        __ERC20_init("YBOB", "YBOB");
        __ERC20Permit_init("YBOB");
        __ERC20Votes_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(UPGRADER_ROLE, defaultAdmin);
        _grantRole(GOVERNOR_ROLE, defaultAdmin);
        _grantRole(MINTER_ROLE, defaultAdmin);
        _grantRole(BURNER_ROLE, defaultAdmin);
        
        emit MinterAdded(defaultAdmin);
    }
    
    /**
     * @dev Creates `amount` new tokens for `to`
     * @param to The address to mint tokens to
     * @param amount The amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) nonReentrant {
        require(to != address(0), "YBOB: cannot mint to zero address");
        require(amount > 0, "YBOB: amount must be greater than 0");
        
        _mint(to, amount);
        emit TokensMinted(to, amount, msg.sender);
    }
    
    /**
     * @dev Destroys `amount` tokens from `account`, reducing the total supply
     * @param from The address to burn tokens from
     * @param amount The amount of tokens to burn
     */
    function burn(address from, uint256 amount) external onlyRole(BURNER_ROLE) nonReentrant {
        require(from != address(0), "YBOB: cannot burn from zero address");
        require(amount > 0, "YBOB: amount must be greater than 0");
        require(balanceOf(from) >= amount, "YBOB: burn amount exceeds balance");
        
        _burn(from, amount);
        emit TokensBurned(from, amount, msg.sender);
    }
    
    /**
     * @dev Allows users to burn their own tokens
     * @param amount The amount of tokens to burn
     */
    function burnSelf(uint256 amount) external nonReentrant {
        require(amount > 0, "YBOB: amount must be greater than 0");
        require(balanceOf(msg.sender) >= amount, "YBOB: burn amount exceeds balance");
        
        _burn(msg.sender, amount);
        emit TokensBurned(msg.sender, amount, msg.sender);
    }
    
    /**
     * @dev Adds a new minter
     * @param account The address to grant minter role to
     */
    function addMinter(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(account != address(0), "YBOB: cannot add zero address as minter");
        _grantRole(MINTER_ROLE, account);
        emit MinterAdded(account);
    }
    
    /**
     * @dev Removes a minter
     * @param account The address to revoke minter role from
     */
    function removeMinter(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(MINTER_ROLE, account);
        emit MinterRemoved(account);
    }
    
    /**
     * @dev Checks if an account has minter role
     * @param account The address to check
     */
    function isMinter(address account) external view returns (bool) {
        return hasRole(MINTER_ROLE, account);
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
     * @dev Override _update to handle voting power tracking
     */
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20Upgradeable, ERC20VotesUpgradeable) {
        super._update(from, to, amount);
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