# Econia v5 Architecture

The key words `MUST`, `MUST NOT`, `REQUIRED`, `SHALL`, `SHALL NOT`, `SHOULD`,
`SHOULD NOT`, `RECOMMENDED`,  `MAY`, and `OPTIONAL` in this document are to be
interpreted as described in [RFC 2119].

These keywords `SHALL` be in `monospace` for ease of identification.

## Ratios

1. Prices `SHALL` be expressed in terms of ratios, to enable continuous pricing.
   Here, prices will simply be represented as a ratio of quote to base.
1. Ratios `SHALL` be reduced as much as possible, via division by the greatest
   common divisor of numerator and denominator.
1. Similarly, fees `SHALL` be represented as ratios, with 3 basis points, for
   example, represented via a numerator of 3 and denominator 100.

## Market structure

1. Lot size and tick size will not be required due to continuous ratio pricing,
   and minimum order size `SHALL` be mediated via a mixture of eviction criteria
   and governance, enabling canonical markets for a given pair.

### Minimum post size

1. In the default case, a market `SHALL` have a minimum post size that is
   calculated based on existing liquidity: the amount of base locked in all asks
   or the amount of quote locked in all bids. For example the minimum post size
   may be calculated as the ratio of 1 basis point of all liquidity for the
   given side.
1. Alternatively, governance `MAY` override the default minimum post size and
   specify a minimum base and quote amount to post. This could be necessary for
   high-liquidity markets, to avoid flash loan attacks.
1. A low-pass filter or similar `MAY` be used to calculate time weighted average
   liquidity.
1. The dynamic calculations `SHALL NOT` use a logarithmic formula for
   calculating minimum post size so as to avoid distortions between different
   assets with different decimal amounts.

### Eviction criteria

1. Markets `SHALL` permit a fixed number of orders per side, for example 1000.
1. Orders `SHALL` be evicted if the ratio formed by their price and the best ask
   or bid price exceeds a fixed value, for example 10.
1. When an order is placed, the head and tail of the book for the given side
   `SHALL` be checked, and evicted if it is below the minimum post size for the
   market.

## Fees

1. Taker fees, assessed on the taker side of the trade, `SHALL` default to 0 for
   every new market, with a governance override enabling a new fee ratio for
   select markets.

## APIs

### Oracle queries

1. Queries for information like best bid/ask `SHALL` be possible through public
   APIs to enable composability. These APIs `MAY` charge a small amount, for
   example 100 octas, to reduce excessive queries for contended state.

### Trading

1. Limit orders, rather than specifying a size and integer price, `SHALL` input
   amounts of base and quote, from which a ratio can be calculated.
1. A swap `SHALL` specify an input amount, and a minimum output amount for the
   given input amount, effectively denoting the worst acceptable price.

### Transaction sponsorship

1. Each market `SHALL` include fungible asset stores, that anyone can deposit
   into, to enable transaction sponsorship. Transaction sponsorship `MAY` be
   further segmented into specific buckets for things like placing limit orders,
   placing swaps, etc.
1. Users `MAY` be provided with the ability to pre-pay their own transactions,
   and have their sponsorship bucket be used only after applicable global
   transaction sponsorship.

## Data structures

### Orders

1. Orders `SHALL` track original base and quote amount, and remaining amount to
   fill. Here, orders will only match based on the price ratio specified in each
   order. Per this schema there is an opportunity for truncation issues, for
   example if an order has 3 base and 997 quote to fill, and a matching order
   has 552 quote to fill against. However, truncation issues of the sort will
   be assumed by the taker, and in practice subunits amounts will be of much
   larger orders of magnitude.

### Order books

1. Order books `SHALL` implement a B+ tree-based architecture, with each key
   containing a ratio (price), and an effective sequence number for that price,
   denoting the price-time priority of the order.

### User

1. A user's open orders `SHALL` be tracked via a red-black binary search tree,
   with order price as the lookup key. Hence each user will only be able to have
   one open order at a given price.

### Future proofing

1. Core data structures `SHALL` include `aptos_framework::any::Any` fields or
   similar to enable unforeseen backwards-compatible feature upgrades.

[rfc 2119]: https://www.ietf.org/rfc/rfc2119.txt
