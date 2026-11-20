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

  test('assessment bills contain only external scholars and group by schedule',
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
        [1, 2],
        [3],
        [4],
        [5],
        [9],
        [10],
      ],
    );
  });
}
