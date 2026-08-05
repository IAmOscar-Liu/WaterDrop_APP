# Product Variants Flutter UI Plan

## Goal

Support multiple variants per product across product discovery, cart, checkout, orders, and chat UI using the API contracts in `PRODUCT_VARIANTS_API_CHANGES.md`.

## TODO

- [x] 1. Data Model And Shared Helpers
- [x] 2. Cart Provider API Changes
- [x] 3. Optimistic Cart Merge Behavior
- [x] 4. Advertisement Video Add-To-Cart
- [x] 5. Single Product Page
- [x] 6. Cart Page UI
- [x] 7. Order Details UI
- [x] 8. Chatroom List UI
- [x] 9. ECPay Checkout Payload
- [ ] 10. Verification

## 1. Data Model And Shared Helpers

- Add a reusable `ProductVariant` model in `lib/models/product.dart` with fields from the public summary/detail shapes: `id`, `productId`, `name`, `sku`, `optionValues`, `availableStock`, `status`, and optional detail fields (`stock`, `reserve`, `sortOrder`, `metadata`, timestamps).
- Extend `Product` with:
  - `variants: List<ProductVariant>`
  - `availableStock`
  - optional `variant` for purchased/chatroom contexts where backend returns `product.variant`.
- Add display helpers for variant labels:
  - prefer `variant.name`
  - otherwise render `optionValues` as a compact `key: value` string
  - fallback to SKU, then `規格`
- Extend `CartItem` with `productVariantId` and `variant`, and make `copyWith` support both.
- Extend `OrderItem` with `productVariantId`, `variantNameAtSale`, `variantSkuAtSale`, `variantOptionValuesAtSale`, and `variantAtSale`, with a helper/display getter that prefers snapshot fields over live `product.variant`.
- Extend `DeliveryItem` similarly if delivery item UI needs historical variant display.
- Extend `Chatroom` with `productVariantId` and `variant`.
- Extend `Advertisement` parsing so `GET /api/advertisement/list` can expose `product.variants` for video add-to-cart selection. Prefer storing the nested `Product? product` or at least `variants`.

## 2. Cart Provider API Changes

- Change cart mutations to identify rows by `(productId, variantId)` instead of only `productId`.
- Update `addCartItem(productId, {variantId, productName})` to send:
  - `productId`
  - `productVariantId` or `variantId`, matching backend's Flutter cart contract after confirming current endpoint naming.
  - `quantity`
- Update `updateItemQuantity` into a more general update method, for example `updateCartItem(productId, currentVariantId, {quantity, variantId})`.
- Update `toggleCartItem` and `removeItem` to include `variantId` so same product with different variants is handled independently.
- Preserve existing `loadCartItems(keepPreviousData: true)` reconciliation after server responses.

## 3. Optimistic Cart Merge Behavior

- Keep optimistic update for quantity/checked/remove.
- When updating a cart item to another variant that already exists for the same product:
  - immediately merge the two local rows before waiting for fresh cart data
  - summed quantity = source quantity + target quantity unless the dialog explicitly supplies a different source quantity, in which case use target quantity + new source quantity
  - checked = source checked OR target checked
  - remove the source row from local state
- When updating to a new/non-existing variant:
  - update the row's variant fields and quantity locally
  - preserve checked state
- If the API request fails, return a failure and reload cart data to correct optimistic state.

## 4. Advertisement Video Add-To-Cart

- Update both video add-to-cart surfaces:
  - `lib/features/explore/widget/advertisement_page_view.dart`
  - `lib/pages/advertisement_player_page.dart`
- Keep the add-to-cart button at the lower right.
- If the advertised product has 0 or 1 active variant, add directly with the sole/default variant id.
- If there are more than 1 active variants, show a lightweight overlay/bottom sheet/dropdown anchored near the cart button.
- Do not pause the video when showing the variant selector.
- Selector content:
  - product name
  - variant list with available stock
  - disabled state for out-of-stock/inactive variants
  - add action calls cart provider with selected variant id.

## 5. Single Product Page

- In `lib/pages/single_product_details.dart`, track selected variant in state.
- For products with more than 1 active variant and visible `加入購物車`:
  - render a segmented button/chip group before the action buttons
  - require a selected variant before enabling/calling `加入購物車`
  - show selected variant stock instead of product-level stock where applicable.
- If `hideAddCartItemButton == true` and variants exist:
  - render a read-only variants card/list instead of the selector
  - include variant label and available stock.
- For products with one active variant, auto-select it and keep UI minimal.

## 6. Cart Page UI

- In `lib/features/cart/widgets/cart_item_card.dart`:
  - show variant name under product name when not null/empty
  - pass `productVariantId` when opening chatroom.
  - rename `修改數量` to `修改`.
- Replace/extend `QuantityDialog` into an edit dialog that supports:
  - quantity stepper/input
  - variant picker when the product has multiple active variants
  - returns both quantity and selected variant.
- In `lib/pages/cart_page.dart`, wire each card by cart item identity `(productId, productVariantId)` and call the new provider update method.
- Make sure checkout totals still use checked cart rows and multiply by shared product price.

## 7. Order Details UI

- In `lib/features/order/widgets/order_item_list.dart`, show the historical variant label under `productNameAtSale`.
- In `lib/pages/single_order_details.dart`, when contacting support for an order item, include `productVariantId` in `Routes.chatroomPage` extra.
- Ensure delivery item grouping/matching uses both product id and variant id if current code filters by product id.

## 8. Chatroom List UI

- In `lib/pages/chatroom_list_page.dart`, show `chatRoom.variant` display label under the product name when present.
- Include `productVariantId` in chatroom route extras where a product-specific room is opened/created.
- Keep support chatrooms unchanged (`productId == null`, `productVariantId == null`).

## 9. ECPay Checkout Payload

- In `lib/pages/ecpay_page.dart`, change both pickup group payload shapes:
  - `productIds: [...]` becomes `products: [{ productId, variantId }]`
  - apply to every `cvsPickupGroup` and `nonCvsPickupGroup`.
- Preserve group-level fields such as `receiver`, `receiverStore`, `logisticsSubType`, and delivery category.
- Confirm whether backend expects field name `products` or compatibility field `productIds` with object elements before final implementation. User request says `products`, so default to `products`.

## 10. Verification

- Run `dart format` on changed Dart files.
- Run `flutter analyze` or `fvm flutter analyze` using the repo's existing workflow.
- Manually smoke-test these flows if a simulator/device is available:
  - add from advertisement with multiple variants while video keeps playing
  - add from single product page
  - edit cart quantity only
  - edit cart variant to a new variant
  - edit cart variant to an existing row and verify optimistic merge
  - checkout ECPay payload construction
  - order detail and chatroom list variant labels.
