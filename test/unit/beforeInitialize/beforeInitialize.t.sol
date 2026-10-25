// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// Types
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";

// Libraries
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {CustomRevert} from "v4-core/libraries/CustomRevert.sol";
import {LPFeeLibrary} from "v4-core/libraries/LPFeeLibrary.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";

// Contracts
import {GasPriceFeesHook} from "../../../src/GasPriceFeesHook.sol";
import {ImmutableState} from "@uniswap/v4-periphery/src/base/ImmutableState.sol";

// Test
import {Base_Test} from "../../Base.t.sol";

contract GasPriceFeesHook_beforeInitialize is Base_Test {
    using StateLibrary for IPoolManager;

    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_beforeInitialize_AllowsDynamicFeePool() public {
        // Arrange
        PoolKey memory newKey = PoolKey(currency0, currency1, LPFeeLibrary.DYNAMIC_FEE_FLAG, 10, hook);

        // Act
        manager.initialize(newKey, SQRT_PRICE_1_1);

        // Assert
        (uint160 sqrtPriceX96,,,) = manager.getSlot0(newKey.toId());
        assertEq(sqrtPriceX96, SQRT_PRICE_1_1, "Pool should be initialized");
    }

    function test_beforeInitialize_RevertsWhen_StaticFeePool() public {
        // Arrange
        PoolKey memory newKey = PoolKey(currency0, currency1, 3000, 60, hook);

        // Act and Assert: the PoolManager wraps the hook's revert
        vm.expectRevert(
            abi.encodeWithSelector(
                CustomRevert.WrappedError.selector,
                address(hook),
                IHooks.beforeInitialize.selector,
                abi.encodeWithSelector(GasPriceFeesHook.MustUseDynamicFee.selector),
                abi.encodeWithSelector(Hooks.HookCallFailed.selector)
            )
        );
        manager.initialize(newKey, SQRT_PRICE_1_1);
    }

    function test_beforeInitialize_RevertsWhen_CallerIsNotPoolManager() public {
        // Act and Assert
        vm.expectRevert(ImmutableState.NotPoolManager.selector);
        hook.beforeInitialize(address(this), key, SQRT_PRICE_1_1);
    }
}
