class CatalogState<T> {
  const CatalogState({
    this.data,
    this.loading = false,
    this.cached = false,
    this.failed = false,
  });

  const CatalogState.loaded(T value) : this(data: value);

  const CatalogState.restored(T value)
    : this(data: value, loading: true, cached: true);

  final T? data;
  final bool loading;
  final bool cached;
  final bool failed;

  CatalogState<T> start() =>
      CatalogState(data: data, loading: true, cached: cached);

  CatalogState<T> fail() =>
      CatalogState(data: data, cached: data != null, failed: true);
}
