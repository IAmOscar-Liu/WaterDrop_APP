import 'package:flutter_ad_ecommerce/app_flavor.dart';

String? normalizeDeepLinkLocation(Uri uri) {
  final nestedLink = uri.queryParameters['link'];
  if (nestedLink != null && nestedLink.isNotEmpty) {
    return normalizeDeepLinkLocation(Uri.parse(nestedLink));
  }

  if (_isAppLinkHost(uri)) {
    return _pathWithQuery(uri);
  }

  if (_isCustomScheme(uri)) {
    final path = uri.path.isNotEmpty ? uri.path : '';
    final hostPath = uri.host.isNotEmpty ? '/${uri.host}' : '';
    final location = '$hostPath$path';
    return _withQuery(location.isEmpty ? '/' : location, uri);
  }

  return null;
}

bool _isAppLinkHost(Uri uri) {
  if (uri.scheme != 'https') return false;

  switch (AppFlavor.current) {
    case AppFlavor.dev:
      return uri.host == 'api.waterdropping.com';
    case AppFlavor.stg:
      return uri.host == 'stg-api.waterdropping.com';
  }
}

bool _isCustomScheme(Uri uri) {
  switch (AppFlavor.current) {
    case AppFlavor.dev:
      return uri.scheme == 'waterdrop-dev';
    case AppFlavor.stg:
      return uri.scheme == 'waterdrop-stg';
  }
}

String _pathWithQuery(Uri uri) {
  return _withQuery(uri.path.isEmpty ? '/' : uri.path, uri);
}

String _withQuery(String path, Uri uri) {
  if (uri.query.isEmpty) return path;
  return '$path?${uri.query}';
}
