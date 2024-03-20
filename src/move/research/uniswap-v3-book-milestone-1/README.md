# Implementation

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

$$ Q_x = 2^{64} x \tag{1} $$

Let $r$ represent the square root of $x$:

$$r = \sqrt{x} \tag{2} $$

Encode $r$ similarly:

$$ Q_r = 2^{64} r \tag{3} $$

Define $x$ and $r$ in terms of $Q_x$ and $Q_r$:

$$ r = \frac{Q_r}{2^{64}} \tag{4} $$

$$x = \frac{Q_x}{2^{64}} \tag{5} $$

Substituting $(4)$ and $(5)$ into $(2)$ yields:

$$ \frac{Q_r}{2^{64}} = \sqrt{\frac{Q_x}{2^{64}}} $$

$$ {Q_r} = 2^{64} \sqrt{\frac{Q_x}{2^{64}}} $$

$$ {Q_r} = \sqrt{(2^{64})^2 \frac{Q_x}{2^{64}}} $$

$$ {Q_r} = \sqrt{2^{64} Q_x} \tag{6} $$

| Equation   | Function     |
| ---------- | ------------ |
| $(1), (3)$ | `u64_to_q64` |
| $(4), (5)$ | `q64_to_u64` |
| $(6)$      | `sqrt_q64`   |

[santa clara university programming lab supplement]: https://www.cse.scu.edu/~dlewis/book3/labs/Lab11E.pdf
[stack overflow answer]: https://stackoverflow.com/a/994709
[wikipedia]: https://en.wikipedia.org/wiki/Integer_square_root#Example_implementation_in_C
