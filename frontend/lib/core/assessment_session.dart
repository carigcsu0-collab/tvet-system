String assessmentSessionLabel(Object? value) {
  final session = value?.toString().trim() ?? '';
  return session.isEmpty ? 'Whole Day' : session;
}
