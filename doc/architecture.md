<!--- cspell:words incentivized, evictable -->

# Econia v5 Architecture

The key words `MUST`, `MUST NOT`, `REQUIRED`, `SHALL`, `SHALL NOT`, `SHOULD`,
`SHOULD NOT`, `RECOMMENDED`,  `MAY`, and `OPTIONAL` in this document are to be
interpreted as described in [RFC 2119].

These keywords `SHALL` be in `monospace` for ease of identification.

## Units

1. Size `SHALL` be expressed in terms of indivisible base subunits.
1. Volume `SHALL` be expressed in terms of indivisible quote subunits.
1. Prices `SHALL` be expressed as a `u128` fixed-point decimal per
   [`aptos-core` #11952], representing a ratio of volume to size.
1. Fee rates `SHALL` be expressed in basis points.
1. Both size and price `SHALL` be restricted to a certain number of significant
   figures, based on the market, per [`aptos-core` #11950].
1. The minimum permissible post size `SHALL` be mediated via a mixture of
   eviction criteria and governance.

### Significant figures

1. Size and price `SHALL` be restricted to a certain number of significant
   figures per market, with the required number of significant figures tracked
   separately for each unit.
1. A global registry `SHALL` track the default minimum size and price
   significant figure values for new markets, with both defaults subject to
   modification per a governance vote.
1. Governance `SHALL` have the authority to manually set new significant figure
   restrictions for existing markets to enable, for example, above-average
   significant figure restrictions for price on a wrapped Bitcoin market.

### Minimum post size

1. In the default case, a market `SHALL` have a minimum post size that is
   calculated based on existing liquidity: the amount of base locked in all asks
   or the amount of quote locked in all bids. For example the minimum post size
   may be calculated as 1 basis point of all liquidity for the given side.
1. Alternatively, governance `MAY` override the default minimum post size and
   specify a minimum base and quote amount to post. This could be necessary for
   high-liquidity markets, to avoid flash loan attacks.
1. A low-pass filter or similar `MAY` be used to calculate time weighted average
   liquidity.
1. The dynamic calculations `SHALL NOT` use a logarithmic formula to calculate
   minimum post size so as to avoid distortions between assets with different
   decimal amounts.

## Dynamics

### Fees

1. Taker fees, assessed on the taker side of the trade, `SHALL` default to 0 for
   every new market, with a governance override enabling a new fee rate for
   select markets.
1. Integrators `SHALL` have the ability to collect fees via an
   `integrator_fee_rate_bps: u16` argument on public functions, deposited into a
   specific fungible asset store reserved for that market, to enable parallelism
   for integrators who facilitate trades across multiple markets. Hence there
   `SHALL` also be an `integrator_fee_store: Object<T>` argument. Integrator
   fees `SHALL` be assessed in the quote asset for the pair.
1. The market's liquidity pool `SHALL` also charge a fee, mediated via market
   parameters, denominated in basis points. Within liquidity pool operations
   fees must be assessed in both base and quote, but `SHALL` be normalized to
   quote-only outside of liquidity pool operations.

### Eviction

1. Markets `SHALL` permit a fixed number of orders per side, for example 1000.

1. Orders `SHALL` be evicted if the ratio formed by their price and the best ask
   or bid price exceeds a fixed value, for example 10.

1. When an order is placed, the head and tail of the book for the given side
   `SHALL` be checked, and evicted if they are below the minimum post size for
   the market.

1. Eviction from the middle of the price-time queue `MAY` be incentivized via an
   eviction bounty program via a public API, where bounty hunters need to pay a
   deposit, and if the order in question is evictable, then they get back their
   deposit and an eviction bounty, for example 5 basis points of the posted
   collateral on the order, deposited straight to the bounty hunter's primary
   fungible asset store. In this schema bounty rate and deposit amount may be
   tracked as market parameters.

### Oracle queries

1. Queries for information like best bid/ask `SHALL` be possible through public
   APIs, to enable composability. These APIs `MAY` charge a small amount, for
   example 100 octas, to reduce excessive queries for contended state.

### Trading

1. Limit orders and market orders `SHALL` accept the object address of a user's
   market account, as well as a size, price, and restriction. This `MAY` be
   moderated via a single API that uses `HI_64` or `0` to indicate market order
   for immediate-or-cancel restriction.
1. Swaps `SHALL` fill outside of a market account, and `SHALL` specify an input
   amount as well as the worst acceptable effective price after fees.
1. Size change or cancel orders `SHALL` accept the price of the order to cancel.

### Transaction sponsorship

1. Each market `SHALL` include fungible asset stores, that anyone can deposit
   into, to enable transaction sponsorship. Transaction sponsorship `MAY` be
   further segmented into specific buckets for things like placing limit orders,
   placing swaps, etc.
1. Users `MAY` be provided with the ability to pre-pay their own transactions,
   and have their sponsorship bucket be used only after applicable global
   transaction sponsorship.

### Events

1. Market registration events `SHALL` include fungible asset metadata like
   decimals for ease of indexing.

### Withdrawals

1. Since fungible assets may be seized at any time, deposits and withdrawals
   `SHALL` be assessed proportionally to socialize losses and avoid bank run
   scenarios: if vaults are 50% empty, then deposits will be 50% of expected.

## Data structures

### Market accounts

1. A user's open orders `SHALL` be tracked via a red-black binary search tree,
   with order price as the lookup key. Hence each user will only be able to have
   one open order at a given price. The red-black tree `MAY` cache the location
   of the last accessed key so that operations to check existence then borrow
   can occur without re-traversal.
1. Only available and total amounts for base and quote `SHALL` be tracked, since
   deposits will be held in a global vault in order to reduce borrows. Since
   anyone can deposit into the global vault store, there is no way to ensure the
   global ceiling is static.
1. Market orders and swaps `SHALL` fill into a user's market account.
1. When a user deposits to or withdraws from their market account, assets
   `SHALL` transact against a global base/quote vault for the entire market.
1. There `SHALL` be a hard-coded constant restricting the number of open orders
   each user is allowed to have.

### Market vaults

1. Markets `SHALL` have a global vault for base and quote, containing all user
   and liquidity pool deposits.
1. It `SHALL` be assumed that no more than `HI_64` of assets will be
   consolidated in one place, to avoid excessive error checking. Hence the onus
   is on asset issuers to regulate supply accordingly.

### Liquidity pools

1. Liquidity pool logic `SHALL` take reasonable steps to ensure that no more
   than `HI_64` of lp tokens are ever minted. For example for the first mint,
   the number of tokens could be taken as the greater of base and quote
   deposited.

### Parametric configurability

1. Multisig governance `SHALL` have the ability to manually configure market
   parameters on specific markets, as well as the default parameters for new
   markets, via a `MarketParameters` residing at both the market level and the
   registry level, with the latter stipulating a
   `new_market_defaults: MarketParameters` field.

### Orders

1. Orders `SHALL` track original size and volume amount, and remaining amount to
   fill. Here, orders will only match based on the price specified in each
   order. Per this schema there is an opportunity for truncation issues, for
   example if an order has 3 base and 997 quote to fill, and a matching order
   has 552 quote to fill against. However, truncation issues of the sort will
   be assumed by the taker, and in practice subunits amounts will be of much
   larger orders of magnitude.

### Order books

1. Order books `SHALL` implement a B+ tree-based architecture, with each key
   containing a price and an effective sequence number for that price,
   denoting the price-time priority of the order, represented as a `u256` of the
   form `price_as_decimal_fixed_u128 << 64 | sequence_number_at_level`. The
   sequence number for the level `SHALL` be generated dynamically upon insertion
   such that the first order at a new price level assumes the sequence number 1.

### Extensions

1. Core data structures `SHALL` include `aptos_framework::any::Any`,
   `aptos_framework::copyable_any::Any`, or similar `extension` fields
   to enable unforeseen backwards-compatible feature upgrades.

## Implementation details

1. Error codes that are raised by multiple functions `SHALL` be wrapped with
   inline helper functions containing a single assert, so that the inline
   function can be failure tested, for ease of coverage.

[rfc 2119]: https://www.ietf.org/rfc/rfc2119.txt
[`aptos-core` #11950]: https://github.com/aptos-labs/aptos-core/pull/11950
[`aptos-core` #11952]: https://github.com/aptos-labs/aptos-core/pull/11952
