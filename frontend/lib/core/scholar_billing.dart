import 'dart:convert';

List<List<Map<String, dynamic>>> assessmentScholarGroups(
    Iterable<Map<String, dynamic>> assessees) {
  final groups = <String, List<Map<String, dynamic>>>{};
  for (final assessee in assessees) {
    final center = assessee['center'];
    if (assessee['assessment_candidate_type'] != 'external_scholar' ||
        center is! Map ||
        center['type'] != 'assessment') {
      continue;
    }

    final date = assessee['assessment_date']?.toString().trim() ?? '';
    final key = date.isEmpty
        ? jsonEncode(['undated', assessee['id']])
        : jsonEncode([
            assessee['assessment_center_id'],
            assessee['qualification'],
            date,
            assessee['assessor']?.toString().trim() ?? '',
          ]);
    groups.putIfAbsent(key, () => []).add(assessee);
  }
  return groups.values.toList();
}
