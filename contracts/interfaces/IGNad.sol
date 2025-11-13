// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

interface IGNad {
    event NadFunCreate();
    event NadFunBuy();
    event NadFunSell();

    function createCurve(
        address creator,
        string memory name,
        string memory symbol,
        string memory tokenURI,
        uint256 amountIn,
        uint256 fee
    )
        external
        payable
        returns (address curve, address token, uint256 virtualNative, uint256 virtualToken, uint256 amountOut);

    function buy(uint256 amountIn, uint256 fee, address token, address to, uint256 deadline) external payable;

    function protectBuy(
        uint256 amountIn,
        uint256 amountOutMin,
        uint256 fee,
        address token,
        address to,
        uint256 deadline
    ) external payable;

    function exactOutBuy(uint256 amountInMax, uint256 amountOut, address token, address to, uint256 deadline)
        external
        payable;

    function sell(uint256 amountIn, address token, address to, uint256 deadline) external;

    function sellPermit(
        uint256 amountIn,
        address token,
        address from,
        address to,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function protectSell(uint256 amountIn, uint256 amountOutMin, address token, address to, uint256 deadline)
        external;

    function protectSellPermit(
        uint256 amountIn,
        uint256 amountOutMin,
        address token,
        address from,
        address to,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function exactOutSell(uint256 amountInMax, uint256 amountOut, address token, address to, uint256 deadline)
        external
        payable;

    function exactOutSellPermit(
        uint256 amountInMax,
        uint256 amountOut,
        address token,
        address from,
        address to,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable;

    function getCurveData(address _factory, address token)
        external
        view
        returns (address curve, uint256 virtualNative, uint256 virtualToken, uint256 k);

    function getCurveData(address curve)
        external
        view
        returns (uint256 virtualNative, uint256 virtualToken, uint256 k);

    function getAmountOut(uint256 amountIn, uint256 k, uint256 reserveIn, uint256 reserveOut)
        external
        pure
        returns (uint256 amountOut);

    function getAmountIn(uint256 amountOut, uint256 k, uint256 reserveIn, uint256 reserveOut)
        external
        pure
        returns (uint256 amountIn);

    function getFeeVault() external view returns (address feeVault);
}