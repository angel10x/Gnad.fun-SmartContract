# Test Suite

This directory contains comprehensive test files for the pumpnad.fun contracts using Foundry's Forge testing framework.

## Test Files

- **WMon.t.sol** - Tests for the wrapped Monad token contract
  - Deposit/withdraw functionality
  - Receive/fallback functions
  - Permit type hash
  - Transfer operations

- **Token.t.sol** - Tests for the ERC20 token with permit functionality
  - Minting (single mint restriction)
  - Burning tokens
  - Permit type hash verification
  - Transfer operations

- **BondingCurve.t.sol** - Tests for the bonding curve contract
  - Initialization
  - Reserve queries
  - Buy/sell access control
  - Parameter validation

- **BondingCurveFactory.t.sol** - Tests for the factory contract
  - Factory initialization
  - Bonding curve creation
  - Configuration management
  - Owner functions

- **FeeVault.t.sol** - Tests for the multisig fee vault
  - Withdrawal proposals
  - Multi-signature signing
  - Proposal execution
  - Access control

- **GNad.t.sol** - Tests for the main GNad contract
  - Bonding curve creation
  - Buy operations (market and protected)
  - Sell operations (market and protected)
  - Permit functions
  - Fee handling

## Running Tests

### Run all tests:
```bash
forge test
```

### Run specific test file:
```bash
forge test --match-path test/WMon.t.sol
```

### Run with verbosity:
```bash
forge test -vvv
```

### Run with gas reporting:
```bash
forge test --gas-report
```

### Run specific test function:
```bash
forge test --match-test test_Deposit
```

## Test Coverage

All tests include:
- Happy path scenarios
- Edge cases
- Access control checks
- Error condition testing
- Event emission verification
- State verification

