// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

interface IBondingCurve {
    function initialize(
        address token,
        uint256 virtualWNative,
        uint256 virtualToken,
        uint256 k,
        uint256 targetWNative,
        uint8 feeDenominator,
        uint16 feeNumerator
    ) external;
}