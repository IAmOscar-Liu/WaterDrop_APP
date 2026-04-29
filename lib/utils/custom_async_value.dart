/// Enum to represent the different states of an asynchronous operation.
enum CustomAsyncValueStatus {
  /// The initial state before any operation has started.
  initial,

  /// The state when an operation is in progress for the first time.
  loading,

  /// The state when fetching more data (e.g., for pagination).
  fetching,

  /// The state when updating data
  processing,

  /// The state when the operation has completed successfully.
  done,

  /// The state when the operation has failed.
  error,
}

/// A generic class to encapsulate the state of an asynchronous operation.
/// It holds the status, the data of type [T], and an error object.
class CustomAsyncValue<T> {
  /// The current status of the operation.
  final CustomAsyncValueStatus status;

  /// The data returned by the successful operation. Null if not done or on error.
  final T? data;

  /// The error object if the operation failed. Null otherwise.
  final dynamic error;

  /// Private constructor to enforce usage of factory constructors.
  const CustomAsyncValue._({required this.status, this.data, this.error});

  /// Creates an instance with the [initial] status.
  factory CustomAsyncValue.initial() {
    return const CustomAsyncValue._(status: CustomAsyncValueStatus.initial);
  }

  /// Creates an instance with the [loading] status.
  factory CustomAsyncValue.loading() {
    return const CustomAsyncValue._(status: CustomAsyncValueStatus.loading);
  }

  /// Creates an instance with the [fetching] status.
  /// Optionally keeps the previous data.
  factory CustomAsyncValue.fetching([T? previousData]) {
    return CustomAsyncValue._(
      status: CustomAsyncValueStatus.fetching,
      data: previousData,
    );
  }

  /// Creates an instance with the [processing] status.
  factory CustomAsyncValue.processing(T data) {
    return CustomAsyncValue._(
      status: CustomAsyncValueStatus.processing,
      data: data,
    );
  }

  /// Creates an instance with the [done] status and the resulting [data].
  factory CustomAsyncValue.done(T data) {
    return CustomAsyncValue._(status: CustomAsyncValueStatus.done, data: data);
  }

  /// Creates an instance with the [error] status and an [error] object.
  factory CustomAsyncValue.error(dynamic error) {
    return CustomAsyncValue._(
      status: CustomAsyncValueStatus.error,
      error: error,
    );
  }

  // --- Convenience Getters ---

  bool get isInitial => status == CustomAsyncValueStatus.initial;
  bool get isLoading => status == CustomAsyncValueStatus.loading;
  bool get isFetching => status == CustomAsyncValueStatus.fetching;
  bool get isProcessing => status == CustomAsyncValueStatus.processing;
  bool get isDone => status == CustomAsyncValueStatus.done;
  bool get hasError => status == CustomAsyncValueStatus.error;
  bool get hasData => data != null;

  @override
  String toString() {
    return 'CustomAsyncValue(status: $status, data: $data, error: $error)';
  }
}
