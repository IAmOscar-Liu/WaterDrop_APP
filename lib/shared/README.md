# Shared UI

Reusable application UI lives here. Import the specific file you need using
`package:flutter_ad_ecommerce/shared/...`.

| Location | Components and use |
| --- | --- |
| `layouts/app_scaffold.dart` | Standard page background, app bar slot, optional safe area and keyboard dismissal. Keep `PopScope` and navigation callbacks in the page. |
| `layouts/draggable_details_sheet.dart` | Half-height expandable detail modal, shared by shipment and refund history. Attach the provided scroll controller to the body list. Header builders receive a sheet context for dismissing that modal. |
| `widgets/app_panel.dart` | Bordered, rounded account and checkout surface with caller-controlled margins. |
| `widgets/section_panel.dart` | Panel heading, optional icon/badge, divider, and feature content. |
| `widgets/detail_rows.dart` | `DetailRow` for descriptive values and optional trailing actions; `SummaryRow` for amounts and totals. Callers format values and calculate totals. |
| `widgets/receiver_info_panel.dart` | Read-only shipping and bank details used by cart and payment settings. Takes account data without watching providers. |
| `widgets/filter_button.dart` | Selected/unselected filter presentation; callers own state and callbacks. |
| `widgets/search_filter_button.dart` | Search-query filter used by products, collections, and messages. |
| `widgets/status_badge.dart` | Text/color badge presentation. Enum labels and colors stay in feature adapters. |
| `widgets/product_thumbnail.dart` | Product thumbnails in cart, checkout, and orders, including loading/error/initial fallbacks. Callers select the image URL. |
| `widgets/selection_option_tile.dart` | Selection row shared by product variants and the cart quantity dialog, with formatted values and an optional preview action. |
| `widgets/simple_app_bar.dart` | Common app bar, including optional subtitle and actions. |
| `widgets/messaging_app_bar.dart` | App bar with the application notification action and unread count. |
| `widgets/page_status.dart` | Loading, error, and empty-list content. |
| Other `widgets/` files | Existing app version, badge count, initial image, and keyboard-dismiss components. |

## Migration

- Former `lib/widgets/*` imports now use `lib/shared/widgets/*`.
- `OrderDetailRow` and `OrderSummaryRow` are now `DetailRow` and `SummaryRow`
  in `shared/widgets/detail_rows.dart`.
- Repeated receiver panels, summary rows, filter styles, standard page surfaces,
  bordered panels, and draggable detail-sheet behavior use these components.

## Boundaries

The review covered the Dart pages, feature widgets, routing/layouts, providers,
models, services, utilities, and existing tests. Native platform configuration,
generated files, and assets do not need UI extraction.

Keep order/refund rules, product variants, checkout validation, API calls,
provider lifecycles, and media playback in their existing feature or application
directories. Root/tab navigation layouts remain in `lib/layout`; existing
non-UI utilities and color constants retain their current locations.

Promote a component when real consumers share its presentation or behavior.
Pass data and callbacks into shared UI, preserving caller-specific spacing,
scroll controllers, navigation guards, and async handling. Avoid moving an
entire feature widget here merely because it contains a card or dialog.
