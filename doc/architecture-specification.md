<!--- cspell:words evictable, incentivized -->

# Econia v5 Architecture Specification

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
1. Price `SHALL` be restricted to a certain number of significant figures, based
   on the market, per [`aptos-core` #11950].
1. The minimum permissible post amount `SHALL` be mediated via dynamic eviction
   eviction criteria.

### Significant figures

1. Price `SHALL` be restricted to a certain number of significant figures per
   market.
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
   liquidity.
1. The dynamic calculations `SHALL NOT` use a logarithmic formula to calculate
   minimum post size so as to avoid distortions between assets with different
   decimal amounts.

## Dynamics

### Fees

1. Fee rates `SHALL` be encoded as `u8` values, enabling fees up to 2.55%.
1. Taker fees, assessed on the taker side of the trade, `SHALL` default to 0 for
   every new market, with a governance override enabling a new fee rate for
   select markets.
1. Integrators `SHALL` have the ability to collect fees via an
   `integrator_fee_rate_bps: u8` argument on public functions, deposited into an
   integrator's market account, to enable parallelism for integrators who
   facilitate trades across multiple markets. Hence there `SHALL` also be an
   `integrator_market_account: Object<T>` argument. Integrator fees `SHALL` be
   assessed in the quote asset for the pair.
1. The market's liquidity pool `SHALL` also charge a fee, mediated via market
   parameters, denominated in basis points. Within liquidity pool operations
   fees must be assessed in both base and quote, but `SHALL` be normalized to
   quote-only outside of liquidity pool operations.

### Eviction

1. Markets `SHALL` permit a fixed tree height per side, for example 5.
1. Orders `SHALL` be evicted if the ratio formed by their price and the best ask
   or bid price exceeds a fixed value, for example 10.
1. Eviction from anywhere in the price-time queue `SHALL` be enabled via a
   public API available outside of order posting.
1. Public eviction APIs `MAY` be incentivized via an eviction bounty for a fixed
   amount of the remaining collateral available on an evictable order, for
   example 5 basis points, deposited straight to the eviction executor's market
   account. If bounties are available, they `SHALL` be assessed on either all
   evictions or none, including those instigated by order posts, such that
   orders at the back of the price-time queue are not immune from bounty loss.
1. Should a bounty not be implemented for fear of promoting adversarial
   behaviors, eviction stewardship for the middle of the price-time queue `MAY`
   be implemented as a duty good, whereby oracle operations that access order
   book state, for example, (or even those that do not) are required to randomly
   scan the order book for the given market and evict orders as needed.
1. When an order is placed, the head and tail of the book for the given side
   `MAY` be checked, and evicted if market eviction criteria are met to ensure
   that eviction is at least checked during tree grow operations.

### Oracle queries

1. Queries for information like best bid/ask `SHALL` be possible through public
   APIs, to enable composability. These APIs `MAY` charge a small amount, for
   example 100 octas, to reduce excessive queries for contended state.
1. Oracle fees `SHALL` be paid to a primary fungible store for each market,
   denominated in the protocol utility coin, with the oracle query amount
   tracked in a global registry.
1. Runtime oracle functions `SHALL` be implemented as a public wrapper around
   private view functions.

### Trading

1. Orders `SHALL` accept the object address of a user's market account, as well
   as a size, limit price (worst execution price including fees), and
   restriction.
1. Limit orders, market orders, and swaps `SHALL` be moderated via a single API
   that uses `HI_64` or `0` to indicate an immediate-or-cancel market order.
1. Orders `SHALL` fill outside of a market account if the market account object
   address is passed as `0x0`.
1. Size changes and order cancellations `SHALL` accept the price of the order to
   cancel for the given user and market account object address.
1. Posting `SHALL NOT` be permitted outside of a market account.
1. Restrictions and self match behavior `SHALL NOT` moderate behavior via abort
   statements, since this approach inhibits ease of indexing.
1. Self match behavior `SHALL` support `CANCEL_BOTH`, `CANCEL_MAKER`, and
   `CANCEL_TAKER` options.
1. Order restrictions `SHALL` support `NO_RESTRICTION`, `FILL_OR_KILL`,
   `POST_ONLY`, and `IMMEDIATE_OR_CANCEL`.

### Transaction sponsorship

1. Each market `SHALL` include fungible asset stores, that anyone can deposit
   into, to enable transaction sponsorship. Transaction sponsorship `MAY` be
   further segmented into specific buckets for things like placing limit orders,
   placing swaps, etc.
1. Users `MAY` be provided with the ability to pre-pay their own transactions,
   and have their sponsorship bucket be used only after applicable global
   transaction sponsorship.

## Data structures

### Registry

1. Recognized markets `SHALL` map from trading pair to market ID, using an
   `aptos_std::smart_table::SmartTable` since it is an ordered map that will not
   be subject to the same attack vectors as maps with a public insertion vector.
1. Market IDs `SHALL` be 1-indexed.

### Market accounts

1. A user's open orders `SHALL` be tracked via a red-black binary search tree,
   with order price as the lookup key. Hence each user will only be able to have
   one open order at a given price. The red-black tree `MAY` cache the location
   of the last accessed key so that operations to check existence then borrow
   can occur without re-traversal. Bid and ask trees for a user `MAY` be
   combined into one single tree.
1. Only available and total amounts for base and quote `SHALL` be tracked, since
   deposits will be held in a global vault in order to reduce borrows. Since
   anyone can deposit into the global vault store, there is no way to ensure the
   global ceiling is static.
1. When a user deposits to or withdraws from their market account, assets
   `SHALL` transact against a global base/quote vault for the entire market.
1. There `SHALL` be a hard-coded constant restricting the number of open orders
   each user is allowed to have.
1. Each user `SHALL` have a market accounts map of type
   `aptos_std::smart_table::SmartTable` which lists the markets they have open
   market accounts for.

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
1. Orders `SHALL` stipulate the original size or volume posted, such that they
   can be evaluated for eviction.
1. An order that would post to the tail of a queue that is above the eviction
   height threshold `SHALL` be prohibited from posting.

### Order books

1. Order books `SHALL` implement a B+ tree-based architecture, with each key
   containing a price and an effective sequence number for that price,
   denoting the price-time priority of the order, represented as a `u256` of the
   form `price_as_decimal_fixed_u128 << 64 | sequence_number_flag`. The
   sequence number for the level `SHALL` be generated dynamically upon insertion
   such that the first order at a new price level assumes the sequence number 1.
1. Each market `SHALL` have a B+ tree for each side, which caches the best price
   and its leaf node's address, and has a sort order direction such that the
   sequence number flag for bids, of descending sort order direction, is
   `HI_64 - sequence_number_at_level`. The tail of the tree `SHALL NOT` be
   cached, to avoid serialization griefing from the worst order in the queue.
1. The B+ tree `MAY` track its height at the root node, for ease of eviction
   monitoring, though insertion and lookup mechanics will be able to track
   height on the fly.

### Extensions

1. Core data structures `SHALL` include `aptos_framework::any::Any`,
   `aptos_framework::copyable_any::Any`, or similar `extension` fields
   to enable unforeseen backwards-compatible feature upgrades.

## Implementation details

### Matching

1. The matching engine `SHALL` implement a two-phase model to first evaluate a
   match, then commit it, with an intermediate "match result" data structure
   that tabulates the orders to fill/decrement, self match orders to cancel,
   pool changes, etc.
1. The intermediate match result `SHALL` be considered before evaluating
   fill-or-kill orders.
1. The intermediate match result `SHALL` be made publicly available during
   runtime via an oracle function.

### Eviction

1. Eviction price `SHALL` be mediated via optimistic division only per
   [`aptos-core` #11952], via `eviction_price_divisor_ask` and `_bid`, such that
   the proposed ask price is divided by the best ask price, and the best bid
   price is divided by the proposed bid price before threshold comparisons.
1. Eviction of a full order book `SHALL NOT` be possible within a single
   transaction.
1. Eviction liquidity divisors `SHALL` similarly be mediated via optimistic
   division.

### Error codes

1. Error codes that are raised by multiple functions `SHALL` be wrapped with
   inline helper functions containing a single assert, so that the inline
   function can be failure tested, for ease of coverage.

### Events

1. Market registration events `SHALL` include fungible asset metadata like
   decimals for ease of indexing.
1. Market orders and limit orders `SHALL` use the same event structure, which
   `MAY` be common to swaps.

### Withdrawals

1. Since fungible assets may be seized at any time, deposits and withdrawals
   `SHALL` be assessed proportionally to socialize losses and avoid bank run
   scenarios: if vaults are 50% empty, then deposits will be 50% of expected.

### Parameter updates

1. Market parameter updates for a given market `SHALL` be updated in multiple
   places in the registry since data is indexed in multiple ways.
1. Market parameters `SHALL` be set via APIs that accept a vector for each
   field, representing an option where `some` corresponding to an update. Market
   ID `SHALL` be offered as a field, and if `none` the update corresponds to
   default parameter updates.

### Package size

1. Move package size `SHALL` be under the max transaction limit, to enable
   package publication using a single transaction.

### Indexer

1. The "Data Service Stack" `SHALL` be renamed the "indexer".
1. The indexer `SHALL` track a single table with rows for the last updated
   transaction version number for each pipeline.

[rfc 2119]: https://www.ietf.org/rfc/rfc2119.txt
[`aptos-core` #11950]: https://github.com/aptos-labs/aptos-core/pull/11950
[`aptos-core` #11952]: https://github.com/aptos-labs/aptos-core/pull/11952
