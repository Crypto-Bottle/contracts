# CryptoBottle Smart Contracts

This repository contains the smart contracts for the CryptoBottle platform, a decentralized application allowing users to create, manage, and trade unique NFT collections called "Cuvées". These NFTs represent bottles that can hold a random amount of cryptocurrencies, bringing an element of surprise to the NFT marketplace.

## Contract Overview

The CryptoBottle contracts are responsible for the creation, randomization, and management of the Cuvées. They interact with various decentralized services, such as Chainlink VRF for provably fair random number generation and smart contract proxies for efficient upgradability.

## Installation

It is recommended to install [`pnpm`](https://pnpm.io) through the `npm` package manager, which comes bundled with [Node.js](https://nodejs.org/en) when you install it on your system. It is recommended to use a Node.js version `>= 20.0.0`.

Once you have `npm` installed, you can run the following both to install and upgrade `pnpm`:

```console
npm install -g pnpm
```

After having installed `pnpm`, simply run:

```console
pnpm install
```

## Configuration Variables

Run `npx hardhat vars set PRIVATE_KEY` to set the private key of your wallet. This allows secure access to your wallet to use with both testnet and mainnet funds during Hardhat deployments.

You can also run `npx hardhat vars setup` to see which other [configuration variables](https://hardhat.org/hardhat-runner/docs/guides/configuration-variables) are available.

## Using a Ledger Hardware Wallet

This template implements the [`hardhat-ledger`](https://hardhat.org/hardhat-runner/plugins/nomicfoundation-hardhat-ledger) plugin. Run `npx hardhat set LEDGER_ACCOUNT` and enter the address of the Ledger account you want to use.

## Contract Verification

Change the contract address to your contract after the deployment has been successful. This works for both testnet and mainnet. You will need to get an API key from [etherscan](https://etherscan.io), [snowtrace](https://snowtrace.io) etc.

**Example:**

```console
npx hardhat verify --network fantomMain --constructor-args arguments.js <YOUR_CONTRACT_ADDRESS>
```

## Foundry

This template repository also includes the [Foundry](https://github.com/foundry-rs/foundry) toolkit as well as the [`@nomicfoundation/hardhat-foundry`](https://hardhat.org/hardhat-runner/docs/advanced/hardhat-and-foundry) plugin.

> If you need help getting started with Foundry, I recommend reading the [📖 Foundry Book](https://book.getfoundry.sh).

### Dependencies

```console
make update
```

or

```console
forge update
```

### Compilation

```console
make build
```

or

```console
forge build
```

### Testing

To run only TypeScript tests:

```console
pnpm test:hh
```

To run only Solidity tests:

```console
pnpm test:forge
```

or

```console
make test-forge
```

To additionally display the gas report, you can run:

```console
make test-gasreport
```