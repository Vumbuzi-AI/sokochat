# Collection and delivery

Business now stores pickup availability, the pickup address (`location`), opening hours, an optional map link, delivery availability, and up to eight delivery areas with KES fees. A fee of zero explicitly means free delivery. Sellers can accept unlisted areas for a delivery quote.

## Website details

The existing public-site reader uses Floki to read JSON-LD addresses and opening hours, address tags, and map links. If needed, it follows one same-host contact/location link. Existing public-host and redirect restrictions apply. No Serper key is needed.

New-shop website imports populate factual contact details along with the existing AI brief. They do not enable pickup/delivery or invent rates. On Business, **Find details from website** fills only empty address, map and hours fields. The seller reviews and saves them. An unreachable site or unstructured page leaves manual entry available.

## Buyer flow

Request order → collection/delivery → delivery area and address if applicable → review → confirm. Unlisted areas display an unconfirmed fee, with no invented final total. Product prices remain estimates starting from the cheapest variant; final size, stock and payment are confirmed by the merchant.

Fulfilment details are scoped to a draft's shared line and buyer, then snapshotted with the merchant's order. Drafts expire after 30 minutes. Confirmation rechecks product and fulfilment settings. Confirmed requests retain their original fee. The merchant inbox displays only that merchant's requests and fulfilment details.

Shops with no fulfilment options configured retain the existing request flow, explicitly saying that collection, delivery and charges require merchant confirmation. Checkout actions remain disabled in the playground.

## Design and release

Doop: https://doop.design/c/nbdU_ygDzg?frame=E7hoDvLPQB

The new migration is `20261113130000_add_order_fulfillment`. It was applied locally. The existing release server entrypoint runs migrations on startup, so deploy the web application normally. No Pi service changes or extra credentials are required.

Compilation and assets may be checked independently of tests. Regression tests cover website extraction, zero versus unquoted fees, incomplete addresses, rate changes, buyer/merchant scoping and removing the last delivery area. Tests and browser QA are left to Sean.
