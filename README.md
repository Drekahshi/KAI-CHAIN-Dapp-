# KAI CHAIN Smart Contracts

This repository contains the smart contracts for the KAI CHAIN project. It is built using [Hardhat](https://hardhat.org/), a professional development environment for Ethereum and EVM-compatible chains.

## Getting Started

Follow these instructions to set up a local development environment.

### Prerequisites

* [Node.js](https://nodejs.org/en/) (Version 18 or higher recommended)
* [npm](https://www.npmjs.com/) (comes with Node.js) or [Yarn](https://yarnpkg.com/)

### Installation

1.  **Clone the repository:**
    ```shell
    git clone <your-repository-url>
    cd KAI-CHAIN
    ```

2.  **Install dependencies:**
    This project may have conflicting peer dependencies. Use the `--legacy-peer-deps` flag to ensure a smooth installation.
    ```shell
    npm install --legacy-peer-deps
    ```

### Configuration

You will need to create a `.env` file to store sensitive information like your private key and network RPC URLs.

1.  Create a copy of the example environment file:
    ```shell
    cp .env.example .env
    ```

2.  Open the `.env` file and add your details:
    ```
    CORE_TESTNET_URL="YOUR_RPC_URL_HERE"
    PRIVATE_KEY="YOUR_WALLET_PRIVATE_KEY"
    ```

---

## Available Hardhat Tasks

Here are some of the most common tasks you will run during development.

### Compile Contracts

To compile all the smart contracts in the `contracts/` directory:
```shell
npx hardhat compile
