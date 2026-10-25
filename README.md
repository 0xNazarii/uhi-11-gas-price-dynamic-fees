# Gas price based dynamic fees

A really simple dynamic fees hook

The hook keeps a moving average of the gas price onchain and charges swap fees based on how the current gas price compares to it:

| gas price vs average | fee |
|---|---|
| more than 10% above | 0.25% (half) |
| within ±10% | 0.5% (`BASE_FEE`) |
| more than 10% below | 1% (double) |

> This is not production ready by any means. It is a PoC.

### Design

1. how do we track the average gas price?

the hook can only see transactions that call into it, so it updates the average every time it runs: once in the constructor, and after every swap (`afterSwap`)

```
New Average = ((Old Average * # of Txns Tracked) + Current Gas Price) / (# of Txns Tracked + 1)
```

for more accurate tracking you'd enable every hook function and update the average in each of them - we only do it where it matters for now

2. why would anyone pay a higher gas price for a lower fee?

when gas is high, swappers are already paying a lot to get included, so we charge them less. when gas is cheap, we charge more

a real version would need some financial modelling, so that nobody can bump their gas price just to pay a lower total cost than swapping at the base fee

---

### dynamic fees in v4

every pool has an `lpFee` in its `Slot0`. normally it's fixed when the pool is initialized, but a dynamic fee pool lets its hook change it

there are two ways to do that:

1. `poolManager.updateDynamicLPFee(key, newFee)` - stores a new fee for the pool. good for fees that change once per block or less often
2. return an override fee from `beforeSwap` - applies to this swap only. good for fees that change every swap

we want a different fee for every swap, so we use (2): `beforeSwap` returns `fee | LPFeeLibrary.OVERRIDE_FEE_FLAG` as its third value

the flag (bit 23) is what tells the PoolManager to use this fee instead of the stored one

#### beforeInitialize

a pool must be created with `LPFeeLibrary.DYNAMIC_FEE_FLAG` (`0x800000`) as its fee to be a dynamic fee pool. this can't be changed later

a static fee pool ignores the override fee, so the hook rejects it in `beforeInitialize` with `MustUseDynamicFee`

---

### Setup

```
git submodule update --init lib/forge-std lib/v4-hooks-public
git -C lib/v4-hooks-public submodule update --init --depth 1 lib/v4-periphery
git -C lib/v4-hooks-public submodule update --init --recursive --depth 1 lib/v4-core
forge test
```

`BaseHook` moved out of `v4-periphery` into [`Uniswap/v4-hooks-public`](https://github.com/Uniswap/v4-hooks-public), so that's what we install (same as the lesson)

don't run `git submodule update --init --recursive` from the root - `v4-hooks-public` pulls in 17 repos (UniswapX, v2/v3, Fluid, Pancake...) and we only need `v4-core` and `v4-periphery` from it

### Tests

`test/unit/<function>/` has one file per hook function:

- `constructor` - seeds the average with the deploy gas price
- `beforeInitialize` - allows dynamic fee pools, rejects static ones
- `beforeSwap` - exact fee at, above and below the average, including the ±10% boundaries, and the lesson's check that a lower fee gives more output
- `afterSwap` - the lesson's 10 → 4 → 12 gwei sequence moves the average 10 → 8 → 9 gwei
