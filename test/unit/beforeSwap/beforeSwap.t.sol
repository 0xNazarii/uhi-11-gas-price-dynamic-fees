// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// Types
import {SwapParams} from "v4-core/types/PoolOperation.sol";

// Libraries
import {TickMath} from "v4-core/libraries/TickMath.sol";

// Contracts
import {ImmutableState} from "@uniswap/v4-periphery/src/base/ImmutableState.sol";

// Test
import {Base_Test} from "../../Base.t.sol";

contract GasPriceFeesHook_beforeSwap is Base_Test {
    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_beforeSwap_ChargesBaseFeeWhen_GasPriceAtAverage() public {
        // Act
        uint24 fee = feeAt(10 gwei);

        // Assert
        assertEq(fee, hook.BASE_FEE(), "Fee should be the base fee");
    }

    function test_beforeSwap_ChargesHalfFeeWhen_GasPriceAboveTenPercent()
        public
    {
        // Act
        uint24 fee = feeAt(11 gwei + 1);

        // Assert
        assertEq(fee, hook.BASE_FEE() / 2, "Fee should be halved");
    }

    function test_beforeSwap_ChargesDoubleFeeWhen_GasPriceBelowTenPercent()
        public
    {
        // Act
        uint24 fee = feeAt(9 gwei - 1);

        // Assert
        assertEq(fee, hook.BASE_FEE() * 2, "Fee should be doubled");
    }

    function test_beforeSwap_ChargesBaseFeeWhen_GasPriceExactlyTenPercentAbove()
        public
    {
        // Act
        uint24 fee = feeAt(11 gwei);

        // Assert
        assertEq(fee, hook.BASE_FEE(), "Fee should be the base fee");
    }

    function test_beforeSwap_ChargesBaseFeeWhen_GasPriceExactlyTenPercentBelow()
        public
    {
        // Act
        uint24 fee = feeAt(9 gwei);

        // Assert
        assertEq(fee, hook.BASE_FEE(), "Fee should be the base fee");
    }

    function test_beforeSwap_LowerFeeGivesMoreOutput() public {
        // Act: same as the lesson, swap at 10, then 4, then 12 gwei
        uint256 baseFeeOutput = swapAt(10 gwei);
        uint256 increasedFeeOutput = swapAt(4 gwei);
        uint256 decreasedFeeOutput = swapAt(12 gwei);

        // Assert
        assertGt(
            decreasedFeeOutput,
            baseFeeOutput,
            "High gas swap should get more than the base fee swap"
        );
        assertGt(
            baseFeeOutput,
            increasedFeeOutput,
            "Base fee swap should get more than the low gas swap"
        );
    }

    function test_beforeSwap_RevertsWhen_CallerIsNotPoolManager() public {
        // Act and Assert
        vm.expectRevert(ImmutableState.NotPoolManager.selector);
        hook.beforeSwap(
            address(this),
            key,
            SwapParams({
                zeroForOne: true,
                amountSpecified: -int256(SWAP_AMOUNT),
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            ZERO_BYTES
        );
    }
}
