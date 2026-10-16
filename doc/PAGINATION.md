# Flutter Pagination

The shared list page size is **20**, configured by `AppConstants.paginationPageSize` in [app_constants.dart](../lib/constants/app_constants.dart). This is the requested maximum; a response can contain fewer items.

| Data | Endpoint | Previous requested limit | Current requested limit |
| --- | --- | --- | --- |
| Products | `GET /api/product/list` | 10 | 20 |
| Orders | `GET /api/order/list` | 10 | 20 |
| Collections | `GET /api/collection/list` | 10 | 20 |
| Chatroom list | `GET /api/chatroom/list` (legacy) or `/api/chatroom/sync/list` (SSE enabled) | 10 | 20 |
| Notifications | `GET /api/notification/list` (legacy) or `/api/notification/sync/list` (SSE enabled) | 10 | 20 |
| Chat-message history | `GET /api/chatroom/sync/history/{chatRoomId}` (SSE enabled) | 9,999 | 20, with older-history cursor pagination |
| Legacy chat history and polling | `GET /api/chatroom/history/{chatRoomId}` (SSE disabled) | 9,999 | 9,999, retained for rollback |
| Advertisements | `GET /api/advertisement/list` | Up to 20 | Up to 20, capped by remaining allowance |

The five paginated lists use the same size for initial loads and subsequent pages. Product collection status comes from `isCollected` on product list/detail responses; it does not require scanning collection pages.

Notification SSE is enabled by default. Read/delete responses and events update items and unread counts directly, without reloading every page. Lists use query-bound snapshots and retain frozen page counts even when deletions leave short or empty pages. Text searches are refreshed through the server rather than approximating PostgreSQL matching locally. See the [notification sync contract](FLUTTER_NOTIFICATION_SSE_API_CHANGES.md).

With `NOTIFICATION_SSE_ENABLED=false`, the legacy notification path refreshes already-loaded pages after read/delete using separate requests of 20 items each, retaining server totals so scrolling can continue.

SSE is enabled by default. Chat history loads the newest 20 messages and fetches older messages in batches of 20 as the user scrolls up. A separate user-scoped SSE cursor handles live updates/replay. Chatroom lists use frozen membership/order snapshots so live reordering cannot skip rooms between pages. Setting `CHAT_SSE_ENABLED=false` selects the legacy rollback path with 9,999-message history and polling; see [configuration instructions](../README.md#chatroom-sse-rollout) and the [confirmed API contract](FLUTTER_CHATROOM_SSE_API_CHANGES.md).

Cart (`GET /api/cart/list`) and treasure-box (`GET /api/treasureBox/list`) requests do not send pagination parameters. Their response size is determined by the backend. This change does not introduce pagination for these endpoints or change backend defaults.
