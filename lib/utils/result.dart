sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  T? get data => this is Success<T> ? (this as Success<T>).data : null;
  String? get error => this is Failure<T> ? (this as Failure<T>).error : null;

  // Static factory methods
  static Result<T> success<T>([T? data]) => Success<T>(data);
  static Result<T> failure<T>(String error) => Failure<T>(error);

  R when<R>({
    required R Function(T? data) success,
    required R Function(String error) failure,
  }) {
    return switch (this) {
      Success(data: final d) => success(d),
      Failure(error: final e) => failure(e),
    };
  }
}

final class Success<T> extends Result<T> {
  @override
  final T? data;
  const Success([this.data]);
}

final class Failure<T> extends Result<T> {
  @override
  final String error;
  const Failure(this.error);
}
