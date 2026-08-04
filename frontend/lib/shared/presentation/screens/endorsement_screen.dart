import 'package:flutter/material.dart';
import '../../../core/constants.dart';
import 'document_screen.dart';

class EndorsementScreen extends StatelessWidget {
  const EndorsementScreen({super.key});

  static const List<FieldConfig> _fields = [
    FieldConfig(name: 'to', label: 'To (Name, Designation, Office, Address)'),
    FieldConfig(name: 'from', label: 'Thru (Office)'),
    FieldConfig(name: 'subject', label: 'Subject'),
    FieldConfig(name: 'body', label: 'Body', maxLines: 5),
  ];

  @override
  Widget build(BuildContext context) {
    return const DocumentScreen(
      slug: AppConstants.endorsementSlug,
      title: 'Endorsement',
      icon: Icons.verified,
      fields: _fields,
      showLetterhead: true,
    );
  }
}
