import 'dart:convert';

import 'package:intl/intl.dart';

DateTime? _assessmentDate(Object? value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return null;
  final formats = [
    DateFormat('yyyy-MM-dd'),
    DateFormat('M/d/yy'),
    DateFormat('M/d/yyyy'),
  ];
  for (final format in formats) {
    try {
      final date = format.parseStrict(text, true);
      return DateTime.utc(date.year, date.month, date.day);
    } on FormatException {
      continue;
    }
  }
  return null;
}

List<List<Map<String, dynamic>>> assessmentScholarGroups(
    Iterable<Map<String, dynamic>> assessees) {
  final schedules = <String, List<Map<String, dynamic>>>{};
  final undated = <List<Map<String, dynamic>>>[];
  for (final assessee in assessees) {
    final center = assessee['center'];
    if (assessee['assessment_candidate_type'] != 'external_scholar' ||
        center is! Map ||
        center['type'] != 'assessment') {
      continue;
    }

    final date = _assessmentDate(assessee['assessment_date']);
    if (date == null) {
      undated.add([assessee]);
      continue;
    }
    final assessor = assessee['assessor']?.toString().trim() ?? '';
    final key = jsonEncode([
      assessee['assessment_center_id'],
      assessee['qualification'],
      assessor,
      if (assessor.isEmpty) date.toIso8601String(),
    ]);
    schedules.putIfAbsent(key, () => []).add(assessee);
  }

  final groups = <List<Map<String, dynamic>>>[];
  for (final schedule in schedules.values) {
    schedule.sort((a, b) => _assessmentDate(a['assessment_date'])!
        .compareTo(_assessmentDate(b['assessment_date'])!));
    List<Map<String, dynamic>>? group;
    DateTime? previousDate;
    for (final assessee in schedule) {
      final date = _assessmentDate(assessee['assessment_date'])!;
      if (previousDate == null || date.difference(previousDate).inDays > 1) {
        group = <Map<String, dynamic>>[];
        groups.add(group);
      }
      group!.add(assessee);
      previousDate = date;
    }
  }
  return [...groups, ...undated];
}

String assessmentScholarDateLabel(List<Map<String, dynamic>> scholars) {
  final first = _assessmentDate(scholars.first['assessment_date']);
  if (first == null) {
    final text = scholars.first['assessment_date']?.toString().trim() ?? '';
    return text.isEmpty ? 'Date not set' : 'Invalid date: $text';
  }
  final last = _assessmentDate(scholars.last['assessment_date'])!;
  if (first == last) return DateFormat('MMMM d, yyyy').format(first);
  if (first.year == last.year && first.month == last.month) {
    return '${DateFormat('MMMM d').format(first)}-${DateFormat('d, yyyy').format(last)}';
  }
  return '${DateFormat('MMMM d, yyyy').format(first)} - ${DateFormat('MMMM d, yyyy').format(last)}';
}
