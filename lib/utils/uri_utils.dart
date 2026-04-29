class UriUtils {
  /// A utility function to create a Uri with query parameters.
  ///
  /// [scheme] is the URI scheme, e.g., 'https' or 'http'.
  /// [authority] is the authority, e.g., 'api.example.com'.
  /// [unencodedPath] is the path, e.g., '/users/search'.
  /// [queryParams] is a map of key-value pairs for the query string.
  /// The values in the map will be converted to strings.
  static Uri buildUri({
    required String scheme,
    required String authority,
    required String unencodedPath,
    Map<String, dynamic>? queryParams,
  }) {
    // The Uri constructor handles the proper encoding of query parameters.
    // We convert all values in the queryParams map to strings.
    final Map<String, String>? stringQueryParameters = queryParams?.map(
      (key, value) => MapEntry(key, value.toString()),
    );

    return Uri(
      scheme: scheme,
      host: authority,
      path: unencodedPath,
      queryParameters: stringQueryParameters,
    );
  }

  /// A utility function to add query parameters to an existing URL string.
  ///
  /// [baseUrl] is the full URL string you want to add parameters to.
  /// [queryParams] is a map of key-value pairs for the query string.
  /// If the [baseUrl] already contains query parameters, the new ones will be
  /// merged with them. If there are conflicting keys, the new ones from
  /// [queryParams] will overwrite the existing ones.
  static Uri addQueryParamsToUrl({
    required String baseUrl,
    Map<String, dynamic>? queryParams,
  }) {
    if (queryParams == null || queryParams.isEmpty) {
      return Uri.parse(baseUrl);
    }

    // Parse the base URL into a Uri object.
    final Uri baseUri = Uri.parse(baseUrl);

    // Make a mutable copy of the existing query parameters.
    final Map<String, dynamic> allQueryParams = Map<String, dynamic>.from(
      baseUri.queryParametersAll,
    );

    // Convert the new query parameters to strings and add them to the map.
    // This will overwrite any existing keys with the new values.
    queryParams.forEach((key, value) {
      if (value is Iterable) {
        allQueryParams[key] = value.map((e) => e.toString()).toList();
      } else {
        allQueryParams[key] = [value.toString()];
      }
    });

    // Create a new Uri with the updated query parameters.
    return baseUri.replace(queryParameters: allQueryParams);
  }
}
