# Algorithms

The square root algorithm is adapted from a [Wikipedia] example, which notes
that the search converges faster when the initial estimate is adjusted based on
the binary logarithm of the operand.

Both a [stack overflow answer] and `math128` from the Aptos Standard Library
specify that the binary logarithm of an integer is equivalent to the position of
the most significant bit. Hence the binary logarithm function uses a simple
binary search to identify the most significant bit.

[stack overflow answer]: https://stackoverflow.com/a/994709
[wikipedia]: https://en.wikipedia.org/wiki/Integer_square_root#Example_implementation_in_C
