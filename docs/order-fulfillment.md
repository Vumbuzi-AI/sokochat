# Collection and delivery

Business now stores pickup availability, the pickup address (`location`), opening hours, an optional map link, delivery availability, and up to eight delivery areas with KES fees. A fee of zero explicitly means free delivery. Sellers can accept unlisted areas for a delivery quote.

## Website details

The existing public-site reader uses Floki to read JSON-LD addresses and opening hours, address tags, and map links. If needed, it follows one same-host contact/location link. Existing public-host and redirect restrictions apply. No Serper key is needed.

New-shop website imports populate factual contact details along with the existing AI brief. They do not enable pickup/delivery or invent rates. On Business, **Find details from website** fills only empty address, map and hours fields. The seller reviews and saves them. An unreachable site or unstructured page leaves manual entry available.

## Buyer flow

Request order → collection/delivery → delivery area and address if applicable → review → confirm. Unlisted areas display an unconfirmed fee, with no invented final total. Product prices remain estimates starting from the cheapest variant; final size, stock and payment are confirmed by the merchant.

Fulfilment details are scoped to a draft's shared line and buyer, then snapshotted with the merchant's order. Drafts expire after 30 minutes. Confirmation rechecks product and fulfilment settings. Confirmed requests retain their original fee. The merchant inbox displays only that merchant's requests and fulfilment details.

Shops with no fulfilment options configured retain the existing request flow, explicitly saying that collection, delivery and charges require merchant confirmation. Checkout actions remain disabled in the playground.

## Buyer contact and order references

Order requests have a stable public reference such as `SC-7D3F-A91C-8E2B`. Internal integer IDs still scope actions and webhook buttons. References are generated from six random bytes, protected by a unique index, and preserved across webhook replays, confirmation and contact status changes. Reference collisions retry up to three times. Migration `20261116070000_add_order_request_references` assigns references to existing requests and provides a database default for older writers during rollout.

The inbox labels the buyer's WhatsApp number and groups Kenyan and UAE numbers with binary pattern matching. Other international numbers retain their digits with a leading `+`; local or malformed values are never assigned a guessed country code. No phone-number dependency is used. **Chat on WhatsApp** opens a digits-only `wa.me` link in a new tab without sending a message or changing contact status. **Mark as contacted** remains a separate action. Missing or malformed numbers show recovery guidance instead of a chat link.

The deterministic WhatsApp confirmation includes the same reference and tells buyers to verify the business and agree on the item, total, delivery and payment details before paying. It confirms the request, not stock, payment or fulfilment. Replayed confirmations retain the caution.

Designs: [desktop inbox](https://doop.design/c/nbdU_ygDzg?frame=MBqG-MW6EV), [mobile inbox](https://doop.design/c/nbdU_ygDzg?frame=b77AOvuZvb), [buyer confirmation](https://doop.design/c/nbdU_ygDzg?frame=zGHJxuBcZ1).

## Design and release

Doop: https://doop.design/c/nbdU_ygDzg?frame=E7hoDvLPQB

The new migration is `20261113130000_add_order_fulfillment`. It was applied locally. The existing release server entrypoint runs migrations on startup, so deploy the web application normally. No Pi service changes or extra credentials are required.

Compilation and assets may be checked independently of tests. Regression tests cover website extraction, zero versus unquoted fees, incomplete addresses, rate changes, buyer/merchant scoping and removing the last delivery area. Tests and browser QA are left to Sean.
