# Uniswap v3 whitepaper

This content references the [Uniswap v3 whitepaper].

## Terminology

| Conventional finance | Example | Uniswap "asset" | Uniswap "token" |
| -------------------- | ------- | --------------- | --------------- |
| Base                 | APT     | x               | `token0`        |
| Quote                | USDC    | y               | `token1`        |

## Concentrated liquidity overview

In older versions of Uniswap, liquidity was distributed along single curve:

```math
x y = k
```

However, v3 bounds liquidity within price ranges having lower price $p_a$ and
upper price $p_b$, where price is defined as ratio of quote to base:

```math
p = \frac{y}{x} = \frac{token1}{token0} = \frac{Quote}{Base}
```

Within a range, prices move as if there were enough "virtual reserves" to
deplete real $x$ and $y$ reserves just upon reaching the endpoints.

"Liquidity" is taken as:

```math
L = \sqrt{k} = \sqrt{x_{virtual}y_{virtual}}
```

Liquidity and real reserves are related to price endpoints by the equation:

```math
(x + \frac{L}{\sqrt{p_b}})(y + \frac{L}{\sqrt{p_a}}) = L^2
```

## Ticks and ranges

Positions can be indicated between "ticks", which are at integer powers of
1.0001 such that each tick represents a basis point step from its neighbor. The
tick index is a signed integer $i$:

```math
p(i) = 1.0001^i
```

Except pools track ticks at every square root price:

```math
\sqrt{p}(i) = 1.0001^{\frac{i}{2}}
```

`tickSpacing` initializes ticks at only certain integer multiples, and is
dictated by the pool fee rate.

Instead of tracking virtual reserves, the pool tracks liquidity and square root
of price, which are functions of virtual reserves:

```math
L = \sqrt{x_v y_v}
```

```math
\sqrt{P} = \sqrt{\frac{y_v}{x_v}}
```

Tracking these two values is deemed convenient because only one changes at a
time, though virtual reserves can always be back-calculated:

```math
x = \frac{L}{\sqrt{P}}
```

```math
y = L \sqrt{P}
```

Price changes when swapping, and liquidity changes when:

- Liquidity is added
- Liquidity is removed
- A tick is crossed

It is noted that this choice of variables avoids rounding errors that could
happen if tracking virtual reserves.

Liquidity is also cited as the amount of quote reserves (either actual or
virtual) that change for a given change in square root price:

```math
L = \frac{\Delta Y}{\Delta \sqrt{P}}
```

Hence during a swap, when liquidity is constant, quote amount changes are a
direct function of square root price.

Global state tracks the current tick index as a signed integer, with the
relationship to price given by:

```math
i_c = \lfloor \log_{\sqrt{1.0001}} \sqrt{P} \rfloor
```

## Fees

Pool fee rate is represented in hundredths of a basis point:

```math
\gamma
```

Global state tracks two values for fees, `feeGrowthGlobal0` and `_1`:

```math
f_{g, 0}
```

```math
f_{g, 1}
```

These represent total amount of fess per unit of $L$ over entire history of
pool. Values are stored as `Q128.128` integers.

Similar relationships hold for protocol fees, denoted as the fraction of swap
fees taken as protocol fees:

```math
\phi
```

## Swapping within a tick

Within a tick, swaps act like an $xy=k$ swap. Consider an input amount of quote.
First, global and protocol fees are incremented:

```math
\Delta f_{g, 1} = y_{in} \gamma (1 - \phi)
```

```math
\Delta f_{p, 1} = y_{in} \gamma \phi
```

Hence the change in reserves is the increase in quote after fees is taken out of
input:

```math
\Delta y = y_{in}(1 - \gamma)
```

If virtual reserves $x$ and $y$ were tracked, then base out could be calculated
via:

```math
x_{out} = \frac{x_v y_v}{y_v + \Delta y}
```

However, since v3 tracks liquidity and square root price, changes in asset
amounts are calculated via:

```math
\Delta \sqrt{P} = \frac{\Delta y}{L}
```

```math
\Delta y = L \Delta \sqrt{P}
```

```math
\Delta \frac{1}{\sqrt{P}} = \frac{\Delta x}{L}
```

```math
\Delta x = L \Delta \frac{1}{\sqrt{P}}
```

Hence v3 can calculate the price change due to the amount of one asset in, and
from that value get the amount of the other asset out.

## Tick state

Each tick tracks the total amount of liquidity that needs to be added or removed
when the tick is crossed, `liquidityNet`:

```math
\Delta L
```

This value only needs to be updated when a position when a bound at the given
tick is updated.

Additionally, each tick tracks the gross tally of all liquidity that references
the tick, `liquidityGross`:

```math
L_g
```

This allows for for a tick to be uninitialized in the situation that net
liquidity is 0, and no positions reference it.

`feeGrowthOutside`, $f_o$ is tracked for both base and quote, and refers to how
many fees were accumulated both above $f_a$ or below $f_b$ the given tick index.
Note this value depends on if a given tick is the current tick:

```math
f_a(i) = \begin{cases}
    f_g - f_o(i) & i_c \geq i \\
    f_o(i) & i_c \lt i \\
\end{cases}
```

```math
f_b(i) = \begin{cases}
    f_o(i) & i_c \geq i \\
    f_g - f_o(i) & i_c \lt i \\
\end{cases}
```

Hence the amount of fees per share $f_r$ in the between lower tick $i_l$ and
upper tick $i_u$ is given by:

```math
f_r = f_g - f_b(i_l) - f_a(i_u)
```

Note that $f_o$ needs to be updated whenever a tick is crossed:

```math
f_o(i) := f_g - f_o(i)
```

$f_o$ only needs to be updated for initialized ticks. Hence, when $f_o$ is
initialized for a tick, it is taken as if all fees earned to date had occurred
below the tick:

```math
f_o := \begin{cases}
    f_g & i_c \geq i \\
    0 & i_c \lt i
\end{cases}
```

## Position state

Positions are indexed by the combination of user address, lower bound, and upper
bound. Each position tracks virtual liquidity:

```math
l = \sqrt{x_v y_v}
```

This is the amount of virtual reserves the position contributes to the pool
whenever it is in range. Note that liquidity amounts do not change as fees are
accumulated. Rather, fees are accumulated as uncollected amounts, and at each
user level, there are values to track `feeGrowthInsideLast`:

```math
f_{r, 0}(t_o)
```

To start a position, a user has to specify a liquidity amount and range
endpoints. Hence uncollected fees can be calculated against the last collection
checkpoint:

```math
f_i = l (f_r(t_1) - f_r(t_0))
```

The position's liquidity change amount is then added to the tick at the bottom
of the range, and removed from the upper tick. If the current price is in the
range, then the global liquidity for the pool is also updated.

Deposit amounts are taken as the amount that would be sold if the price were to
move from the current price $P$ to the upper or lower tick respectively. The
amounts depend on whether the price is below, within, or above the range of the
position.

```math
\Delta Y = \begin{cases}
    0 & i_c \lt i_l \\
    \Delta L (\sqrt{P} - \sqrt{p(i_l)}) & i_l \leq i_c \lt i_u \\
    \Delta L (\sqrt{p(i_u)} - \sqrt{p(i_l)}) & i_c \geq i_u \\
\end{cases}
```

```math
\Delta X = \begin{cases}
    0 & i_c \lt i_l \\
    \Delta L (\frac{1}{\sqrt{p(i_l)}} - \frac{1}{\sqrt{p(i_u)}})
        & i_l \leq i_c \lt i_u \\
    \Delta L (\frac{1}{\sqrt{P}} - \frac{1}{\sqrt{p(i_u)}})
        & i_c \geq i_u
\end{cases}
```

[uniswap v3 whitepaper]: https://uniswap.org/whitepaper-v3.pdf
