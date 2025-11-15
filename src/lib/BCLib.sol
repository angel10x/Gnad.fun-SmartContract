// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IBondingCurve} from "../interfaces/IBondingCurve.sol";
import {IBondingCurveFactory} from "../interfaces/IBondingCurveFactory.sol";
import "../errors/CustomErrors.sol" as CustomErrors;

/**
 * @title BCLib
 * @dev Library for handling bonding curve calculations and related utilities
 * Contains functions for calculating amounts, fees, and managing curve data
 */

library BCLib {
    /**
     * @notice Calculates the output amount for a given input in the bonding curve
     * @dev Uses the formula: amountOut = reserveOut - (k / (reserveIn + amountIn)) - 1
     * The -1 is added to handle floating point precision issues
     * @param amountIn Amount of tokens being input
     * @param reserveIn Current reserve of input token
     * @param reserveOut Current reserve of output token
     * @return amountOut Amount of tokens to be output
     */
    function getAmountOut(uint256 amountIn, uint256 k, uint256 reserveIn, uint256 reserveOut)
        internal
        pure
        returns (uint256 amountOut)
    {
        require(amountIn > 0 && reserveIn > 0 && reserveOut > 0, CustomErrors.INVALID_INPUT_BC_LIBRARY);

        uint256 newReserveIn = reserveIn + amountIn;

        // Use newReserveIn - 1 to round up when dividing
        uint256 newReserveOut = (k + newReserveIn - 1) / newReserveIn;

        require(newReserveOut < reserveOut, CustomErrors.INSUFFICIENT_BC_LIQUIDITY);
        amountOut = reserveOut - newReserveOut;
    }

    /**
     * @notice Calculates the required input amount for a desired output amount
     * @dev Uses inverse bonding curve formula and adds 1 to handle precision
     * @param amountOut Desired amount of output tokens
     * @param reserveIn Current reserve of input token
     * @param reserveOut Current reserve of output token
     * @return amountIn Required amount of input tokens
     */
    function getAmountIn(uint256 amountOut, uint256 k, uint256 reserveIn, uint256 reserveOut)
        internal
        pure
        returns (uint256 amountIn)
    {
        require(amountOut <= reserveOut, CustomErrors.INVALID_AMOUNT_OUT);

        uint256 newReserveOut = reserveOut - amountOut;

        uint256 numerator = (k + newReserveOut - 1) / newReserveOut;
        amountIn = numerator - reserveIn;

        return amountIn;
    }

    /**
     * @notice Calculates fee and adjusted output amount for a given curve
     * @param bc Address of the bonding curve contract
     * @param amountOut Original output amount before fee
     * @return fee Fee amount to be deducted
     * @return adjustedAmountOut Final output amount after fee deduction
     */
    function getAmountAndFee(address bc, uint256 amountOut)
        internal
        view
        returns (uint256 fee, uint256 adjustedAmountOut)
    {
        (uint8 denominator, uint16 numerator) = IBondingCurve(bc).getFeeConfig();

        fee = getFeeAmount(amountOut, denominator, numerator);
        adjustedAmountOut = amountOut - fee;
    }

    /**
     * @notice Calculates fee amount based on configured fee parameters
     * @param amount Base amount to calculate fee from
     * @param denominator Fee denominator
     * @param numerator Fee numerator
     * @return fee Calculated fee amount
     */
    function getFeeAmount(uint256 amount, uint8 denominator, uint16 numerator) internal pure returns (uint256 fee) {
        fee = (amount * denominator) / numerator;
    }

    /**
     * @notice Retrieves all relevant data for a bonding curve from factory
     * @param factory Address of the bonding curve factory
     * @param token Token address associated with the curve
     * @return bc Address of the bonding curve
     * @return virtualNative Virtual NAD reserve
     * @return virtualToken Virtual token reserve
     * @return k Constant product k
     */
    function getBcData(address factory, address token)
        internal
        view
        returns (address bc, uint256 virtualNative, uint256 virtualToken, uint256 k)
    {
        bc = getBc(factory, token);
        (virtualNative, virtualToken) = getVirtualReserves(bc);
        k = getK(bc);
    }

    /**
     * @notice Retrieves curve data directly from curve address
     * @param bc Address of the bonding curve
     * @return virtualNative Virtual NAD reserve
     * @return virtualToken Virtual token reserve
     * @return k Constant product k
     */
    function getBcData(address bc) internal view returns (uint256 virtualNative, uint256 virtualToken, uint256 k) {
        (virtualNative, virtualToken) = getVirtualReserves(bc);
        k = getK(bc);
    }

    /**
     * @notice Gets fee configuration from a bonding curve
     * @param bc Address of the bonding curve
     * @return Fee denominator and numerator
     */
    function getFeeConfig(address bc) internal view returns (uint8, uint16) {
        return IBondingCurve(bc).getFeeConfig();
    }

    /**
     * @notice Gets bc address from factory for a given token
     * @param factory Address of the factory contract
     * @param token Token address to look up
     * @return bc Address of the corresponding bonding curve
     */
    function getBc(address factory, address token) internal view returns (address bc) {
        bc = IBondingCurveFactory(factory).getBc(token);
        return bc;
    }

    /**
     * @notice Retrieves virtual reserves from a bonding curve
     * @param bc Address of the bonding curve
     * @return virtualNative Virtual NAD reserve
     * @return virtualToken Virtual token reserve
     */
    function getVirtualReserves(address bc) internal view returns (uint256 virtualNative, uint256 virtualToken) {
        (virtualNative, virtualToken) = IBondingCurve(bc).getVirtualReserves();
    }

    /**
     * @notice Gets the constant product k from a bonding curve
     * @param bc Address of the bonding curve
     * @return k Constant product value
     */
    function getK(address bc) internal view returns (uint256 k) {
        k = IBondingCurve(bc).getK();
    }
}
