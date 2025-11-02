<div align="center">
  <img src="./assets/ccrt-logo.svg" alt="CCRT Logo" width="210"/>

# 🔄 CCRT — Cross-Chain Rebase Token Protocol

**A unified, rebase-aware token that maintains yield, principal, and state across chains.**  
Built with **Solidity**, powered by **Chainlink CCIP**, deployed across **multi-chain networks**.

[![GitHub Stars](https://img.shields.io/github/stars/wasim007choudhary/Cross-Chain-Rebase-Protocol?style=social)](https://github.com/wasim007choudhary/Cross-Chain-Rebase-Protocol/stargazers)
[![GitHub Forks](https://img.shields.io/github/forks/wasim007choudhary/Cross-Chain-Rebase-Protocol?style=social)](https://github.com/wasim007choudhary/Cross-Chain-Rebase-Protocol/network/members)
[![GitHub Issues](https://img.shields.io/github/issues/wasim007choudhary/Cross-Chain-Rebase-Protocol)](https://github.com/wasim007choudhary/Cross-Chain-Rebase-Protocol/issues)

[![Solidity](https://img.shields.io/badge/solidity-^0.8.20-blue.svg?logo=ethereum)](https://soliditylang.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![Powered by CCIP](https://img.shields.io/badge/Powered%20By-Chainlink%20CCIP-blue?logo=chainlink)](https://chain.link/cross-chain)

</div>

---

## 🌉 **Why CCRT Exists**

Most multi-chain tokens **break** rebasing logic when bridged — because bridges only move raw balances.

**CCRT fixes that.**  
When bridging across chains, CCRT preserves:

| Property | Preserved Cross-Chain? | How |
|--------|:-----------------------:|----|
| Principal (original deposit) | ✅ | Stored + synced during burn/mint |
| Rebased balance | ✅ | Calculated dynamically |
| User-specific interest rate | ✅ | Packed + sent inside CCIP payload |

**Result:** A token that **keeps compounding correctly** no matter which chain it lives on.

---


### 🔍 Key Design Notes

| Chain | Components | Abilities |
|------|------------|-----------|
| **Source Chain** | `CCRVault`, `CCRToken`, `CCRebaseTokenPool` | ✅ Mint, ✅ Burn, ✅ Rebase, ✅ **Redeem collateral** |
| **Destination Chains** | `CCRToken`, `CCRebaseTokenPool` | ✅ Mint (via CCIP), ✅ Burn (return to source), ❌ **No collateral redemption** |

**Why?**  
Collateral must remain *consolidated on a single chain* to avoid:
- Over-redemption attacks
- Collateral mis-accounting
- Multi-chain insolvency

---

## 💡 Core Components

| Contract | Role |
|---------|------|
| `CCRToken` | The rebase-aware ERC20 token |
| `CCRebaseTokenPool` | Handles cross-chain burn/mint via Chainlink CCIP |
| `CCRVault` | Accepts native deposits → mints rebasing principal and will only be deployed in the source chain by architecture logic |
| Bridging Scripts | Automate cross-chain messaging and fee handling |
| Pool Config Scripts | Scripts for Bridging Token Cross Chain |

---

## ⚙️ Install & Build

```bash
git clone https://github.com/wasim007choudhary/Cross-Chain-Rebase-Protocol
cd Cross-Chain-Rebase-Protocol
forge install
forge build
```

---

## 🚀 Deploy (Local / Testnet)

Use Foundry scripts:

forge script script/DeployTokenAndPool.s.sol:DeployTokenAndPool --rpc-url <RPC> --broadcast
forge script script/DeployVault.s.sol:DeployVault --rpc-url <RPC> --broadcast --sig "run(address)" <CCRT_TOKEN>

## 🌉 Bridge Tokens Cross-Chain

forge script script/TokenBridgingScript.s.sol:TokenBridgingScript \
  --rpc-url <SOURCE_RPC> \
  --broadcast \
  --sig "run(address,uint64,address,uint256,address,address)" \
  <receiver> <destChainSelector> <tokenAddress> <amount> <LINK> <Router>

## 💰 Deposit / Redeem Yield

// Deposit ETH → receive rebasing CCRT
vault.deposit{value: 1 ether}();

// Redeem max balance
vault.redeem(type(uint256).max);

## 🧪 Testing

forge test -vv

---

## 🤝 Connect

| Link | Profile |
|------|---------|
| LinkedIn | https://www.linkedin.com/in/wasim-007-choudhary/ |
| GitHub | https://github.com/wasim007choudhary |

---

## 👨‍💻 Author

`Wasim Choudhary`

Builder of minimalistic, trustless financial primitives on Ethereum.

---

## 📜 License

This project is licensed under the MIT License.

MIT
© 2025 Wasim Choudhary