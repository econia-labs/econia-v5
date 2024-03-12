<!--- cspell:words evictable, incentivized -->

# Econia v5 Architecture Specification

The key words `MUST`, `MUST NOT`, `REQUIRED`, `SHALL`, `SHALL NOT`, `SHOULD`,
`SHOULD NOT`, `RECOMMENDED`,  `MAY`, and `OPTIONAL` in this document are to be
interpreted as described in [RFC 2119].

These keywords `SHALL` be in `monospace` for ease of identification.

## Units

1. Size `SHALL` be expressed in terms of indivisible base subunits.
1. Volume `SHALL` be expressed in terms of indivisible quote subunits.
1. Order book prices `SHALL` be expressed as a rational number via a `u64` each
   for numerator and denominator, representing the ratio of quote to base, and
   `MAY` be encoded as `numerator << 64 | denominator` via a single `u128`.
1. Fee rates `SHALL` be expressed in hundredths of a basis point.
1. Price `SHALL` be restricted to a certain number of significant figures, based
   on the market, per [`aptos-core` #11950].
1. The minimum permissible post amount `SHALL` be mediated via dynamic eviction
   eviction criteria.

### Significant figures

1. Price `SHALL` be restricted to a certain number of significant figures per
   market, using decimalized rational number representations with a base-10
   denominator and a numerator having the specified number of significant
   figures.
1. A global registry `SHALL` track the default maximum price significant figure
   values for new markets, with defaults subject to modification per a
   governance vote.
1. Governance `SHALL` have the authority to manually set new significant figure
   restrictions for existing markets to enable, for example, above-average
   significant figure restrictions for price on a wrapped Bitcoin market.

### Minimum post amount

1. In the default case, a market `SHALL` have a minimum post amount that is
   calculated based on existing liquidity: the amount of base locked in all asks
   or the amount of quote locked in all bids. For example the minimum post
   amount may be calculated as 0.1 basis point of all liquidity for the given
   side, implemented as a fixed decimal divisor.
1. Alternatively, governance `MAY` be given the ability to set a static minimum
   post amount, to eliminate the possibility of griefing via a flash loan. Here,
   the minimum post amount for base and quote must be stipulated separately in
   case the other side of the book is emptied, in which case base collateral on
   asks could not be priced. Notably, this approach implies a reference price
   that may need to be tuned on occasion (ratio of quote to base).
1. A low-pass filter or similar `MAY` be used to calculate time weighted average
   liquidity, to prevent flash loan eviction attacks.
1. The dynamic calculations `SHALL NOT` use a logarithmic formula to calculate
   minimum post size so as to avoid distortions between assets with different
   decimal amounts.

## Dynamics

### Fees

1. Protocol and integrator fees `SHALL` be assessed in the quote asset for a
   pair.
1. Fee rates `SHALL` be encoded as `u16` values, enabling fees up to 6.5535%.
1. Protocol fees, assessed on the taker side of the trade, `SHALL` default to 0
   for every new market, with a governance override enabling a new fee rate for
   select markets.
1. Integrators `SHALL` have the ability to collect fees via `integrator_address`
   and `integrator_fee_rate` arguments on public functions, with fees deposited
   to the corresponding primary fungible store.
1. The market's liquidity pool `SHALL` charge a dynamic fee based on volatility.
   Fees `MAY` be assessed in both base and quote at the pool level as needed,
   but `SHALL` be normalized outside of liquidity pool operations for ease of
   slippage comparison.

### Eviction

1. Markets `SHALL` permit a fixed tree height per side, for example 5.
1. Orders `SHALL` be evicted if the ratio formed by their price and the best ask
   or bid price exceeds a fixed value, for example 10.
1. Eviction from anywhere in the price-time queue `SHALL` be enabled via a
   public API available outside of order posting.
1. Public eviction APIs `MAY` be incentivized via an eviction bounty for a fixed
   amount of the remaining collateral available on an evictable order, for
   example 5 basis points, deposited straight to the eviction executor's primary
   fungible store. If bounties are available, they `SHALL` be assessed on either
   all evictions or none, including those instigated by order posts, such that
   orders at the back of the price-time queue are not immune from bounty loss.
1. Should a bounty not be implemented for fear of promoting adversarial
   behaviors, eviction stewardship for the middle of the price-time queue `MAY`
   be implemented as a duty good, whereby oracle operations that access order
   book state, for example, (or even those that do not) are required to randomly
   scan the order book for the given market and evict orders as needed.
1. The source of randomness for eviction duty `MAY` use transaction hash, Aptos
   unique identifier (AUID), on-chain randomness, cyclical redundancy check or
   similar bitshift technique, at each level in the tree, to determine which
   branch to iterate to next.
1. When an order is placed, the head and tail of the book for the given side
   `MAY` be checked, and evicted if market eviction criteria are met to ensure
   that eviction is at least checked during tree grow operations.

### Oracle queries

1. Queries for information like best bid/ask `SHALL` be possible through public
   APIs, to enable composability. These APIs `MAY` charge a small amount, for
   example 100 octas, to reduce excessive queries for contended state.
1. Oracle fees `MAY` be paid to a primary fungible store for each market,
   denominated in the protocol utility coin, with the oracle query amount
   tracked in a global registry.
1. Runtime oracle functions `SHALL` be implemented as a public wrapper around
   private view functions.

### Trading

1. A user's open orders `SHALL` be tracked in an open orders object, such that
   market makers can submit the address of the object for optimized order
   placement.
1. Orders `SHALL` accept a size, limit price (worst execution price including
   fees), restriction, and open orders object address.
1. Order APIs `SHALL` accept `0x0` for open orders address to indicate an
   immediate-or-cancel order that settles to a user's primary fungible store.
1. Limit orders, market orders, and swaps `SHALL` be moderated via a single API
   wherein a user can set an order's limit price to `0 / 1` (denoting price `0`)
   or `1 / 0` (denoting price infinity) to indicate an immediate-or-cancel
   market order.
1. Order cancellations `SHALL` accept the price of the order to cancel for the
   given user and the open orders object address.
1. Due to low usage of size changes in Econia v4, size changes `SHALL NOT` be
   supported, in order to simplify the implementation and reduce attack vectors.
1. Posting `SHALL` abort if at a price that a user already has an open order at.
1. Restrictions and self match behavior `SHALL NOT` moderate behavior via abort
   statements, since this approach inhibits ease of indexing.
1. Self match behavior `SHALL` support `CANCEL_BOTH`, `CANCEL_MAKER`, and
   `CANCEL_TAKER` options.
1. Order restrictions `SHALL` support `NO_RESTRICTION`, `FILL_OR_KILL`,
   `POST_ONLY`, and `IMMEDIATE_OR_CANCEL`.

### Transaction sponsorship

1. Each market `MAY` be designed to include fungible asset stores, that anyone
   can deposit into, to enable transaction sponsorship. Transaction sponsorship
   `MAY` be further segmented into specific buckets for things like placing
   limit orders, placing swaps, etc.
1. Users `MAY` be provided with the ability to pre-pay their own transactions,
   and have their sponsorship bucket be used only after applicable global
   transaction sponsorship.

## Data structures

### Registry

1. Recognized markets `SHALL` map from trading pair to market ID, using an
   `aptos_std::smart_table::SmartTable` since it is an ordered map that will not
   be subject to the same attack vectors as maps with a public insertion vector.
1. Market IDs `SHALL` be 1-indexed.

### Open orders

1. A user's open orders `SHALL` be tracked via a red-black binary search tree,
   with order price as the lookup key. Hence each user will only be able to have
   one open order at a given price. The red-black tree `MAY` cache the location
   of the last accessed key so that operations to check existence then borrow
   can occur without re-traversal. Bid and ask trees for a user `MAY` be
   combined into one single tree.
1. There `SHALL` be a hard-coded constant restricting the number of open orders
   each user is allowed to have.
1. Each user `SHALL` have an open orders map of type
   `aptos_std::smart_table::SmartTable` which lists the markets they have open
   orders objects for.
1. Open orders objects `SHALL` be non-transferrable.

### Market vaults

1. Markets `SHALL` have a global vault for base and quote, containing all posted
   order collateral and liquidity pool deposits.
1. It `SHALL` be assumed that no more than `HI_64` of assets will be
   consolidated in one place, to avoid excessive error checking. Hence the onus
   is on asset issuers to regulate supply accordingly. This style mimics the
   `aptos_framework::coin` specification.

### Liquidity pools

1. Liquidity pool logic `SHALL` take reasonable steps to ensure that no more
   than `HI_64` of liquidity provider tokens are ever minted. For example for
   the first mint, the number of tokens could be taken as the greater of base
   and quote deposited.
1. Initialized ticks `SHALL` be organized in a B+ tree with a doubly linked list
   at both inner and leaf nodes.

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
1. Orders `SHALL` stipulate the original size or volume posted, such that they
   can be evaluated for eviction.
1. An order that would post to the tail of a queue that is above the eviction
   height threshold `SHALL` be prohibited from posting.
1. Orders `MAY` be given the opportunity to specify time in force, though this
   approach would increase overall execution gas for a feature that is not
   necessarily a requirement for most market makers.

### Order books

1. Order books `SHALL` implement a B+ tree-based architecture, with each key
   containing a price and an effective sequence number for that price,
   denoting the price-time priority of the order. The sequence number for the
   level `SHALL` be generated dynamically upon insertion such that the first
   order at a new price level assumes the sequence number 0.
1. Each market `SHALL` have a B+ tree for each side, which caches the best price
   and its leaf node's address, the worst price and its leaf node's address,
   and has a sort order direction such that the sequence number flag for bids,
   of descending sort order direction, is `HI_64 - sequence_number_at_level`.
1. The B+ tree `SHALL` track its height at the root node, for ease of eviction
   monitoring, though insertion and lookup mechanics `MAY` be able to track
   height on the fly.
1. Each inner node in the B+ tree `SHALL` implement a doubly linked list.
1. Each leaf node in the B+ tree `SHALL` implement a doubly linked list.
1. The B+ tree `SHALL` accept inner and leaf node orders configured during
   initialization, optimized for gas costs.

### Extensions

1. Core data structures `SHALL` include `aptos_framework::any::Any`,
   `aptos_framework::copyable_any::Any`, or similar `extension` fields
   to enable unforeseen backwards-compatible feature upgrades.

## Implementation details

### B+ tree

1. Since both orders and ticks rely on a B+ tree, the tree `SHALL` be designed
   in a generalized format that can be used for both applications.
1. The tree `SHALL` support a `Pointer` struct or similar, containing both node
   address and vector index, that can be stored for caching/iteration purposes.
1. Inner and leaf node order `SHALL` be configurable upon initialization, via a
   `tree_order` market parameter or similar.
1. An insertion API `SHALL` be provided with a `Pointer` return, to reduce
   borrows.

### Pausing

1. A `status` resource `SHALL` contain an `active` field that can be modified by
   governance, such that if the protocol is considered inactive then only
   order cancellations and withdrawals are allowed.

### Objects

1. Objects `SHALL` be non-transferrable.

### Matching

1. The matching engine `SHALL` implement a two-phase model to first evaluate a
   match, then commit it, with an intermediate "match result" data structure
   that tabulates the orders to fill/decrement, self match orders to cancel,
   pool changes, etc.
1. The intermediate match result `SHALL` be considered before evaluating
   fill-or-kill orders.
1. The intermediate match result `SHALL` be made publicly available during
   runtime via an oracle function.
1. For order types that do not require a two-phase model, matching `SHALL` be
   evaluated on the fly to reduce overhead associated with the prepare/commit
   paradigm.

### Eviction

1. Eviction price `SHALL` be mediated via scaling per
   `eviction_price_divisor_ask` and `_bid`, such that the proposed ask price is
   divided by the best ask price, and the best bid price is divided by the
   proposed bid price before threshold comparisons.
1. Eviction of a full order book `SHALL NOT` be possible within a single
   transaction.
1. Eviction liquidity divisors `SHALL` similarly be mediated via optimistic
   division.

### Error codes

1. Error codes that are raised by multiple functions `SHALL` be wrapped with
   helper functions containing a single assert, so that the helper function can
   be failure tested alone, for ease of coverage testing.

### Events

1. Market registration events `SHALL` include fungible asset metadata like
   decimals for ease of indexing.
1. Market orders and limit orders `SHALL` use the same event structure, which
   `MAY` be common to swaps.

### Withdrawals

1. Since fungible assets may be seized at any time, deposits and withdrawals
   `SHALL` be assessed proportionally to socialize losses and avoid bank run
   scenarios per [`aptos-core` #12240]: if vaults are 50% empty, then returned
   amounts will be 50% of expected.

### Parameter updates

1. Market parameter updates for a given market `SHALL` be updated in multiple
   places in the registry since data is indexed in multiple ways.
1. Market parameters `SHALL` be set via APIs that accept a vector for each
   field, representing an option where `some` corresponding to an update. Market
   ID `SHALL` be offered as a field, and if `none` the update corresponds to
   default parameter updates.

### Package publication

1. Move package size `SHALL` be under the max transaction limit, to enable
   package publication using a single transaction.
1. The package `SHALL` not introduction publication conflicts with the Econia v4
   package, such that it can be published at the same address, for example by
   using non-overlapping module names.

### Indexer

1. The "Data Service Stack" `SHALL` be renamed the "indexer".
1. The indexer `SHALL` track a single table with rows for the last updated
   transaction version number for each pipeline.

[rfc 2119]: https://www.ietf.org/rfc/rfc2119.txt
[`aptos-core` #11950]: https://github.com/aptos-labs/aptos-core/pull/11950
[`aptos-core` #12240]: https://github.com/aptos-labs/aptos-core/pull/12240
