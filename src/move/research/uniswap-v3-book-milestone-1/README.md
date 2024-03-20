# Uniswap v3 Book Milestone 1

This content is based on [milestone 1 from the Uniswap v3 book].

## Numerical algorithms

The square root algorithm (`sqrt`) is adapted from a [Wikipedia] example, which
notes that the search converges faster when the initial estimate is adjusted for
the binary logarithm of the operand.

Both a [stack overflow answer] and `math128` from the Aptos Standard Library
specify that the binary logarithm of an integer is equivalent to the position of
the most significant bit. Hence the binary logarithm function (`log2_unchecked`)
uses a simple binary search to identify the most significant bit.

## Fixed point

For ease of representation in a `u128`, fixed point values are represented as a
`Q64.64`. This mirrors `math_fixed64` from the Aptos Standard Library. The fixed
point square root algorithm is adapted from a
[Santa Clara University programming lab supplement] as follows:

Let $x$ represent a square root operand, and $Q_x$ its `Q64.64` encoding:

```math
Q_x = 2^{64} x \tag{1}
```

Let $r$ represent the square root of $x$:

```math
r = \sqrt{x} \tag{2}
```

Encode $r$ similarly:

```math
Q_r = 2^{64} r \tag{3}
```

Define $x$ and $r$ in terms of $Q_x$ and $Q_r$:

```math
r = \frac{Q_r}{2^{64}} \tag{4}
```

```math
x = \frac{Q_x}{2^{64}} \tag{5}
```

Substituting $(4)$ and $(5)$ into $(2)$ yields:

```math
\frac{Q_r}{2^{64}} = \sqrt{\frac{Q_x}{2^{64}}}
```

```math
{Q_r} = 2^{64} \sqrt{\frac{Q_x}{2^{64}}}
```

```math
{Q_r} = \sqrt{(2^{64})^2 \frac{Q_x}{2^{64}}}
```

```math
{Q_r} = \sqrt{2^{64} Q_x} \tag{6}
```

Similarly, the multiplication operation $p = ab$ is governed by:

```math
p = ab
```

```math
\frac{Q_p}{2^{64}} = \frac{Q_a}{2^{64}} \frac{Q_b}{2^{64}}
```

```math
Q_p = \frac{Q_a Q_b}{2^{64}} \tag{7}
```

Likewise, for the division operation $q = \frac{a}{b}$:

```math
q = \frac{a}{b}
```

```math
\frac{Q_q}{2^{64}} = \frac{\frac{Q_a}{2^{64}}}{\frac{Q_b}{2^{64}}} =
\frac{Q_a}{Q_b}
```

```math
Q_q = \frac{2^{64} Q_a}{Q_b} \tag{8}
```

For the addition operation $s = a + b$:

```math
s = a + b
```

```math
\frac{Q_s}{2^{64}} = \frac{Q_a}{2^{64}} + \frac{Q_b}{2^{64}}
```

```math
Q_s = Q_a + Q_b \tag{9}
```

And finally, for the subtraction operation $d = a - b$:

```math
d = a - b
```

```math
\frac{Q_d}{2^{64}} = \frac{Q_a}{2^{64}} - \frac{Q_b}{2^{64}}
```

```math
Q_d = Q_a - Q_b \tag{10}
```

| Equation   | Function     |
| ---------- | ------------ |
| $(1), (3)$ | `u64_to_q64` |
| $(4), (5)$ | `q64_to_u64` |
| $(6)$      | `sqrt_q64`   |
| $(7)$      | `multiply_q64_unchecked` |
| $(8)$      | `divide_q64_unchecked` |
| $(9)$      | `add_q64_unchecked` |
| $(10)$      | `subtract_q64_unchecked` |


[milestone 1 from the uniswap v3 book]: https://uniswapv3book.com/milestone_1/introduction.html
[santa clara university programming lab supplement]: https://www.cse.scu.edu/~dlewis/book3/labs/Lab11E.pdf
[stack overflow answer]: https://stackoverflow.com/a/994709
[wikipedia]: https://en.wikipedia.org/wiki/Integer_square_root#Example_implementation_in_C
