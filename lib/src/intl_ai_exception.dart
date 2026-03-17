class IntlAiException implements Exception {
  const IntlAiException(this.message);

  final String message;

  @override
  String toString() => 'IntlAiException: $message';
}
