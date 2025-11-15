# Support Documentation

[中文](./SUPPORT_CN.md)

## Table of Contents

- [Getting Help](#getting-help)
- [Common Issues](#common-issues)
- [Frequently Asked Questions (FAQ)](#frequently-asked-questions-faq)
- [Troubleshooting](#troubleshooting)
- [Reporting Bugs](#reporting-bugs)
- [Feature Requests](#feature-requests)
- [Contributing](#contributing)
- [Contact Information](#contact-information)

## Getting Help

If you need help with GNad.Fun, here are the best ways to get support:

1. **Documentation**: Check the [README.md](./README.md) for comprehensive documentation
2. **Issues**: Search existing issues on GitHub to see if your question has been answered
3. **New Issue**: Create a new issue if you can't find an answer to your question
4. **Discussions**: Use GitHub Discussions for general questions and community help

## Common Issues

### Contract Deployment Issues

**Issue**: Contracts fail to deploy or initialize

**Solutions**:
- Ensure you have sufficient gas for deployment
- Check that all required parameters are provided correctly
- Verify that factory contracts are initialized before use
- Ensure proper contract permissions and ownership

### Transaction Failures

**Issue**: Transactions revert with error messages

**Common Causes**:
- Insufficient balance (WMon or tokens)
- Slippage protection triggered
- Deadline expired
- Insufficient allowance for token spending
- Contract is locked (for bonding curves)

**Solutions**:
- Check your WMon balance before trading
- Increase slippage tolerance if using protected functions
- Use a future deadline (block.timestamp + X)
- Approve tokens before selling operations
- Wait until bonding curve unlocks or check lock status

### Fee Calculation Errors

**Issue**: Fee validation fails

**Solutions**:
- Verify fee amount matches bonding curve configuration
- Check fee denominator and numerator values
- Ensure fee is calculated correctly: `fee >= (amount * denominator) / numerator`

### Permit/Approval Issues

**Issue**: Permit or approval fails

**Solutions**:
- Verify signature parameters (v, r, s) are correct
- Check deadline hasn't expired
- Ensure domain separator matches contract
- Verify nonce is correct

## Frequently Asked Questions (FAQ)

### General Questions

**Q: What is WMon?**
A: WMon is the wrapped version of the native Monad token, providing ERC20 compatibility for trading operations.

**Q: How do bonding curves work?**
A: Bonding curves use a constant product formula (k = x * y) to determine prices. As more tokens are bought, prices increase. Virtual reserves are used for initial price calculation.

**Q: What happens when a bonding curve locks?**
A: When the locked token target is reached, the bonding curve locks and trading stops. The curve can then be listed on a DEX.

**Q: Can I create multiple tokens?**
A: Yes, each call to `createBc` creates a new token and bonding curve pair.

**Q: How are fees calculated?**
A: Fees are calculated based on the bonding curve's fee configuration (denominator/numerator). The fee is taken from the input amount for buys and output amount for sells.

### Trading Questions

**Q: What's the difference between `buy` and `protectBuy`?**
A: `buy` executes immediately at current price. `protectBuy` includes slippage protection and reverts if price moves beyond `amountOutMin`.

**Q: Do I need to approve tokens before selling?**
A: Yes, you need to either:
- Approve tokens using `approve()` function, or
- Use permit-based functions (`sellPermit`, `protectSellPermit`, etc.)

**Q: What is a deadline parameter?**
A: Deadline ensures transaction freshness. It must be a future timestamp (block.timestamp + duration). Transactions with expired deadlines will revert.

**Q: Can I buy exact amounts of tokens?**
A: Yes, use `exactOutBuy` to specify exactly how many tokens you want to receive.

**Q: Can I sell for exact amounts of WMon?**
A: Yes, use `exactOutSell` to specify exactly how much WMon you want to receive.

### Technical Questions

**Q: What Solidity version is used?**
A: Contracts are written in Solidity ^0.8.13

**Q: What testing framework is used?**
A: Foundry is used for testing. See [test/README.md](./test/README.md) for testing information.

**Q: How do virtual reserves differ from real reserves?**
A: Virtual reserves are used for initial price calculation and don't reflect actual balances. Real reserves track actual token balances in the bonding curve contract.

**Q: What happens during DEX listing?**
A: When `listing()` is called, tokens and WMon are transferred to a Uniswap V2 compatible pair, liquidity is provided, and LP tokens are burned.

## Troubleshooting

### Test Failures

If tests are failing:

1. **Check Foundry version**: Ensure you're using a compatible Foundry version
   ```bash
   forge --version
   ```

2. **Update dependencies**: Pull latest dependencies
   ```bash
   forge update
   ```

3. **Clean build**: Clean and rebuild
   ```bash
   forge clean
   forge build
   ```

4. **Run specific test**: Isolate the failing test
   ```bash
   forge test --match-test testName
   ```

5. **Verbose output**: Get more information
   ```bash
   forge test -vvv
   ```

### Compilation Errors

If contracts won't compile:

1. **Check Solidity version**: Ensure version matches (^0.8.13)
2. **Verify imports**: Check all import paths are correct
3. **Install dependencies**: Ensure all dependencies are installed
   ```bash
   forge install
   ```
4. **Check remappings**: Verify `remappings.txt` is correct

### Runtime Errors

If transactions fail at runtime:

1. **Read error messages**: Error messages are designed to be descriptive
2. **Check event logs**: Events can provide additional context
3. **Verify state**: Ensure contracts are in expected state
4. **Check permissions**: Verify caller has required permissions
5. **Gas estimation**: Ensure sufficient gas is provided

## Reporting Bugs

When reporting bugs, please include:

1. **Description**: Clear description of the issue
2. **Steps to Reproduce**: Detailed steps to reproduce the bug
3. **Expected Behavior**: What should happen
4. **Actual Behavior**: What actually happens
5. **Environment**:
   - Solidity version
   - Foundry version (if applicable)
   - Network (if applicable)
6. **Error Messages**: Full error messages or logs
7. **Code Samples**: Minimal code to reproduce (if applicable)
8. **Screenshots**: If visual issues (if applicable)

### Bug Report Template

```markdown
## Bug Description
Brief description of the bug

## Steps to Reproduce
1. Step one
2. Step two
3. Step three

## Expected Behavior
What should happen

## Actual Behavior
What actually happens

## Environment
- Solidity Version: 
- Foundry Version: 
- Network: 

## Error Messages
Paste error messages here

## Additional Context
Any additional context or information
```

## Feature Requests

We welcome feature requests! When submitting:

1. **Clear Description**: Describe the feature clearly
2. **Use Case**: Explain why this feature would be useful
3. **Potential Implementation**: If you have ideas, share them
4. **Alternatives**: Discuss any alternatives you've considered

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

For more details, see contribution guidelines (if available).

## Contact Information

### 📬 Say hello

- [Whatsapp](https://wa.me/16286666724?text=Hello%20there)
- [Telegram](https://t.me/angel001000010100)
- [Discord](https://discordapp.com/users/1114372741672488990)
- [Email](mailto:10xAngel.dev@gmail.com?subject=Hello%20Angel&body=Hi%20Angel%2C%20I%20found%20you%20on%20GitHub!)

## Additional Resources

- [README.md](./README.md) - Main documentation
- [README_CN.md](./README_CN.md) - Chinese documentation
- [test/README.md](./test/README.md) - Testing documentation
- [GitHub Repository](https://github.com/angel10x/Gnad.fun-SmartContract) - Source code

---

**Note**: For security vulnerabilities, please use responsible disclosure and contact maintainers privately rather than opening a public issue.

