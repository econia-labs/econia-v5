# Uniswap v3 whitepaper

This content references the [Uniswap v3 whitepaper].

## Whitepaper review

### Terminology

| Conventional finance | Example | Uniswap "asset" | Uniswap "token" |
| -------------------- | ------- | --------------- | --------------- |
| Base                 | APT     | x               | `token0`        |
| Quote                | USDC    | y               | `token1`        |

### Concentrated liquidity overview

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

### Ticks and ranges

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

### Fees

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

### Swapping within a tick

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

### Tick state

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

### Position state

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

## Followup

### Initial commentary

Uniswap v3 is based on the Ethereum blockchain, where computational resources
are exceedingly scarce and gas optimizations are of paramount concern. Hence
the choice of tracking liquidity and square root price may be useful for keeping
gas down, but it complicates some of the math involved. Precision issues are
cited, but this may have to do with the exceedingly high number of decimal
places offered on the chain: ETH, the L1 token, has 18 decimal places, hence the
precision issues involved with converting between reserve amounts against USDC,
for example, which only has 6.

Additionally, Uniswap v3 does not enable fee compounding, and it is proposed
that the ideal protocol would use simple $xy=k$ relationships with reinvested
fees for concentrated liquidity management. Here, the trick is tracking fees
while ensuring that "whenever the price crosses an initialized tick, virtual
liquidity is kicked in or out."

However, for incorporation with the Econia order book protocol, a CLMM would
ideally only accrue protocol and integrator fees in the quote asset. Note that
LP fees would ideally be two-sided and reinvested, so as to continuously grow
liquidity amounts with maximum yield.

Another issue is that full-range positions are still non-fungible, even though
they would ideally be fungible (analogous to LP tokens).

Finally, the choice of logarithmic tick sizing adds to the numerical complexity.
A proposed alternative model involves so-called "dumbbell" tick sizing, based on
dumbbell weights which change in their increment amount at milestone decimal
values: 25, 27.5, 32.5, ... 47.5, 50, 55, 60. Similarly, one method for tracking
prices could entail the use of ratios where the numerator increment doubles at
every nominal doubling. For example:

```math
\frac{11}{100}, \frac{12}{100}, \frac{13}{100} \dots
\frac{19}{100}, \frac{20}{100}, \frac{22}{100} \dots
\frac{38}{100}, \frac{40}{100}, \frac{44}{100}
```

Here, the increment doubles at a nominal value of 20%, then again at 40%. Base-2
relationship can easily be managed via simple bitshift operations.

### Prototype structs

`structs.move` contains prototype structs geared to address the above issues. At
the `Pool` level, there are tracked `virtual_base` and `virtual_quote` amounts.
Here, the intention is that tick crossing simply updates the virtual reserve
amounts, and that input or output amounts can be calculated without recourse to
square roots.

Hence a `Position` tracks the amount of base and quote provided, as well as the
amounts of virtual base and quote at the time of provisioning. From these values
an effective liquidity share can be derived for redemption purposes. Similarly,
a `Tick` tracks virtual base and quote change amounts, relying on a bool flag to
determine polarity since Move does not natively support signed integers.

There is the issue of tracking how many reinvested fees an LP is entitled to,
since not all of their liquidity is necessarily in range. Hence the `Pool`
tracks a `base_growth_global` and `quote_growth_global`. And similarly, each
tick tracks `base_growth_outside` and `quote_growth_outside`. Hence when a tick
is active, its net values for virtual base and quote must be updated at each
swap to offset changes in overall virtual reserves. Then when it is crossed, the
base and quote growth values can be updated against the global values.

Note that without extensive supporting calculations it still stands to be seen
if reinvestment is possible through this schema, though this prototype at least
aims for such a mechanism. For example, one limitation could be the translation
of the $xy = k$ curve not working with fee reinvestment.

Note that this two-sided pool fee schema does not preclude a one-sided fee
schema for protocol fees or integrator fees. Those can simply be assessed on the
input amount for a market buy, and the output amount on a market sell.

To address the decimal price issue, prices may be represented as a `Ratio`, with
valid prices checked upon position initialization.

As for LP tokens on full-range positions, the `Pool` tracks the number of issued
LP tokens, corresponding to shares of a position having as its bounds the lowest
possible tick and the highest possible tick. However unlike other positions
which can simply be minted and burned, the virtual position, of which LP tokens
are shares in, is continuously updated whenever a portion of its shares are
minted or burned. Hence the pool tracks base/quote input amounts as well as the
amount of virtual base and quote at the last mint/burn operation.

[uniswap v3 whitepaper]: https://uniswap.org/whitepaper-v3.pdf
