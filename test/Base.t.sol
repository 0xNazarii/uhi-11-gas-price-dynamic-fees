// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// Dependencies
import {Test} from "forge-std/Test.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";

// Types
import {SwapParams, ModifyLiquidityParams} from "v4-core/types/PoolOperation.sol";

// Libraries
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {LPFeeLibrary} from "v4-core/libraries/LPFeeLibrary.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";

// Contracts
import {GasPriceFeesHook} from "../src/GasPriceFeesHook.sol";

/// @notice Deploys v4, two tokens, the hook at 10 gwei and a dynamic fee pool with liquidity
abstract contract Base_Test is Test, Deployers {
    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Gas price the hook is deployed at, which seeds the moving average
    uint256 internal constant INITIAL_GAS_PRICE = 10 gwei;

    /// @dev Small next to the pool's liquidity, so price impact doesn't hide fee differences
    uint256 internal constant SWAP_AMOUNT = 0.00001 ether;

    /*//////////////////////////////////////////////////////////////
                               CONTRACTS
    //////////////////////////////////////////////////////////////*/

    GasPriceFeesHook internal hook;

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        // Deploy PoolManager and routers
        deployFreshManagerAndRouters();

        // Deploy, mint and approve two tokens
        deployMintAndApprove2Currencies();

        // Deploy the hook at 10 gwei to an address with its permission flags set
        address flags = address(uint160(Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG));
        vm.txGasPrice(INITIAL_GAS_PRICE);
        deployCodeTo("GasPriceFeesHook.sol", abi.encode(manager), flags);
        hook = GasPriceFeesHook(flags);

        // Initialize a dynamic fee pool through the PoolManager
        (key,) = initPool(currency0, currency1, hook, LPFeeLibrary.DYNAMIC_FEE_FLAG, SQRT_PRICE_1_1);

        // Add liquidity in [-60, 60] around price 1
        modifyLiquidityRouter.modifyLiquidity(
            key,
            ModifyLiquidityParams({tickLower: -60, tickUpper: 60, liquidityDelta: 100 ether, salt: bytes32(0)}),
            ZERO_BYTES
        );

        // Label the contracts
        vm.label(address(hook), "GasPriceFeesHook");
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Sell SWAP_AMOUNT of token0 for token1 at `gasPrice`, returning the token1 received
    function swapAt(uint256 gasPrice) internal returns (uint256 output) {
        vm.txGasPrice(gasPrice);
        uint256 balanceBefore = currency1.balanceOfSelf();
        swapRouter.swap(
            key,
            SwapParams({
                zeroForOne: true, amountSpecified: -int256(SWAP_AMOUNT), sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            ZERO_BYTES
        );
        output = currency1.balanceOfSelf() - balanceBefore;
    }

    /// @dev Fee the hook returns from beforeSwap at `gasPrice`, without the override flag
    function feeAt(uint256 gasPrice) internal returns (uint24) {
        vm.txGasPrice(gasPrice);
        vm.prank(address(manager));
        (,, uint24 feeWithFlag) = hook.beforeSwap(
            address(swapRouter),
            key,
            SwapParams({
                zeroForOne: true, amountSpecified: -int256(SWAP_AMOUNT), sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            ZERO_BYTES
        );
        assertTrue(feeWithFlag & LPFeeLibrary.OVERRIDE_FEE_FLAG != 0, "Fee should carry the override flag");
        return feeWithFlag & ~LPFeeLibrary.OVERRIDE_FEE_FLAG;
    }
}
