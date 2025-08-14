// script.js
document.addEventListener('DOMContentLoaded', function() {
    // Initialize the problem counter
    if (document.querySelector('.problem-list')) {
        document.querySelector('.problem-list').style.counterReset = "problem-counter";
    }
    // Set initial section
    navigateTo('home');
});

// Navigation function
function navigateTo(section) {
    const sections = document.querySelectorAll('.section');
    sections.forEach(sec => sec.classList.remove('active'));
    document.getElementById(`${section}-section`).classList.add('active');

    const navItems = document.querySelectorAll('.nav-item');
    navItems.forEach(item => {
        item.classList.remove('active');
        if (item.dataset.section === section) {
            item.classList.add('active');
        }
    });

    // Animate fade-in for cards in the section
    const cards = document.getElementById(`${section}-section`).querySelectorAll('.section-card, .fade-in');
    cards.forEach((card, index) => {
        setTimeout(() => {
            card.classList.add('fade-in');
        }, 200 * index);
    });
}

function goBack() {
    history.back();
}

function toggleTheme() {
    document.body.classList.toggle('light-theme');
}

function printPage() {
    window.print();
}

function joinRevolution() {
    alert('Thank you for joining the KAI DeFi revolution! Redirecting to signup...');
    // In a real app, redirect to a signup page
}

// Wallet functions
function connectWallet() {
    // Mock wallet connection
    document.getElementById('wallet-status').textContent = 'Wallet connected: 0x1234...abcd';
    document.getElementById('balance-list').style.display = 'block';
    alert('Wallet connected successfully!');
}

// Swap function
function performSwap() {
    alert('Swap executed successfully! (This is a mock transaction)');
}

// App open function
function openApp(appName) {
    alert(`Opening ${appName} app... (This would launch the dApp in a real implementation)`);
}