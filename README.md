[简体中文](./README_CN.md)

# GNad.Fun Smart Contract

## Table of Contents

- [System Overview](#system-overview)
- [Contract Architecture](#contract-architecture)
- [Key Components](#key-components)
- [Main Functions](#main-functions)
- [Events](#events)
- [Usage Notes](#usage-notes)
- [Testing](#testing)
- [Development Information](#development-information)

## System Overview

gnad.fun is a smart contract system for creating and managing bonding curve-based tokens on the Monad blockchain. It enables creators to mint new tokens with associated bonding curves and allows traders to buy and sell these tokens through a centralized endpoint. The system uses a combination of bonding curves and automated market makers to provide liquidity and price discovery for newly created tokens.

## Contract Architecture

### Core Contracts

1. **GNad.sol**

   - Central contract that coordinates all system operations
   - Handles token creation, buying, and selling operations
   - Manages interactions with WMon (Wrapped Monad) and fee collection
   - Implements various safety checks and slippage protection
   - Supports EIP-2612 permit functionality for gasless approvals

2. **BondingCurve.sol**

   - Implements the bonding curve logic using constant product formula
   - Calculates token prices based on virtual and real reserves
   - Manages token reserves and liquidity
   - Handles buy/sell operations with locked token mechanism
   - Supports DEX listing when target is reached

3. **BondingCurveFactory.sol**

   - Deploys new bonding curve contracts
   - Maintains registry of created curves
   - Ensures standardization of curve parameters
   - Manages configuration (fees, virtual reserves, target tokens)

4. **WMon.sol**
   - Wrapped Monad token implementation
   - Provides ERC20 interface for native Monad tokens
   - Enables deposit/withdraw functionality
   - Supports EIP-2612 permit

### Supporting Contracts

5. **FeeVault.sol**

   - Collects and manages trading fees
   - Implements multisig withdrawal mechanism
   - Requires multiple signatures for withdrawals
   - Provides secure fee management

6. **Token.sol**

   - Standard ERC20 implementation for created tokens
   - Includes ERC20Permit for gasless approvals
   - Single mint restriction (can only mint once)
   - Burn functionality for token holders

### Libraries

- **lib/BCLib.sol**
  - Bonding curve calculation functions
  - Amount in/out calculations
  - Fee calculation utilities

- **lib/Transfer.sol**
  - Safe native token transfer utilities
  - Handles transfer failures gracefully

### Interfaces

- Defines contract interfaces for all major contracts
- Ensures proper contract interaction
- Facilitates type safety and integration

### Errors

- Centralizes error definitions as string constants
- Provides clear error messages
- Improves debugging experience

## Key Components

| Component           | Description                                                                                |
| ------------------- | ------------------------------------------------------------------------------------------ |
| Creator             | Initiates the creation of new tokens and bonding curves                                   |
| Trader              | Interacts with the system to buy and sell tokens                                           |
| GNad                | Main contract handling bonding curve creation, buying, and selling                        |
| WMon                | Wrapped Monad token used for transactions                                                  |
| BondingCurveFactory | Deploys new bonding curve contracts                                                        |
| BondingCurve        | Manages token supply and price calculations using constant product formula                |
| Token               | Standard ERC20 token contract deployed for each new coin                                   |
| DEX                 | External decentralized exchange (Uniswap V2 compatible) for token trading after listing   |
| FeeVault            | Repository for accumulated trading fees; multisig-controlled withdrawals                   |

## Main Functions

### Create Functions

- `createBc`: Creates a new token and its associated bonding curve
  - Can optionally perform an initial buy during creation
  - Returns bonding curve address, token address, and initial reserves

### Buy Functions

| Function      | Description                                           |
| ------------- | ----------------------------------------------------- |
| `buy`         | Market buy tokens at the current bonding curve price  |
| `protectBuy`  | Buys tokens with slippage protection                  |
| `exactOutBuy` | Buys an exact amount of tokens from a bonding curve   |

### Sell Functions

| Function            | Description                                                              |
| ------------------- | ------------------------------------------------------------------------ |
| `sell`              | Market sells tokens at the current bonding curve price                   |
| `sellPermit`        | Market sells tokens at the current bonding curve price with permit      |
| `protectSell`       | Sells tokens with slippage protection                                   |
| `protectSellPermit` | Sells tokens with slippage protection with permit                       |
| `exactOutSell`      | Sells tokens for an exact amount of native on the bonding curve         |
| `exactOutSellPermit`| Sells tokens for an exact amount of native on the bonding curve with permit |

### Utility Functions

- `getBcData`: Retrieves data about a specific bonding curve (address, virtual reserves, k)
- `getAmountOut`: Calculates the output amount for a given input
- `getAmountIn`: Calculates the input amount required for a desired output
- `getFeeVault`: Returns the address of the fee vault

## Events

### GNad Events

```solidity
event GNadCreate();
event GNadBuy();
event GNadSell();
```

### BondingCurve Events

```solidity
event Buy(
    address indexed sender,
    address indexed token,
    uint256 amountIn,
    uint256 amountOut
);

event Sell(
    address indexed sender,
    address indexed token,
    uint256 amountIn,
    uint256 amountOut
);

event Lock(address indexed token);
event Sync(
    address indexed token,
    uint256 reserveWNative,
    uint256 reserveToken,
    uint256 virtualWNative,
    uint256 virtualToken
);

event Listing(
    address indexed curve,
    address indexed token,
    address indexed pair,
    uint256 listingWNativeAmount,
    uint256 listingTokenAmount,
    uint256 burnLiquidity
);
```

### Factory Events

```solidity
event Create(
    address indexed creator,
    address indexed bc,
    address indexed token,
    string tokenURI,
    string name,
    string symbol,
    uint256 virtualNative,
    uint256 virtualToken
);
```

## Usage Notes

- ⏰ **Deadline parameter**: Ensures transaction freshness in all trading functions
- 🔐 **Token approvals**: Some functions require pre-approval of token spending
- 💱 **WMon**: All transactions use WMon (Wrapped Monad) tokens
- 📝 **EIP-2612 permit**: Gasless approvals available for buy/sell operations
- 🛡️ **Slippage protection**: Implemented in `protectBuy` and `protectSell` functions
- 🔒 **Locked tokens**: Bonding curves lock when target token amount is reached
- 📊 **Virtual reserves**: Used for price calculation, separate from real reserves
- 🏭 **DEX listing**: Automatic listing on DEX when locked token target is reached

## Testing

The project includes comprehensive test coverage using Foundry. To run tests:

```bash
# Run all tests
forge test

# Run with verbose output (shows console.log)
forge test -vv

# Run specific test file
forge test --match-path test/WMon.t.sol

# Run with gas reporting
forge test --gas-report
```

See [test/README.md](test/README.md) for more testing information.

## Development Information

This smart contract system is designed to create and manage bonding curve-based tokens on the Monad blockchain. The system uses:

- **Solidity**: ^0.8.13
- **Foundry**: For development and testing
- **OpenZeppelin**: For ERC20 and ERC20Permit implementations
- **Uniswap V2**: For DEX integration after listing

### Key Features

- Constant product bonding curve formula
- Virtual and real reserve management
- Multisig fee vault
- Gasless approvals via EIP-2612
- Automatic DEX listing mechanism
- Comprehensive test coverage

### Project Structure

```
src/
├── GNad.sol                 # Main contract
├── BondingCurve.sol         # Bonding curve implementation
├── BondingCurveFactory.sol  # Factory for creating curves
├── WMon.sol                 # Wrapped Monad token
├── Token.sol                # ERC20 token implementation
├── FeeVault.sol             # Multisig fee vault
├── lib/                     # Utility libraries
│   ├── BCLib.sol           # Bonding curve calculations
│   └── Transfer.sol        # Safe transfer utilities
├── interfaces/              # Contract interfaces
└── errors/                  # Error definitions

test/
└── *.t.sol                  # Test files
```

📌 For questions or support, please open an issue in the GitHub repository.

📖 Need help? Check out my [Support Guide](./SUPPORT.md)
