import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/layout/root_layout.dart';
import 'package:flutter_ad_ecommerce/layout/tab_layout.dart';
import 'package:flutter_ad_ecommerce/models/order.dart';
import 'package:flutter_ad_ecommerce/pages/account_delivery_page.dart';
import 'package:flutter_ad_ecommerce/pages/advertisement_player_page.dart';
import 'package:flutter_ad_ecommerce/pages/cart_page.dart';
import 'package:flutter_ad_ecommerce/pages/chatroom_list_page.dart';
import 'package:flutter_ad_ecommerce/pages/chatroom_page.dart';
import 'package:flutter_ad_ecommerce/pages/collection_page.dart';
import 'package:flutter_ad_ecommerce/pages/ecpay_page.dart';
import 'package:flutter_ad_ecommerce/pages/explore_page.dart';
import 'package:flutter_ad_ecommerce/pages/fullscreen_video_player.dart';
import 'package:flutter_ad_ecommerce/pages/help_page.dart';
import 'package:flutter_ad_ecommerce/pages/home_page.dart';
import 'package:flutter_ad_ecommerce/pages/message_page.dart';
import 'package:flutter_ad_ecommerce/pages/mine_page.dart';
import 'package:flutter_ad_ecommerce/pages/order_page.dart';
import 'package:flutter_ad_ecommerce/pages/payment_settings_page.dart';
import 'package:flutter_ad_ecommerce/pages/photo_view_page.dart';
import 'package:flutter_ad_ecommerce/pages/product_page.dart';
import 'package:flutter_ad_ecommerce/pages/profile_page.dart';
import 'package:flutter_ad_ecommerce/pages/sign_in_page.dart';
import 'package:flutter_ad_ecommerce/pages/single_message_details.dart';
import 'package:flutter_ad_ecommerce/pages/single_order_details.dart';
import 'package:flutter_ad_ecommerce/pages/single_product_details.dart';
import 'package:flutter_ad_ecommerce/pages/text_search_page.dart';
import 'package:flutter_ad_ecommerce/pages/trade_document_page.dart';
import 'package:flutter_ad_ecommerce/pages/user_consent_page.dart';
import 'package:flutter_ad_ecommerce/router/routes.dart';
import 'package:go_router/go_router.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final tabRoutes = StatefulShellRoute.indexedStack(
  builder: (context, state, navigationShell) {
    return TabLayout(
      navigationShell: navigationShell,
      matchedLocation: state.matchedLocation,
    );
  },
  branches: [
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: Routes.homePage,
          builder: (context, state) => const HomePage(),
        ),
      ],
    ),
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: Routes.explorePage,
          builder: (context, state) => const ExplorePage(),
        ),
      ],
    ),
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: Routes.productPage,
          builder: (context, state) => const ProductPage(),
        ),
      ],
    ),
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: Routes.cartPage,
          builder: (context, state) => const CartPage(),
        ),
      ],
    ),
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: Routes.minePage,
          builder: (context, state) => const MinePage(),
          routes: [
            GoRoute(
              path: "profile",
              builder: (context, state) => ProfilePage(),
            ),
          ],
        ),
      ],
    ),
  ],
);

GoRouter getRouter({
  String? initialLocation,
  required bool isLoggedIn,
  required bool isLoading,
  dynamic error,
  // void Function(Uri)? setDeepLinkUri,
}) {
  return GoRouter(
    navigatorKey: kReleaseMode ? _rootNavigatorKey : null,
    initialLocation: initialLocation ?? Routes.initialPage,
    routes: [
      ShellRoute(
        redirect: (context, state) {
          print("[redirect] root layout: ${state.matchedLocation}");

          // final uri = state.uri;
          // final isDeepLink = uri.hasScheme && uri.scheme.isNotEmpty;
          // print("[redirect] deep link: $isDeepLink");
          // if (isDeepLink && isLoading) {
          //   setDeepLinkUri?.call(uri);
          // }

          if (isLoading || error != null) return null;

          final inPrivatePage = state.matchedLocation != Routes.signIn;
          if (isLoggedIn && !inPrivatePage) {
            return Routes.homePage;
          } else if (!isLoggedIn) {
            return Routes.signIn;
          }
          return null;
        },
        builder: (context, state, navigationShell) {
          // print("root layout: ${state.matchedLocation}");
          return RootLayout(
            isLoggedIn: isLoggedIn,
            isLoading: isLoading,
            error: error,
            navigationShell: navigationShell,
          );
          // if (isLoading) {
          //   return Scaffold(
          //     backgroundColor: AppColors.primaryColor,
          //     body: Center(child: CircularProgressIndicator()),
          //   );
          // } else if (error != null) {
          //   return Scaffold(
          //     backgroundColor: AppColors.primaryColor,
          //     body: Center(
          //       child: Text(
          //         "Failed to login $error",
          //         style: TextStyle(color: Colors.white),
          //       ),
          //     ),
          //   );
          // }
          // return navigationShell;
        },
        routes: [
          // Auth routes
          GoRoute(
            path: Routes.signIn,
            builder: (context, state) => SignInPage(),
          ),
          // Private routes
          tabRoutes,
          GoRoute(
            path: Routes.messagePage,
            builder: (context, state) => const MessagePage(),
          ),
          GoRoute(
            path: Routes.accountDelivery,
            builder: (context, state) => AccountDeliveryPage(),
          ),
          GoRoute(path: Routes.help, builder: (context, state) => HelpPage()),
          GoRoute(
            path: Routes.advertisementVideoPlayer,
            builder: (context, state) =>
                AdvertisementPlayerPage(extra: state.extra),
          ),
          GoRoute(
            path: Routes.singleProductDetails,
            builder: (context, state) =>
                SingleProductDetails(extra: state.extra),
          ),
          GoRoute(
            path: Routes.textSearch,
            builder: (context, state) =>
                TextSearchPage(textSearch: state.extra as String),
          ),
          GoRoute(
            path: Routes.photoView,
            builder: (context, state) => PhotoViewPage(
              urlImages: (state.extra as Map)["urlImages"] as List<String>,
              index: (state.extra as Map)["index"],
            ),
          ),
          GoRoute(
            path: Routes.fullScreenVideoPlayerPage,
            builder: (context, state) =>
                FullScreenVideoPlayer(url: state.extra as String),
          ),
          GoRoute(
            path: Routes.chatroomListPage,
            builder: (context, state) => ChatroomListPage(),
          ),
          GoRoute(
            path: Routes.chatroomPage,
            builder: (context, state) => ChatroomPage(extra: state.extra),
          ),
          GoRoute(
            path: Routes.paymentSettingsPage,
            builder: (context, state) =>
                PaymentSettingsPage(extra: state.extra),
          ),
          GoRoute(
            path: Routes.ecPayPage,
            builder: (context, state) => ECPayPage(extra: state.extra),
          ),
          GoRoute(
            path: Routes.collectionPage,
            builder: (context, state) => CollectionPage(),
          ),
          GoRoute(
            path: Routes.orderPage,
            builder: (context, state) => OrderPage(),
          ),
          GoRoute(
            path: "${Routes.orderPage}/:id",
            builder: (context, state) {
              final id = state.pathParameters['id'];
              if (id == null) {
                return OrderPage();
              }
              return SingleOrderDetails(
                extra: {"orderId": id},
                openedFromDeepLink: true,
              );
            },
          ),
          GoRoute(
            path: Routes.singleOrderDetails,
            builder: (context, state) => SingleOrderDetails(extra: state.extra),
          ),
          GoRoute(
            path: Routes.tradeDocumentPage,
            builder: (context, state) =>
                TradeDocumentPage(delivery: state.extra as Delivery),
          ),
          GoRoute(
            path: Routes.singleMessageDetails,
            builder: (context, state) =>
                SingleMessageDetails(extra: state.extra),
          ),
          GoRoute(
            path: Routes.userConsentPage,
            builder: (context, state) => const UserConsentPage(),
          ),
        ],
      ),
    ],
  );
}
