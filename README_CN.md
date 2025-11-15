[En](./README.md)

# GNad.Fun 智能合约

## 目录

- [系统概述](#系统概述)
- [合约架构](#合约架构)
- [核心组件](#核心组件)
- [主要功能](#主要功能)
- [事件](#事件)
- [使用说明](#使用说明)
- [测试](#测试)
- [开发信息](#开发信息)

## 系统概述

gnad.fun 是一个在 Monad 区块链上创建和管理基于债券曲线的代币的智能合约系统。它使创建者能够铸造新的代币并关联债券曲线，允许交易者通过集中端点买卖这些代币。该系统使用债券曲线和自动化做市商的组合为新创建的代币提供流动性和价格发现。

## 合约架构

### 核心合约

1. **GNad.sol**

   - 协调所有系统操作的中心合约
   - 处理代币创建、买卖操作
   - 管理与 WMon（包装 Monad）和费用收集的交互
   - 实现各种安全检查和滑点保护
   - 支持 EIP-2612 permit 功能以实现无 gas 授权

2. **BondingCurve.sol**

   - 使用恒定乘积公式实现债券曲线逻辑
   - 基于虚拟和真实储备计算代币价格
   - 管理代币储备和流动性
   - 处理带锁定代币机制的买卖操作
   - 支持达到目标后在 DEX 上架

3. **BondingCurveFactory.sol**

   - 部署新的债券曲线合约
   - 维护已创建曲线的注册表
   - 确保曲线参数的标准化
   - 管理配置（费用、虚拟储备、目标代币）

4. **WMon.sol**
   - 包装 Monad 代币实现
   - 为原生 Monad 代币提供 ERC20 接口
   - 启用存款/提取功能
   - 支持 EIP-2612 permit

### 支持合约

5. **FeeVault.sol**

   - 收集和管理交易费用
   - 实现多签提取机制
   - 提取需要多个签名
   - 提供安全的费用管理

6. **Token.sol**

   - 标准 ERC20 实现用于创建的代币
   - 包含 ERC20Permit 以实现无 gas 授权
   - 单一铸造限制（只能铸造一次）
   - 代币持有者的销毁功能

### 库文件

- **lib/BCLib.sol**
  - 债券曲线计算函数
  - 金额输入/输出计算
  - 费用计算工具

- **lib/Transfer.sol**
  - 安全的原生代币转账工具
  - 优雅地处理转账失败

### 接口

- 定义所有主要合约的接口
- 确保合约正确交互
- 促进类型安全和集成

### 错误处理

- 将错误定义集中为字符串常量
- 提供清晰的错误消息
- 改善调试体验

## 核心组件

| 组件                | 描述                                                         |
| ------------------- | ------------------------------------------------------------ |
| Creator（创建者）   | 发起新代币和债券曲线的创建                                   |
| Trader（交易者）    | 与系统交互以买卖代币                                         |
| GNad                | 处理债券曲线创建、买卖的主合约                               |
| WMon                | 用于交易的包装 Monad 代币                                    |
| BondingCurveFactory | 部署新的债券曲线合约                                         |
| BondingCurve        | 使用恒定乘积公式管理代币供应和价格计算                       |
| Token               | 为每个新代币部署的标准 ERC20 代币合约                        |
| DEX                 | 上架后用于代币交易的外部去中心化交易所（兼容 Uniswap V2）    |
| FeeVault            | 累积交易费用的存储库；多签控制的提取                         |

## 主要功能

### 创建功能

- `createBc`: 创建新代币及其关联的债券曲线
  - 可以在创建期间选择性地执行初始购买
  - 返回债券曲线地址、代币地址和初始储备

### 买入功能

| 函数        | 描述                                   |
| ----------- | -------------------------------------- |
| `buy`       | 按当前债券曲线价格市场买入代币         |
| `protectBuy`| 带滑点保护的买入代币                   |
| `exactOutBuy`| 从债券曲线买入精确数量的代币          |

### 卖出功能

| 函数                | 描述                                                       |
| ------------------- | ---------------------------------------------------------- |
| `sell`              | 按当前债券曲线价格市场卖出代币                             |
| `sellPermit`        | 使用 permit 按当前债券曲线价格市场卖出代币                 |
| `protectSell`       | 带滑点保护的卖出代币                                       |
| `protectSellPermit` | 带滑点保护和使用 permit 的卖出代币                         |
| `exactOutSell`      | 按债券曲线卖出代币换取精确数量的原生代币                   |
| `exactOutSellPermit`| 使用 permit 按债券曲线卖出代币换取精确数量的原生代币      |

### 工具函数

- `getBcData`: 获取特定债券曲线的数据（地址、虚拟储备、k）
- `getAmountOut`: 计算给定输入的输出金额
- `getAmountIn`: 计算所需输出所需的输入金额
- `getFeeVault`: 返回费用金库的地址

## 事件

### GNad 事件

```solidity
event GNadCreate();
event GNadBuy();
event GNadSell();
```

### BondingCurve 事件

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

### Factory 事件

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

## 使用说明

- ⏰ **截止时间参数**: 确保所有交易功能的交易新鲜度
- 🔐 **代币授权**: 某些功能需要预先授权代币支出
- 💱 **WMon**: 所有交易都使用 WMon（包装 Monad）代币
- 📝 **EIP-2612 permit**: 买卖操作可使用无 gas 授权
- 🛡️ **滑点保护**: 在 `protectBuy` 和 `protectSell` 函数中实现
- 🔒 **锁定代币**: 债券曲线在达到目标代币数量时锁定
- 📊 **虚拟储备**: 用于价格计算，与真实储备分开
- 🏭 **DEX 上架**: 达到锁定代币目标时自动在 DEX 上架

## 测试

该项目使用 Foundry 进行了全面的测试覆盖。运行测试：

```bash
# 运行所有测试
forge test

# 运行详细输出（显示 console.log）
forge test -vv

# 运行特定测试文件
forge test --match-path test/WMon.t.sol

# 运行 gas 报告
forge test --gas-report
```

更多测试信息请参见 [test/README.md](test/README.md)。

## 开发信息

该智能合约系统旨在在 Monad 区块链上创建和管理基于债券曲线的代币。系统使用：

- **Solidity**: ^0.8.13
- **Foundry**: 用于开发和测试
- **OpenZeppelin**: 用于 ERC20 和 ERC20Permit 实现
- **Uniswap V2**: 用于上架后的 DEX 集成

### 核心特性

- 恒定乘积债券曲线公式
- 虚拟和真实储备管理
- 多签费用金库
- 通过 EIP-2612 实现无 gas 授权
- 自动 DEX 上架机制
- 全面的测试覆盖

### 项目结构

```
src/
├── GNad.sol                 # 主合约
├── BondingCurve.sol         # 债券曲线实现
├── BondingCurveFactory.sol  # 创建曲线的工厂
├── WMon.sol                 # 包装 Monad 代币
├── Token.sol                # ERC20 代币实现
├── FeeVault.sol             # 多签费用金库
├── lib/                     # 工具库
│   ├── BCLib.sol            # 债券曲线计算
│   └── Transfer.sol         # 安全转账工具
├── interfaces/              # 合约接口
└── errors/                  # 错误定义

test/
└── *.t.sol                  # 测试文件
```

### 工作流程

1. **创建代币**: 用户通过 `createBc` 创建新代币和债券曲线
2. **买卖交易**: 交易者通过 `buy`/`sell` 函数在债券曲线上交易
3. **达到目标**: 当代币储备达到锁定目标时，债券曲线自动锁定
4. **DEX 上架**: 锁定后可通过 `listing` 函数在 DEX 上架

### 安全特性

- 多签费用管理
- 滑点保护机制
- 截止时间验证
- 访问控制修饰符
- 安全的数学运算

### 部署说明

1. 部署 WMon 合约
2. 部署 FeeVault 合约（配置多签所有者）
3. 部署 BondingCurveFactory 合约
4. 部署 GNad 合约并初始化
5. 配置工厂参数（费用、虚拟储备等）

📌 如有问题或需要支持，请在 GitHub 仓库中提交 issue。

📖 需要帮助？请查看我的 [支持指南](./SUPPORT_CN.md)