# Flutter Pagination

The shared list page size is **20**, configured by `AppConstants.paginationPageSize` in [app_constants.dart](../lib/constants/app_constants.dart). This is the requested maximum; a response can contain fewer items.

| Data | Endpoint | Previous requested limit | Current requested limit |
| --- | --- | --- | --- |
| Products | `GET /api/product/list` | 10 | 20 |
| Orders | `GET /api/order/list` | 10 | 20 |
| Collections | `GET /api/collection/list` | 10 | 20 |
| Chatroom list | `GET /api/chatroom/list` | 10 | 20 |
| Notifications | `GET /api/notification/list` | 10 | 20 |
| Chat-message history and polling | `GET /api/chatroom/history/{chatRoomId}` | 9,999 | 9,999 (until scroll pagination is implemented) |
| Advertisements | `GET /api/advertisement/list` | Up to 20 | Up to 20, capped by remaining allowance |

The five paginated lists use the same size for initial loads and subsequent pages. Collection membership checks also scan in pages of 20.

After marking a notification as read or deleting one, the app refreshes the pages already loaded using separate requests of 20 items each. It retains the server's total and page count so scrolling can continue. Previously this refresh requested `loadedPages × pageSize` in a single call and replaced totals with the number of loaded items.

Chat-message history currently loads up to 9,999 messages without an older-message pagination control. This limit is a workaround to expose history, not a requirement to fetch everything at once. The [chatroom SSE plan](FLUTTER_CHATROOM_SSE_API_PLAN.md) proposes loading the newest 20 messages, fetching 20 older messages when scrolling up, and using SSE for new messages/read receipts. The runtime limit remains 9,999 until scroll pagination is implemented so reducing it does not make older messages inaccessible.

Cart (`GET /api/cart/list`) and treasure-box (`GET /api/treasureBox/list`) requests do not send pagination parameters. Their response size is determined by the backend. This change does not introduce pagination for these endpoints or change backend defaults.
