import 'package:flutter_test/flutter_test.dart';
import 'package:tvet_documents/core/assessment_session.dart';
import 'package:tvet_documents/core/scholar_billing.dart';

void main() {
  test('blank assessment sessions are whole day', () {
    expect(assessmentSessionLabel(null), 'Whole Day');
    expect(assessmentSessionLabel(''), 'Whole Day');
    expect(assessmentSessionLabel(' '), 'Whole Day');
    expect(assessmentSessionLabel('AM'), 'AM');
    expect(assessmentSessionLabel('PM'), 'PM');
  });

  test(
      'assessment bills contain only external scholars and group consecutive dates',
      () {
    Map<String, dynamic> record(int id,
            {String category = 'external_scholar',
            String? date = '2026-11-20',
            String assessor = 'Assessor A',
            int centerId = 1,
            String centerType = 'assessment'}) =>
        {
          'id': id,
          'assessment_candidate_type': category,
          'assessment_center_id': centerId,
          'center': {'type': centerType},
          'qualification': 'EIM',
          'assessment_date': date,
          'assessor': assessor,
        };

    final groups = assessmentScholarGroups([
      record(1),
      record(2),
      record(3, date: '2026-11-21'),
      record(4, assessor: 'Assessor B'),
      record(5, centerId: 2),
      record(6, category: 'external_walk_in'),
      record(7, category: 'internal'),
      record(8, centerType: 'training'),
      record(9, date: null),
      record(10, date: ''),
    ]);

    expect(
      groups.map((group) => group.map((record) => record['id']).toList()),
      [
        [1, 2, 3],
        [4],
        [5],
        [9],
        [10],
      ],
    );
    expect(assessmentScholarDateLabel(groups.first), 'November 20-21, 2026');
  });

  test(
      'grouping handles gaps, mixed date formats, month boundaries and invalid dates',
      () {
    Map<String, dynamic> record(int id, String? date) => {
          'id': id,
          'assessment_candidate_type': 'external_scholar',
          'assessment_center_id': 1,
          'center': {'type': 'assessment'},
          'qualification': 'EIM',
          'assessment_date': date,
          'assessor': 'Lorenzo Macababbad',
        };
    final groups = assessmentScholarGroups([
      record(1, '12/1/26'),
      record(2, '2026-11-30'),
      record(3, '11/30/26'),
      record(4, '12/3/26'),
      record(5, 'not a date'),
      record(6, 'not a date'),
      record(7, null),
      record(8, '11/30/2026'),
    ]);

    expect(groups.map((group) => group.length), [4, 1, 1, 1, 1]);
    expect(assessmentScholarDateLabel(groups[0]),
        'November 30, 2026 - December 1, 2026');
    expect(assessmentScholarDateLabel(groups[1]), 'December 3, 2026');
    expect(assessmentScholarDateLabel(groups[2]), 'Invalid date: not a date');
    expect(assessmentScholarDateLabel(groups[4]), 'Date not set');
  });

  test('consecutive dates without an assessor are not combined', () {
    final records = [
      for (final date in ['11/14/26', '11/15/26'])
        {
          'id': date,
          'assessment_candidate_type': 'external_scholar',
          'assessment_center_id': 1,
          'center': {'type': 'assessment'},
          'qualification': 'EIM',
          'assessment_date': date,
          'assessor': '',
        },
    ];
    expect(assessmentScholarGroups(records).length, 2);
  });
}
