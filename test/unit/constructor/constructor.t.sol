// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// Test
import {Base_Test} from "../../Base.t.sol";

contract GasPriceFeesHook_constructor is Base_Test {
    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_constructor_SeedsMovingAverageWithDeployGasPrice()
        public
        view
    {
        // Assert
        assertEq(
            hook.movingAverageGasPrice(),
            INITIAL_GAS_PRICE,
            "Average should be the deploy gas price"
        );
        assertEq(
            hook.movingAverageGasPriceCount(),
            1,
            "Deploy should count as one sample"
        );
    }
}
