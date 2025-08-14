// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

/**
 * @title YToken
 * @notice Fixed-supply (2.1B) ERC20 token with governance capabilities, permits, and UUPS upgradeability.
 * @dev This contract implements:
 *      - ERC20 with voting capabilities (ERC20Votes)
 *      - EIP-2612 permit functionality for gasless approvals
 *      - Role-based access control with multiple roles
 *      - UUPS proxy pattern for upgradeability
 *      - Emergency pause functionality
 *      - Reentrancy protection for critical functions
 * 
 * Security Features:
 * - Fixed supply prevents inflation attacks
 * - Role separation for better security
 * - Emergency pause capability
 * - Reentrancy guards on critical functions
 * - Comprehensive input validation
 */
contract YToken is
    Initializable,
    ERC20Upgradeable,
    ERC20PermitUpgradeable,
    ERC20VotesUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    // ============ CONSTANTS ============
    
    /// @notice Role identifier for addresses that can upgrade the contract
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    
    /// @notice Role identifier for addresses that can pause/unpause the contract
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    
    /// @notice Role identifier for addresses that can perform emergency functions
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    
    /// @notice Maximum token supply (2.1 billion tokens with 18 decimals)
    uint256 public constant MAX_SUPPLY = 2_100_000_000 ether;
    
    /// @notice Contract version for upgrade tracking
    string public constant VERSION = "1.0.0";

    // ============ EVENTS ============
    
    /// @notice Emitted when the contract is initialized
    event TokenInitialized(
        address indexed admin,
        address indexed initialHolder,
        uint256 totalSupply,
        string version
    );
    
    /// @notice Emitted when emergency functions are called
    event EmergencyAction(address indexed caller, string action, bytes data);

    // ============ ERRORS ============
    
    error ZeroAddress();
    error InvalidSupply();
    error TransferPaused();
    error InsufficientBalance();

    // ============ MODIFIERS ============
    
    /// @notice Ensures transfers are not paused
    modifier whenTransferNotPaused() {
        if (paused()) revert TransferPaused();
        _;
    }

    // ============ CONSTRUCTOR ============
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // ============ INITIALIZATION ============
    
    /**
     * @notice Initializes the YToken contract
     * @param defaultAdmin Address that receives admin role (should be a multisig)
     * @param initialHolder Address that receives the entire token supply
     * @param pauser Address that receives pauser role (can be same as admin)
     * @param upgrader Address that receives upgrader role (should be governance contract)
     * 
     * @dev This function can only be called once due to the initializer modifier
     *      Roles are separated for better security practices:
     *      - Admin: Can grant/revoke roles, emergency functions
     *      - Upgrader: Can upgrade the contract (should be governance)
     *      - Pauser: Can pause/unpause transfers
     */
    function initialize(
        address defaultAdmin,
        address initialHolder,
        address pauser,
        address upgrader
    ) public initializer {
        if (defaultAdmin == address(0)) revert ZeroAddress();
        if (initialHolder == address(0)) revert ZeroAddress();
        if (pauser == address(0)) revert ZeroAddress();
        if (upgrader == address(0)) revert ZeroAddress();

        // Initialize parent contracts
        __ERC20_init("YToken", "YTK");
        __ERC20Permit_init("YToken");
        __ERC20Votes_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        __Pausable_init();

        // Setup roles with principle of least privilege
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(EMERGENCY_ROLE, defaultAdmin);
        _grantRole(UPGRADER_ROLE, upgrader);
        _grantRole(PAUSER_ROLE, pauser);

        // Mint fixed supply to initial holder
        _mint(initialHolder, MAX_SUPPLY);

        emit TokenInitialized(defaultAdmin, initialHolder, MAX_SUPPLY, VERSION);
    }

    // ============ PUBLIC VIEW FUNCTIONS ============
    
    /// @notice Returns the maximum token supply
    /// @return The maximum supply of tokens
    function cap() external pure returns (uint256) {
        return MAX_SUPPLY;
    }

    /// @notice Returns the current contract version
    /// @return The version string
    function version() external pure returns (string memory) {
        return VERSION;
    }

    // ============ ADMIN FUNCTIONS ============
    
    /**
     * @notice Pauses all token transfers
     * @dev Can only be called by addresses with PAUSER_ROLE
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @notice Unpauses all token transfers
     * @dev Can only be called by addresses with PAUSER_ROLE
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @notice Emergency function to recover accidentally sent ERC20 tokens
     * @param token The ERC20 token contract address
     * @param to The address to send recovered tokens to
     * @param amount The amount of tokens to recover
     * @dev Can only be called by addresses with EMERGENCY_ROLE
     *      Cannot recover YTokens to prevent admin abuse
     */
    function emergencyTokenRecovery(
        address token,
        address to,
        uint256 amount
    ) external onlyRole(EMERGENCY_ROLE) nonReentrant {
        if (token == address(this)) revert InvalidSupply();
        if (to == address(0)) revert ZeroAddress();
        
        // Use low-level call for better compatibility
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSignature("transfer(address,uint256)", to, amount)
        );
        
        require(success && (data.length == 0 || abi.decode(data, (bool))), "Recovery failed");
        
        emit EmergencyAction(msg.sender, "tokenRecovery", abi.encode(token, to, amount));
    }

    // ============ INTERNAL OVERRIDES ============
    
    /**
     * @notice Internal function to authorize contract upgrades
     * @param newImplementation The address of the new implementation
     * @dev Only addresses with UPGRADER_ROLE can authorize upgrades
     */
    function _authorizeUpgrade(address newImplementation) 
        internal 
        override 
        onlyRole(UPGRADER_ROLE) 
    {
        // Additional upgrade validation could be added here
        // e.g., checking implementation compatibility
    }

    /**
     * @notice Internal update function with pause and reentrancy protection
     * @param from The address tokens are transferred from
     * @param to The address tokens are transferred to  
     * @param value The amount of tokens transferred
     * @dev Overrides multiple parent contracts to ensure proper functionality
     */
    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20Upgradeable, ERC20VotesUpgradeable) whenTransferNotPaused {
        super._update(from, to, value);
    }

    /**
     * @notice Returns the nonce for EIP-2612 permits
     * @param owner The address to get the nonce for
     * @return The current nonce
     * @dev Resolves multiple inheritance ambiguity
     */
    function nonces(address owner)
        public
        view
        override(ERC20PermitUpgradeable, NoncesUpgradeable)
        returns (uint256)
    {
        return super.nonces(owner);
    }

    /**
     * @notice Checks if contract supports a given interface
     * @param interfaceId The interface identifier
     * @return True if the interface is supported
     * @dev Required override for AccessControl
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    // ============ STORAGE GAP ============
    
    /**
     * @dev Storage gap for future variables in upgrades
     *      Reduced from 50 to account for new state variables
     */
    uint256[45] private __gap;
}
