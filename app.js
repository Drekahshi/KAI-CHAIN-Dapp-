// Global state
let currentSection = 'home';
let dailyTokens = 722;
let timeRemaining = 23 * 3600 + 51 * 60 + 50; // in seconds
let web3;
let userAccount;

// Core Testnet RPC configuration - UPDATED
const CORE_TESTNET_RPC = 'https://rpc.test.btcs.network'; // Alternative RPC
const CORE_TESTNET_CHAIN_ID = '1116'; // Corrected Chain ID
const CORE_TESTNET_CHAIN_ID_HEX = '0x45C'; // Hex version

// Backup RPC endpoints
const BACKUP_RPC_ENDPOINTS = [
    'https://rpc.test.btcs.network',
    'https://rpc.coredao.org', 
    'https://core-testnet-rpc.allthatnode.com:8545/v1/core'
];

// Initialize app
document.addEventListener('DOMContentLoaded', function() {
    showSection('home');
    startTokenTimer();
    addInteractiveEffects();
    initializeWeb3();
});

// Initialize Web3 with better error handling
async function initializeWeb3() {
    try {
        if (window.ethereum) {
            web3 = new Web3(window.ethereum);
            console.log('Web3 initialized with MetaMask');
        } else {
            // Try connecting to RPC directly
            await tryConnectToRPC();
        }
    } catch (error) {
        console.error('Error initializing Web3:', error);
        showNotification('Failed to initialize Web3 connection: ' + error.message);
    }
}

// Enhanced RPC connection with fallback
async function tryConnectToRPC() {
    for (let i = 0; i < BACKUP_RPC_ENDPOINTS.length; i++) {
        const rpcUrl = BACKUP_RPC_ENDPOINTS[i];
        console.log(`Trying RPC endpoint: ${rpcUrl}`);
        
        try {
            const testWeb3 = new Web3(new Web3.providers.HttpProvider(rpcUrl));
            
            // Test connection with timeout
            const latestBlock = await Promise.race([
                testWeb3.eth.getBlockNumber(),
                new Promise((_, reject) => setTimeout(() => reject(new Error('Timeout')), 10000))
            ]);
            
            console.log(`Successfully connected to ${rpcUrl}, latest block: ${latestBlock}`);
            web3 = testWeb3;
            return rpcUrl;
        } catch (error) {
            console.warn(`Failed to connect to ${rpcUrl}:`, error.message);
            continue;
        }
    }
    throw new Error('All RPC endpoints failed');
}

// Enhanced switch to Core Testnet
async function switchToCoreTestnet() {
    if (!window.ethereum) {
        throw new Error('No wallet detected');
    }

    try {
        // First try to switch
        await window.ethereum.request({
            method: 'wallet_switchEthereumChain',
            params: [{ chainId: CORE_TESTNET_CHAIN_ID_HEX }],
        });
        console.log('Successfully switched to Core Testnet');
    } catch (switchError) {
        console.log('Switch error code:', switchError.code);
        
        if (switchError.code === 4902) {
            // Chain not added, try to add it
            try {
                await window.ethereum.request({
                    method: 'wallet_addEthereumChain',
                    params: [{
                        chainId: CORE_TESTNET_CHAIN_ID_HEX,
                        chainName: 'Core Blockchain Testnet',
                        rpcUrls: BACKUP_RPC_ENDPOINTS,
                        nativeCurrency: {
                            name: 'Core',
                            symbol: 'tCORE',
                            decimals: 18,
                        },
                        blockExplorerUrls: ['https://scan.test.btcs.network'],
                    }],
                });
                console.log('Successfully added Core Testnet');
            } catch (addError) {
                console.error('Error adding Core Testnet:', addError);
                throw new Error('Failed to add Core Testnet to wallet: ' + addError.message);
            }
        } else {
            throw new Error('Failed to switch to Core Testnet: ' + switchError.message);
        }
    }
}

// Enhanced connect wallet
async function connectWallet() {
    if (!window.ethereum) {
        showNotification('Please install MetaMask or another Web3 wallet');
        return;
    }

    try {
        // Request accounts
        const accounts = await window.ethereum.request({ method: 'eth_requestAccounts' });
        userAccount = accounts[0];
        
        // Check and switch network if needed
        const chainId = await web3.eth.getChainId();
        console.log('Current chain ID:', chainId);
        
        if (chainId.toString() !== CORE_TESTNET_CHAIN_ID) {
            console.log('Wrong network, switching to Core Testnet');
            await switchToCoreTestnet();
        }
        
        showNotification(`Connected: ${userAccount.slice(0, 6)}...${userAccount.slice(-4)}`);
        await refreshBalance();
    } catch (error) {
        console.error('Error connecting wallet:', error);
        showNotification('Failed to connect wallet: ' + error.message);
    }
}

// Enhanced refresh wallet balance
async function refreshBalance() {
    if (!userAccount) {
        showNotification('Please connect your wallet first');
        return;
    }
    
    try {
        if (!web3) {
            await initializeWeb3();
        }
        
        const balance = await web3.eth.getBalance(userAccount);
        const balanceInCore = web3.utils.fromWei(balance, 'ether');
        document.getElementById('wallet-balance').textContent = `${parseFloat(balanceInCore).toFixed(4)} tCORE`;
        
        // Mock USD conversion - in production, use a real price API
        const usdValue = parseFloat(balanceInCore) * 0.5; // Mock price: 1 tCORE = $0.5
        document.querySelector('.balance-usd').textContent = `≈ $${usdValue.toFixed(2)} USD`;
        
        console.log(`Balance updated: ${balanceInCore} tCORE`);
    } catch (error) {
        console.error('Error fetching balance:', error);
        showNotification('Failed to fetch balance: ' + error.message);
    }
}

// Enhanced RPC connection with better error handling
async function connectToRPC() {
    const rpcStatusElement = document.getElementById('rpc-status');
    const rpcButtonElement = document.getElementById('rpc-connect-btn');
    
    try {
        // Update UI to show connecting state
        rpcStatusElement.textContent = 'Connecting...';
        rpcStatusElement.style.color = '#ffa500';
        rpcButtonElement.disabled = true;
        rpcButtonElement.textContent = '🔄 Connecting...';
        
        // Try to connect to RPC with fallback
        const connectedRPC = await tryConnectToRPC();
        
        // Test the connection more thoroughly
        const [latestBlock, networkId, gasPrice] = await Promise.all([
            web3.eth.getBlockNumber(),
            web3.eth.net.getId(),
            web3.eth.getGasPrice()
        ]);
        
        console.log('Connection test results:', {
            latestBlock,
            networkId: networkId.toString(),
            expectedChainId: CORE_TESTNET_CHAIN_ID,
            gasPrice: gasPrice.toString(),
            rpcUrl: connectedRPC
        });
        
        // Verify we're connected to Core Testnet (more flexible check)
        if (networkId.toString() === CORE_TESTNET_CHAIN_ID || networkId.toString() === '1115') {
            // Success - update UI
            rpcStatusElement.textContent = 'Connected ✓';
            rpcStatusElement.style.color = '#4caf50';
            rpcButtonElement.textContent = '✅ Connected to Core Testnet';
            rpcButtonElement.style.background = 'linear-gradient(135deg, #4caf50, #45a049)';
            
            showNotification(`Successfully connected to Core Testnet! Block: ${latestBlock} | RPC: ${connectedRPC}`);
            
            // Update button to show disconnect option
            rpcButtonElement.onclick = disconnectFromRPC;
            
        } else {
            throw new Error(`Wrong network. Expected ${CORE_TESTNET_CHAIN_ID}, got ${networkId.toString()}`);
        }
        
    } catch (error) {
        console.error('RPC connection failed:', error);
        
        // Error - update UI
        rpcStatusElement.textContent = 'Failed ✗';
        rpcStatusElement.style.color = '#f44336';
        rpcButtonElement.disabled = false;
        rpcButtonElement.textContent = '🌐 Retry Connection';
        rpcButtonElement.style.background = '';
        
        // Show detailed error
        const errorMsg = error.message || 'Unknown error';
        showNotification(`RPC connection failed: ${errorMsg}`, 'error');
        
        // Suggest manual steps
        if (errorMsg.includes('Timeout') || errorMsg.includes('failed')) {
            setTimeout(() => {
                showNotification('Try: 1) Check internet connection 2) Switch wallet network manually', 'info');
            }, 2000);
        }
    }
}

// Disconnect from RPC relay
function disconnectFromRPC() {
    const rpcStatusElement = document.getElementById('rpc-status');
    const rpcButtonElement = document.getElementById('rpc-connect-btn');
    
    // Reset Web3 instance
    web3 = null;
    
    // Update UI
    rpcStatusElement.textContent = 'Disconnected';
    rpcStatusElement.style.color = '#ff6b35';
    rpcButtonElement.textContent = '🌐 Connect to Core Testnet RPC';
    rpcButtonElement.style.background = '';
    rpcButtonElement.disabled = false;
    rpcButtonElement.onclick = connectToRPC;
    
    showNotification('Disconnected from Core Testnet RPC');
}

// Enhanced notification system
function showNotification(message, type = 'info') {
    const notification = document.createElement('div');
    
    let backgroundColor, borderColor;
    switch(type) {
        case 'error':
            backgroundColor = 'rgba(244, 67, 54, 0.9)';
            borderColor = '#f44336';
            break;
        case 'success':
            backgroundColor = 'rgba(76, 175, 80, 0.9)';
            borderColor = '#4caf50';
            break;
        default:
            backgroundColor = 'rgba(0, 0, 0, 0.9)';
            borderColor = 'rgba(255, 255, 255, 0.2)';
    }
    
    notification.style.cssText = `
        position: fixed;
        top: 20px;
        right: 20px;
        background: ${backgroundColor};
        color: white;
        padding: 15px 20px;
        border-radius: 10px;
        z-index: 10000;
        backdrop-filter: blur(10px);
        border: 1px solid ${borderColor};
        animation: slideIn 0.3s ease;
        max-width: 300px;
        word-wrap: break-word;
    `;
    notification.textContent = message;
    
    document.body.appendChild(notification);
    
    const duration = type === 'error' ? 5000 : 3000;
    setTimeout(() => {
        if (notification.parentNode) {
            notification.remove();
        }
    }, duration);
}

// Navigation functions
function showSection(section) {
    document.querySelectorAll('.section').forEach(s => {
        s.style.display = 'none';
        s.classList.remove('active');
    });
    
    document.querySelectorAll('.nav-item').forEach(item => {
        item.classList.remove('active');
    });
    
    if (section === 'home') {
        document.getElementById('home-section').style.display = 'block';
        document.getElementById('home-section').classList.add('active');
    } else if (section === 'apps') {
        document.getElementById('apps-section').style.display = 'block';
        document.getElementById('apps-section').classList.add('active');
    } else {
        showPlaceholder(section);
    }
    
    if (event && event.target) {
        event.target.closest('.nav-item').classList.add('active');
    }
    currentSection = section;
}

function showPlaceholder(section) {
    const container = document.querySelector('.container');
    let placeholder = document.getElementById('placeholder-section');
    
    if (!placeholder) {
        placeholder = document.createElement('div');
        placeholder.id = 'placeholder-section';
        placeholder.className = 'section fade-in';
        container.appendChild(placeholder);
    }
    
    placeholder.innerHTML = `
        <div style="text-align: center; padding: 100px 20px;">
            <div style="font-size: 60px; margin-bottom: 20px;">🚧</div>
            <h2 style="margin-bottom: 15px;">${section.charAt(0).toUpperCase() + section.slice(1)} Section</h2>
            <p style="color: rgba(255, 255, 255, 0.7);">This section is under development</p>
            <button onclick="showSection('home')" style="
                background: linear-gradient(135deg, #ff6b35, #f7931e);
                border: none;
                padding: 12px 24px;
                border-radius: 25px;
                color: white;
                margin-top: 20px;
                cursor: pointer;
                transition: all 0.3s ease;
            " onmouseover="this.style.transform='translateY(-2px)'" onmouseout="this.style.transform='translateY(0)'">
                Back to Home
            </button>
        </div>
    `;
    
    placeholder.style.display = 'block';
    placeholder.classList.add('active');
}

// Profile functions
function copyLink() {
    navigator.clipboard.writeText('https://coretestnet.com/profile/austin_namuye').then(() => {
        showNotification('Profile link copied to clipboard!', 'success');
    });
}

function shareProfile() {
    if (navigator.share) {
        navigator.share({
            title: 'Austin Namuye - Core Testnet Profile',
            url: 'https://coretestnet.com/profile/austin_namuye'
        });
    } else {
        showNotification('Share functionality not available');
    }
}

// App functions
function openApp(appName) {
    showNotification(`Opening ${appName.charAt(0).toUpperCase() + appName.slice(1)} app...`);
    
    if (event && event.target) {
        const appCard = event.target.closest('.app-card, .bottom-card');
        if (appCard) {
            appCard.style.transform = 'scale(0.95)';
            setTimeout(() => {
                appCard.style.transform = '';
            }, 150);
        }
    }
}

// Timer function for daily tokens
function startTokenTimer() {
    setInterval(() => {
        timeRemaining--;
        if (timeRemaining <= 0) {
            timeRemaining = 24 * 3600;
            dailyTokens += Math.floor(Math.random() * 50) + 700;
        }
        updateTokenDisplay();
    }, 1000);
}

function updateTokenDisplay() {
    const hours = Math.floor(timeRemaining / 3600);
    const minutes = Math.floor((timeRemaining % 3600) / 60);
    const seconds = timeRemaining % 60;
    
    const timeElement = document.querySelector('.token-time');
    if (timeElement) {
        timeElement.textContent = `${hours}h ${minutes}m ${seconds}s`;
    }
    
    const tokenElement = document.querySelector('.token-amount');
    if (tokenElement) {
        tokenElement.textContent = `${dailyTokens} CT`;
    }
}

// Utility functions
function goBack() {
    if (currentSection !== 'home') {
        showSection('home');
    } else {
        showNotification('Already at home page');
    }
}

function toggleTheme() {
    document.body.classList.toggle('light-theme');
    showNotification('Theme toggled!', 'success');
}

function showContentScript() {
    showNotification('Content Script feature coming soon!');
}

// Interactive effects
function addInteractiveEffects() {
    document.querySelectorAll('.app-card, .profile-card, .wallet-overview').forEach(card => {
        card.addEventListener('mouseenter', function() {
            this.style.boxShadow = '0 20px 40px rgba(255, 107, 53, 0.3)';
        });
        
        card.addEventListener('mouseleave', function() {
            this.style.boxShadow = '';
        });
    });

    createParticles();
}

function createParticles() {
    const profileCard = document.querySelector('.profile-card');
    if (!profileCard) return;

    setInterval(() => {
        if (currentSection === 'home') {
            const particle = document.createElement('div');
            particle.style.cssText = `
                position: absolute;
                width: 4px;
                height: 4px;
                background: rgba(255, 255, 255, 0.6);
                border-radius: 50%;
                pointer-events: none;
                left: ${Math.random() * profileCard.offsetWidth}px;
                top: ${Math.random() * profileCard.offsetHeight}px;
                animation: float 3s ease-out forwards;
            `;
            profileCard.appendChild(particle);
            setTimeout(() => particle.remove(), 3000);
        }
    }, 500);
}

// Particle animation styles
const styleSheet = document.createElement('style');
styleSheet.textContent = `
    @keyframes float {
        0% { transform: translateY(0); opacity: 0.6; }
        100% { transform: translateY(-50px); opacity: 0; }
    }
    @keyframes slideIn {
        from { transform: translateX(100%); }
        to { transform: translateX(0); }
    }
`;
document.head.appendChild(styleSheet);