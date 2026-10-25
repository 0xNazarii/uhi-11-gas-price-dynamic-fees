// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// Types
import {SwapParams} from "v4-core/types/PoolOperation.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";

// Libraries
import {TickMath} from "v4-core/libraries/TickMath.sol";

// Contracts
import {ImmutableState} from "@uniswap/v4-periphery/src/base/ImmutableState.sol";

// Test
import {Base_Test} from "../../Base.t.sol";

contract GasPriceFeesHook_afterSwap is Base_Test {
    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_afterSwap_KeepsAverageWhen_GasPriceAtAverage() public {
        // Act
        swapAt(10 gwei);

        // Assert
        assertEq(hook.movingAverageGasPrice(), 10 gwei, "Average should stay at 10 gwei");
        assertEq(hook.movingAverageGasPriceCount(), 2, "Count should be 2");
    }

    function test_afterSwap_UpdatesMovingAverage() public {
        // Act and Assert: same sequence as the lesson
        swapAt(10 gwei);
        swapAt(4 gwei);
        assertEq(hook.movingAverageGasPrice(), 8 gwei, "Average should be (10 + 10 + 4) / 3 = 8 gwei");
        assertEq(hook.movingAverageGasPriceCount(), 3, "Count should be 3");

        swapAt(12 gwei);
        assertEq(hook.movingAverageGasPrice(), 9 gwei, "Average should be (10 + 10 + 4 + 12) / 4 = 9 gwei");
        assertEq(hook.movingAverageGasPriceCount(), 4, "Count should be 4");
    }

    function test_afterSwap_RevertsWhen_CallerIsNotPoolManager() public {
        // Act and Assert
        vm.expectRevert(ImmutableState.NotPoolManager.selector);
        hook.afterSwap(
            address(this),
            key,
            SwapParams({
                zeroForOne: true, amountSpecified: -int256(SWAP_AMOUNT), sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            BalanceDelta.wrap(0),
            ZERO_BYTES
        );
    }
}
