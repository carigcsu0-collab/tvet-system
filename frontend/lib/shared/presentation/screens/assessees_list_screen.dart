import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/api_client.dart';
import '../../../core/app_theme.dart';
import '../widgets/ui_components.dart';
import 'attendance_print_screen.dart';

/// Formats typed digits into M/d/yy or MM/dd/yy on the fly.
/// e.g. 41205 -> 4/12/05, 041205 -> 04/12/05, 111205 -> 11/12/05.
class _NumericDateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }
    if (digits.length > 6) return oldValue;

    String formatted;
    if (digits.startsWith('0')) {
      if (digits.length <= 2) {
        formatted = digits;
      } else if (digits.length <= 4) {
        formatted =
            '${digits.substring(0, 2)}/${digits.substring(2)}';
      } else {
        formatted =
            '${digits.substring(0, 2)}/${digits.substring(2, 4)}/${digits.substring(4)}';
      }
    } else {
      if (digits.length <= 1) {
        formatted = digits;
      } else if (digits.length <= 3) {
        formatted = '${digits[0]}/${digits.substring(1)}';
      } else if (digits.length == 4) {
        formatted =
            '${digits[0]}/${digits.substring(1, 3)}/${digits.substring(3)}';
      } else {
        formatted =
            '${digits.substring(0, 2)}/${digits.substring(2, 4)}/${digits.substring(4)}';
      }
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class AssesseesListScreen extends StatefulWidget {
  final String type;

  const AssesseesListScreen({
    super.key,
    required this.type,
  });

  @override
  State<AssesseesListScreen> createState() => AssesseesListScreenState();
}

class AssesseesListScreenState extends State<AssesseesListScreen> {
  List<dynamic>? _allAssessees;
  List<dynamic>? _assessees;
  List<dynamic>? _centers;
  List<dynamic>? _assessors;
  bool _loading = true;
  String? _error;
  final _search = TextEditingController();
  int? _selectedCenterId;
  String? _selectedQualification;
  String? _selectedDate;
  String? _selectedCompetency;
  String? _selectedAssessor;
  String? _selectedPaid; // 'Paid', 'Unpaid', or null
  Set<int> _selected = <int>{};
  final _tableScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tableScrollController.dispose();
    super.dispose();
  }

  /// Reloads assessees and centers. Called from the shell whenever this tab
  /// becomes visible, because the screen is kept alive inside an IndexedStack.
  Future<void> load() => _load();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiClient.get('/assessees?type=${widget.type}'),
        ApiClient.get('/centers'),
        ApiClient.get('/assessors'),
      ]);
      _allAssessees = results[0].data as List<dynamic>?;
      _centers = (results[1].data as List<dynamic>?)
              ?.where((c) => c['type']?.toString() == widget.type)
              .toList() ??
          [];
      _assessors = results[2].data as List<dynamic>?;
      // Drop a stale selection so the dropdown never points at a deleted center.
      if (_selectedCenterId != null &&
          !_centers!.any((c) => c['id'] == _selectedCenterId)) {
        _selectedCenterId = null;
      }
      if (_selectedQualification != null &&
          !_qualificationsFor(_selectedCenterId)
              .contains(_selectedQualification)) {
        _selectedQualification = null;
      }
      _applyFilters();
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  /// The center that offers [qualification], or null when it is not found.
  /// Centers of the same type share a name and address, so the qualification
  /// is what identifies which center record a person belongs to.
  int? _centerIdForQualification(String? qualification) {
    if (qualification == null) return null;
    for (final c in _centers ?? []) {
      final quals = (c['qualifications'] as List<dynamic>? ?? [])
          .map((q) => q.toString().trim());
      if (quals.contains(qualification)) return c['id'] as int?;
    }
    return null;
  }

  /// Every qualification offered by [centerId], or by all centers of this
  /// type when [centerId] is null. Centers can share a name and address but
  /// still offer different qualifications, so these are collected per center.
  List<String> _qualificationsFor(int? centerId) {
    final centers = _centers ?? [];
    final source =
        centerId == null ? centers : centers.where((c) => c['id'] == centerId);
    final quals = source
        .expand((c) => (c['qualifications'] as List<dynamic>? ?? []))
        .map((q) => q.toString().trim())
        .where((q) => q.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return quals;
  }

  List<Map<String, dynamic>> _assessorsForQualification(String? qualification) {
    final all = (_assessors ?? []).whereType<Map>().map((a) {
      final map = <String, dynamic>{};
      for (final entry in a.entries) {
        map[entry.key.toString()] = entry.value;
      }
      return map;
    }).toList();
    if (qualification == null || qualification.trim().isEmpty) {
      all.sort((a, b) =>
          (a['name']?.toString() ?? '').compareTo(b['name']?.toString() ?? ''));
      return all;
    }

    final filtered = all.where((a) {
      final quals = (a['qualifications'] as List<dynamic>? ?? [])
          .map((q) => q.toString().trim())
          .toSet();
      return quals.contains(qualification.trim());
    }).toList();
    filtered.sort((a, b) =>
        (a['name']?.toString() ?? '').compareTo(b['name']?.toString() ?? ''));
    return filtered;
  }

  void _applyFilters() {
    final query = _search.text.trim().toLowerCase();
    var list = _allAssessees ?? [];
    if (_selectedCenterId != null) {
      list = list
          .where((a) => a['assessment_center_id'] == _selectedCenterId)
          .toList();
    }
    if (_selectedQualification != null) {
      list = list
          .where(
              (a) => a['qualification']?.toString() == _selectedQualification)
          .toList();
    }
    if (_selectedDate != null) {
      list = list.where((a) {
        final d = _normalizeDate(a['assessment_date']);
        return d == _selectedDate;
      }).toList();
    }
    if (_selectedCompetency != null) {
      list = list
          .where((a) => a['competency']?.toString() == _selectedCompetency)
          .toList();
    }
    if (_selectedAssessor != null) {
      list = list
          .where((a) => a['assessor']?.toString() == _selectedAssessor)
          .toList();
    }
    if (_selectedPaid != null) {
      list = list.where((a) {
        final paid = a['assessment_fee_paid'] == true;
        return _selectedPaid == 'Paid' ? paid : !paid;
      }).toList();
    }
    if (query.isNotEmpty) {
      list = list.where((a) {
        final name = a['name']?.toString().toLowerCase() ?? '';
        final qual = a['qualification']?.toString().toLowerCase() ?? '';
        return name.contains(query) || qual.contains(query);
      }).toList();
    }
    setState(() {
      _assessees = list;
      _selected.clear();
    });
  }

  String get _title => widget.type == 'assessment' ? 'Assessees' : 'Trainees';

  /// The fee charged per assessee, taken from the center they belong to.
  /// Assessment centers use `assessment_fee`, training centers use
  /// `training_fee`.
  double _feeForCenter(int? centerId) {
    if (centerId == null) return 0;
    final centers = _centers ?? [];
    for (final c in centers) {
      if (c['id'] == centerId) {
        final fee = widget.type == 'assessment'
            ? (c['assessment_fee'] as num?)?.toDouble()
            : (c['training_fee'] as num?)?.toDouble();
        return fee ?? 0;
      }
    }
    return 0;
  }

  /// Total expected income for the currently filtered list: the sum of each
  /// assessee's center fee. Matches the user's example — a list of 168 at a
  /// given fee yields 168 × fee. Different centers with different fees are
  /// summed per assessee, so the total stays correct under any filter.
  double get _totalIncome {
    final list = _assessees ?? [];
    double sum = 0;
    for (final a in list) {
      final m = a as Map<String, dynamic>;
      sum += _feeForCenter(m['assessment_center_id'] as int?);
    }
    return sum;
  }

  /// Income that has actually been collected — only assessees whose
  /// assessment fee is marked paid contribute. Shown alongside the expected
  /// total so unpaid records are never reported as collected.
  double get _collectedIncome {
    final list = _assessees ?? [];
    double sum = 0;
    for (final a in list) {
      final m = a as Map<String, dynamic>;
      if (m['assessment_fee_paid'] == true) {
        sum += _feeForCenter(m['assessment_center_id'] as int?);
      }
    }
    return sum;
  }

  String _formatCurrency(double value) {
    final peso = String.fromCharCode(8369); // ₱
    return '$peso${value.toStringAsFixed(2)}';
  }

  /// The only accepted assessment results.
  static const List<String> _competencyOptions = [
    'Pending',
    'Competent',
    'Not Yet Competent',
    'Absent',
  ];

  /// Storage format sent to the API for every date field.
  static final DateFormat _storeFormat = DateFormat('yyyy-MM-dd');

  /// Display format used in every grid, form and printout.
  static final DateFormat _displayFormat = DateFormat('MMMM d, yyyy');

  /// Birthday display/storage format requested by the user (M/d/yy).
  static final DateFormat _birthdayFormat = DateFormat('M/d/yy');

  static DateTime? _parseDate(Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    final iso = DateTime.tryParse(text);
    if (iso != null) return iso;
    // Support the MM/DD/YY birthday format as a fallback.
    try {
      return _birthdayFormat.parseLoose(text);
    } catch (_) {
      return null;
    }
  }

  /// Normalises any incoming date value into the given storage format.
  static String _normalizeDate(Object? value, {DateFormat? format}) {
    final date = _parseDate(value);
    if (date == null) return '';
    return (format ?? _storeFormat).format(date);
  }

  /// Formats any stored date into the given display format.
  static String _formatDate(Object? value, {DateFormat? format}) {
    final date = _parseDate(value);
    if (date == null) return value?.toString() ?? '';
    return (format ?? _displayFormat).format(date);
  }

  /// Read-only field that opens a date picker so every date is entered
  /// and stored in the requested [format].
  Widget _dateField({
    required TextEditingController controller,
    required String label,
    required VoidCallback onChanged,
    DateTime? firstDate,
    DateTime? lastDate,
    DateFormat? format,
  }) {
    final now = DateTime.now();
    final dateFormat = format ?? _birthdayFormat;
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [_NumericDateInputFormatter()],
      decoration: InputDecoration(
        labelText: label,
        hintText: 'M/d/yy',
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (controller.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear, size: 18),
                tooltip: 'Clear date',
                onPressed: () {
                  controller.clear();
                  onChanged();
                },
              ),
            IconButton(
              icon: const Icon(Icons.calendar_today, size: 18),
              tooltip: 'Pick a date',
              onPressed: () async {
                final initial = _parseDate(controller.text) ?? now;
                final picked = await showDatePicker(
                  context: context,
                  initialDate: initial,
                  firstDate: firstDate ?? DateTime(1900),
                  lastDate: lastDate ?? DateTime(now.year + 10),
                );
                if (picked == null) return;
                controller.text = dateFormat.format(picked);
                onChanged();
              },
            ),
          ],
        ),
      ),
      onChanged: (_) => onChanged(),
    );
  }

  /// Builds the headers and rows shared by the print and export functions.
  /// The Paid/Unpaid status is taken verbatim from the system records so an
  /// unpaid assessee is never reported as paid in any exported file.
  (List<String>, List<List<String>>) _buildExportData() {
    if (_assessees == null || _assessees!.isEmpty) {
      return (<String>[], <List<String>>[]);
    }

    final toPrint = _selected.isEmpty
        ? _assessees!
        : _selected.map((i) => _assessees![i]).toList();

    final headers = widget.type == 'assessment'
        ? [
            'Name',
            'Qualification',
            'Competency',
            'Ref No.',
            'ULI',
            'Assessment Fee',
            'Processing Fee',
            'OR',
            'Assessor',
            'Assessment Date',
          ]
        : [
            'Name',
            'Qualification',
            'Ref No.',
            'ULI',
            'Last School',
            'Contact',
            'Email',
            'Reg. Form',
            'Med. Cert.',
            'Brgy. Indigency',
            'Brgy. Clearance',
            'TOR/137/138',
          ];

    final data = toPrint.map((a) {
      final m = a as Map<String, dynamic>;
      if (widget.type == 'assessment') {
        return [
          m['name']?.toString() ?? '',
          m['qualification']?.toString() ?? '',
          m['competency']?.toString() ?? '',
          m['reference_number']?.toString() ?? '',
          m['uli']?.toString() ?? '',
          (m['assessment_fee_paid'] == true) ? 'Paid' : 'Unpaid',
          (m['processing_fee_paid'] == true) ? 'Paid' : 'Unpaid',
          m['official_receipt']?.toString() ?? '',
          m['assessor']?.toString() ?? '',
          _formatDate(m['assessment_date']),
        ];
      }
      return [
        m['name']?.toString() ?? '',
        m['qualification']?.toString() ?? '',
        m['reference_number']?.toString() ?? '',
        m['uli']?.toString() ?? '',
        m['last_school_attended']?.toString() ?? '',
        m['contact_number']?.toString() ?? '',
        m['email']?.toString() ?? '',
        (m['registration_form'] == true) ? 'Yes' : 'No',
        (m['medical_certificate'] == true) ? 'Yes' : 'No',
        (m['brgy_indigency'] == true) ? 'Yes' : 'No',
        (m['brgy_clearance'] == true) ? 'Yes' : 'No',
        (m['tor_form137_138'] == true) ? 'Yes' : 'No',
      ];
    }).toList();

    return (headers, data);
  }

  Future<void> _print() async {
    if (_assessees == null || _assessees!.isEmpty) return;

    final (headers, data) = _buildExportData();
    if (data.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No rows selected to print')),
      );
      return;
    }

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Text(
            '$_title List',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: data,
            border: null,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellHeight: 24,
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerCellDecoration:
                const pw.BoxDecoration(color: PdfColors.grey300),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }

  bool _exporting = false;

  /// Shows a save dialog and writes [bytes] to the chosen path.
  Future<void> _saveFile(
    List<int> bytes, {
    required String dialogTitle,
    required String fileName,
    required String extension,
  }) async {
    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: [extension],
    );
    if (outputPath == null) return;
    await File(outputPath).writeAsBytes(bytes);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved to: $outputPath')),
      );
    }
  }

  /// Exports the current selection to a PDF file. The Paid/Unpaid status is
  /// taken verbatim from the system records.
  Future<void> _exportPdf() async {
    if (_assessees == null || _assessees!.isEmpty) return;
    setState(() => _exporting = true);
    try {
      final (headers, data) = _buildExportData();
      if (data.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No rows to export')),
          );
        }
        return;
      }

      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (context) => [
            pw.Text(
              '$_title List',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 16),
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: data,
              border: null,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              cellHeight: 24,
              cellStyle: const pw.TextStyle(fontSize: 8),
              headerCellDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey300),
            ),
          ],
        ),
      );

      final pdfBytes = await pdf.save();
      final safeName = _exportFileName();
      await _saveFile(pdfBytes,
          dialogTitle: 'Save PDF',
          fileName: '$safeName.pdf',
          extension: 'pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// Exports the current selection to an Excel (.xlsx) file.
  Future<void> _exportExcel() async {
    if (_assessees == null || _assessees!.isEmpty) return;
    setState(() => _exporting = true);
    try {
      final (headers, data) = _buildExportData();
      if (data.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No rows to export')),
          );
        }
        return;
      }

      final excel = Excel.createExcel();
      final sheetName = excel.getDefaultSheet() ?? 'Sheet1';
      final sheet = excel[sheetName];

      // Header row (bold-styled via cell value; excel package styles cells
      // through CellValue objects).
      sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
      for (final row in data) {
        sheet.appendRow(row.map((c) => TextCellValue(c)).toList());
      }

      final bytes = excel.encode();
      if (bytes == null) throw Exception('Failed to encode Excel file');
      final safeName = _exportFileName();
      await _saveFile(bytes,
          dialogTitle: 'Save Excel',
          fileName: '$safeName.xlsx',
          extension: 'xlsx');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// Exports the current selection to a Word-compatible (.doc) file.
  /// The document is an HTML table that Microsoft Word opens natively.
  Future<void> _exportWord() async {
    if (_assessees == null || _assessees!.isEmpty) return;
    setState(() => _exporting = true);
    try {
      final (headers, data) = _buildExportData();
      if (data.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No rows to export')),
          );
        }
        return;
      }

      final buffer = StringBuffer()
        ..writeln('<html xmlns:o="urn:schemas-microsoft-com:office:office" '
            'xmlns:w="urn:schemas-microsoft-com:office:word" '
            'xmlns="http://www.w3.org/TR/REC-html40">')
        ..writeln('<head><meta charset="utf-8"><title>$_title List</title>')
        ..writeln('<style>'
            'body { font-family: Arial, sans-serif; font-size: 10pt; }'
            'h2 { margin-bottom: 8pt; }'
            'table { border-collapse: collapse; width: 100%; }'
            'th, td { border: 1px solid #000; padding: 4pt 6pt; '
            'vertical-align: top; }'
            'th { background-color: #d9d9d9; font-weight: bold; }'
            '</style></head><body>')
        ..writeln('<h2>$_title List</h2>')
        ..writeln('<table><thead><tr>');
      for (final h in headers) {
        buffer.writeln('<th>${_escapeHtml(h)}</th>');
      }
      buffer.writeln('</tr></thead><tbody>');
      for (final row in data) {
        buffer.writeln('<tr>');
        for (final cell in row) {
          buffer.writeln('<td>${_escapeHtml(cell)}</td>');
        }
        buffer.writeln('</tr>');
      }
      buffer.writeln('</tbody></table></body></html>');

      final bytes = utf8.encode(buffer.toString());
      final safeName = _exportFileName();
      await _saveFile(bytes,
          dialogTitle: 'Save Word',
          fileName: '$safeName.doc',
          extension: 'doc');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _exportFileName() {
    final type = widget.type == 'assessment' ? 'assessees' : 'trainees';
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    return '${type}_$stamp';
  }

  String _escapeHtml(String text) {
    // Build entity strings from char codes so the source does not contain
    // raw HTML entities that could be mangled by tooling.
    final amp = String.fromCharCode(38); // &
    final lt = String.fromCharCode(60);  // <
    final gt = String.fromCharCode(62);  // >
    final quot = String.fromCharCode(34); // "
    final ampEnt = '${amp}amp;';
    final ltEnt = '${amp}lt;';
    final gtEnt = '${amp}gt;';
    final quotEnt = '${amp}quot;';
    return text
        .replaceAll(amp, ampEnt)
        .replaceAll(lt, ltEnt)
        .replaceAll(gt, gtEnt)
        .replaceAll(quot, quotEnt);
  }

  Future<void> _printAttendance() async {
    if (_assessees == null || _assessees!.isEmpty) return;

    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select assessees to print attendance')),
      );
      return;
    }

    // Fetch AC Managers
    List<dynamic> acManagers = [];
    try {
      final res = await ApiClient.get('/users/ac-managers');
      acManagers = res.data as List<dynamic>;
    } catch (_) {}

    if (!mounted) return;

    Map<String, dynamic>? selectedAcManager;
    bool includePei = true;
    bool includeRap = true;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Print Attendance Sheet'),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                const Text('AC Manager:',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<Map<String, dynamic>>(
                      hint: const Text('Select AC Manager'),
                      isExpanded: true,
                      value: selectedAcManager,
                      items: acManagers.map((manager) {
                        final name = manager['name']?.toString() ?? '';
                        return DropdownMenuItem<Map<String, dynamic>>(
                          value: manager as Map<String, dynamic>,
                          child:
                              Text(name, style: const TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedAcManager = value;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Selected assessees: ${_selected.length}',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  title: const Text('Print PEI (2 copies)'),
                  value: includePei,
                  onChanged: (v) => setState(() => includePei = v ?? true),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                CheckboxListTile(
                  title: const Text('Print RAP (1 copy)'),
                  value: includeRap,
                  onChanged: (v) => setState(() => includeRap = v ?? true),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (selectedAcManager == null) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Please select an AC Manager')),
                    );
                  }
                  return;
                }
                Navigator.of(context).pop();
                await _printAttendanceWithSelection(
                  selectedAcManager!,
                  includePei: includePei,
                  includeRap: includeRap,
                );
              },
              child: const Text('Print'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _printAttendanceWithSelection(
    Map<String, dynamic> acManager, {
    bool includePei = true,
    bool includeRap = true,
  }) async {
    final selectedMaps =
        _selected.map((i) => _assessees![i] as Map<String, dynamic>).toList();

    if (selectedMaps.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No assessees match the selection')),
        );
      }
      return;
    }

    // Validate all selected assessees have the same assessment_date
    final dates = selectedMaps
        .map((a) => a['assessment_date']?.toString() ?? '')
        .toSet();
    if (dates.length > 1) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Cannot print: selected assessees have different assessment dates')),
        );
      }
      return;
    }

    // Validate all selected assessees have the same assessor
    final assessors = selectedMaps
        .map((a) => a['assessor']?.toString() ?? '')
        .toSet();
    if (assessors.length > 1) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Cannot print: selected assessees have different assessors')),
        );
      }
      return;
    }

    // Validate all selected assessees have the same qualification
    final qualifications = selectedMaps
        .map((a) => a['qualification']?.toString() ?? '')
        .toSet();
    if (qualifications.length > 1) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Cannot print: selected assessees have different qualifications')),
        );
      }
      return;
    }

    // Get date from assessee data and format for display
    final rawDate = selectedMaps.first['assessment_date']?.toString() ?? '';
    String date = rawDate;
    final parsed = _parseDate(rawDate);
    if (parsed != null) {
      date = _displayFormat.format(parsed);
    }

    // Get assessor name from assessee data
    final assessorName = selectedMaps.first['assessor']?.toString() ?? '';

    final qualification = selectedMaps.first['qualification']?.toString() ?? '';

    // Determine the center from the first assessee
    final centerId = selectedMaps.first['assessment_center_id'];
    Map<String, dynamic> center = {};
    for (final c in _centers ?? []) {
      if (c['id'] == centerId) {
        center = c as Map<String, dynamic>;
        break;
      }
    }

    // Get accreditation number from the assessor (matched by name)
    String assessorAccred = '';
    if (assessorName.isNotEmpty) {
      final matchingAssessor = _assessorsForQualification(qualification).where(
        (a) => (a['name']?.toString() ?? '') == assessorName,
      );
      if (matchingAssessor.isNotEmpty) {
        assessorAccred =
            matchingAssessor.first['accreditation_number']?.toString() ?? '';
      }
    }

    // Extract AC Manager details
    final acManagerName = acManager['name']?.toString() ?? '';

    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AttendancePrintScreen(
          center: center,
          selectedAssessees: selectedMaps,
          assessorName: assessorName,
          assessorAccreditationNumber: assessorAccred,
          dateOfAssessment: date,
          qualification: qualification,
          acManagerName: acManagerName,
          includePei: includePei,
          includeRap: includeRap,
        ),
      ),
    );
  }

  Future<void> _deleteAssessee(Map<String, dynamic> a) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete'),
        content: Text('Delete ${a['name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child:
                const Text('Delete', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiClient.delete('/assessees/${a['id']}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Deleted')),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  Future<void> _showBulkUpdateDialog() async {
    final assessorController = TextEditingController();
    final dateController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Bulk Update Selected'),
          content: Form(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String?>(
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Assessor'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('— No change —'),
                      ),
                      ...(_assessors ?? [])
                          .whereType<Map>()
                          .map<DropdownMenuItem<String?>>((a) {
                        final name = a['name']?.toString() ?? '';
                        final accred =
                            a['accreditation_number']?.toString() ?? '';
                        final label =
                            accred.isEmpty ? name : '$name ($accred)';
                        return DropdownMenuItem<String?>(
                          value: a['id']?.toString(),
                          child:
                              Text(label, overflow: TextOverflow.ellipsis),
                        );
                      }),
                    ],
                    onChanged: (v) => setDialogState(() {
                      if (v == null) {
                        assessorController.clear();
                        return;
                      }
                      final picked = (_assessors ?? []).where(
                        (a) => a['id']?.toString() == v,
                      );
                      assessorController.text = picked.isEmpty
                          ? ''
                          : picked.first['name']?.toString() ?? '';
                    }),
                  ),
                  const SizedBox(height: 12),
                  _dateField(
                    controller: dateController,
                    label: 'Assessment Date',
                    onChanged: () => setDialogState(() {}),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final ids = _selected
                    .map((i) => _assessees![i]['id'] as int)
                    .toList();
                final payload = <String, dynamic>{'ids': ids};
                if (assessorController.text.trim().isNotEmpty) {
                  payload['assessor'] = assessorController.text.trim();
                }
                if (dateController.text.trim().isNotEmpty) {
                  payload['assessment_date'] = dateController.text.trim();
                }
                Navigator.of(context).pop();
                _bulkUpdate(payload);
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _bulkUpdate(Map<String, dynamic> payload) async {
    try {
      await ApiClient.post('/assessees/bulk-update', data: payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected rows updated')),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  Future<void> _saveAssessee(int? id, Map<String, dynamic> payload) async {
    try {
      if (id == null) {
        await ApiClient.post('/assessees', data: payload);
      } else {
        await ApiClient.put('/assessees/$id', data: payload);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved')),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  Future<void> _showForm({Map<String, dynamic>? assessee}) async {
    final formKey = GlobalKey<FormState>();
    final lastName = TextEditingController(
      text: assessee?['last_name']?.toString() ?? '',
    );
    final firstName = TextEditingController(
      text: assessee?['first_name']?.toString() ?? '',
    );
    final middleName = TextEditingController(
      text: assessee?['middle_name']?.toString() ?? '',
    );
    final extensionName = TextEditingController(
      text: assessee?['extension_name']?.toString() ?? '',
    );
    final birthday = TextEditingController(
      text: _normalizeDate(assessee?['birthday'], format: _birthdayFormat),
    );
    final age = TextEditingController(
      text: assessee?['age']?.toString() ?? '',
    );
    final qualification = TextEditingController(
      text: assessee?['qualification']?.toString() ?? '',
    );
    final uli = TextEditingController(
      text: assessee?['uli']?.toString() ?? '',
    );
    final referenceNumber = TextEditingController(
      text: assessee?['reference_number']?.toString() ?? '',
    );
    final contactNumber = TextEditingController(
      text: assessee?['contact_number']?.toString() ?? '',
    );
    final email = TextEditingController(
      text: assessee?['email']?.toString() ?? '',
    );
    final lastSchool = TextEditingController(
      text: assessee?['last_school_attended']?.toString() ?? '',
    );
    final competency = TextEditingController(
      text: assessee?['competency']?.toString() ?? '',
    );
    final officialReceipt = TextEditingController(
      text: assessee?['official_receipt']?.toString() ?? '',
    );
    final receiptDate = TextEditingController(
      text: _normalizeDate(assessee?['receipt_date'], format: _birthdayFormat),
    );
    final assessor = TextEditingController(
      text: assessee?['assessor']?.toString() ?? '',
    );
    final assessmentDate = TextEditingController(
      text: _normalizeDate(assessee?['assessment_date'], format: _birthdayFormat),
    );

    int? selectedCenterId = assessee?['assessment_center_id'] as int?;
    bool assessmentFeePaid = assessee?['assessment_fee_paid'] == true;
    bool processingFeePaid = assessee?['processing_fee_paid'] == true;
    bool registrationForm = assessee?['registration_form'] == true;
    bool medicalCertificate = assessee?['medical_certificate'] == true;
    bool brgyIndigency = assessee?['brgy_indigency'] == true;
    bool brgyClearance = assessee?['brgy_clearance'] == true;
    bool tor = assessee?['tor_form137_138'] == true;

    if (selectedCenterId == null && (_centers?.isNotEmpty ?? false)) {
      selectedCenterId = _selectedCenterId ?? _centers!.first['id'] as int?;
    }

    // The qualification is what identifies the center, so it is selected
    // from every qualification available for this type.
    var selectedQualification = qualification.text.trim().isEmpty
        ? _selectedQualification
        : qualification.text.trim();
    final centerQualifications =
        _qualificationsFor(_selectedCenterId ?? selectedCenterId);
    if (selectedQualification == null && centerQualifications.length == 1) {
      selectedQualification = centerQualifications.first;
    }
    if (selectedQualification != null &&
        !_qualificationsFor(null).contains(selectedQualification)) {
      selectedQualification = null;
    }
    if (selectedQualification != null) {
      qualification.text = selectedQualification;
      selectedCenterId =
          _centerIdForQualification(selectedQualification) ?? selectedCenterId;
    }

    String? selectedAssessorId;
    if (assessor.text.trim().isNotEmpty) {
      final matchingAssessors = _assessorsForQualification(selectedQualification);
      final match = matchingAssessors.where(
        (a) => a['name']?.toString() == assessor.text.trim(),
      );
      if (match.isNotEmpty) {
        selectedAssessorId = match.first['id']?.toString();
      }
    }

    final existingCompetency = competency.text.trim();
    String? selectedCompetency = _competencyOptions.contains(existingCompetency)
        ? existingCompetency
        : 'Pending';

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(assessee == null ? 'Add $_title' : 'Edit $_title'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Builder(builder: (context) {
                    final options = _qualificationsFor(null);
                    if (options.isEmpty) {
                      return TextFormField(
                        controller: qualification,
                        decoration: const InputDecoration(
                          labelText: 'Qualification',
                          helperText:
                              'No qualifications listed yet. Add them to the '
                              'center in the Centers screen.',
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Required' : null,
                      );
                    }
                    return DropdownButtonFormField<String?>(
                      initialValue: selectedQualification,
                      isExpanded: true,
                      decoration:
                          const InputDecoration(labelText: 'Qualification'),
                      items: options
                          .map((q) => DropdownMenuItem<String?>(
                                value: q,
                                child: Text(q, overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                      onChanged: (v) => setDialogState(() {
                        selectedQualification = v;
                        qualification.text = v ?? '';
                        // The qualification determines which center record
                        // this person belongs to.
                        selectedCenterId =
                            _centerIdForQualification(v) ?? selectedCenterId;
                        final current = _assessorsForQualification(v).where(
                          (a) => a['id']?.toString() == selectedAssessorId,
                        );
                        if (current.isEmpty) {
                          selectedAssessorId = null;
                          assessor.clear();
                        }
                      }),
                    );
                  }),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: lastName,
                    decoration: const InputDecoration(labelText: 'Last Name'),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: firstName,
                    decoration: const InputDecoration(labelText: 'First Name'),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: middleName,
                    decoration: const InputDecoration(labelText: 'Middle Name'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: extensionName,
                    decoration: const InputDecoration(
                      labelText: 'Extension Name',
                      hintText: 'e.g. Jr., Sr., III',
                    ),
                  ),
                  const SizedBox(height: 8),
                  _dateField(
                    controller: birthday,
                    label: 'Birthday',
                    lastDate: DateTime.now(),
                    format: _birthdayFormat,
                    onChanged: () {
                      final bday = _parseDate(birthday.text);
                      if (bday != null) {
                        final now = DateTime.now();
                        int computedAge = now.year - bday.year;
                        if (now.month < bday.month ||
                            (now.month == bday.month && now.day < bday.day)) {
                          computedAge--;
                        }
                        age.text = computedAge.toString();
                      }
                      setDialogState(() {});
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: age,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Age'),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 8),
                  if (widget.type == 'assessment') ...[
                    TextFormField(
                      controller: uli,
                      decoration: const InputDecoration(labelText: 'ULI'),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: referenceNumber,
                      decoration:
                          const InputDecoration(labelText: 'Reference Number'),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String?>(
                      initialValue: selectedCompetency,
                      isExpanded: true,
                      decoration:
                          const InputDecoration(labelText: 'Competency'),
                      items: _competencyOptions
                          .map((c) => DropdownMenuItem<String?>(
                                value: c,
                                child: Text(c),
                              ))
                          .toList(),
                      onChanged: (v) => setDialogState(() {
                        selectedCompetency = v;
                        competency.text = v ?? '';
                      }),
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      title: const Text('Assessment Fee Paid'),
                      value: assessmentFeePaid,
                      onChanged: (v) =>
                          setDialogState(() => assessmentFeePaid = v ?? false),
                    ),
                    CheckboxListTile(
                      title: const Text('Processing Fee Paid'),
                      value: processingFeePaid,
                      onChanged: (v) =>
                          setDialogState(() => processingFeePaid = v ?? false),
                    ),
                    TextFormField(
                      controller: officialReceipt,
                      decoration:
                          const InputDecoration(labelText: 'Official Receipt'),
                    ),
                    const SizedBox(height: 8),
                    _dateField(
                      controller: receiptDate,
                      label: 'Receipt Date',
                      onChanged: () => setDialogState(() {}),
                    ),
                    const SizedBox(height: 8),
                    Builder(builder: (context) {
                      final assessorOptions =
                          _assessorsForQualification(selectedQualification);
                      if (assessorOptions.isEmpty) {
                        return TextFormField(
                          controller: assessor,
                          decoration: const InputDecoration(
                            labelText: 'Assessor',
                            helperText:
                                'No matching assessor for this qualification. Add one in Assessors screen.',
                          ),
                        );
                      }

                      return DropdownButtonFormField<String?>(
                        initialValue: selectedAssessorId,
                        isExpanded: true,
                        decoration:
                            const InputDecoration(labelText: 'Assessor'),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('— Select assessor —'),
                          ),
                          ...assessorOptions.map((a) {
                            final name = a['name']?.toString() ?? '';
                            final accred =
                                a['accreditation_number']?.toString() ?? '';
                            final label = accred.isEmpty
                                ? name
                                : '$name ($accred)';
                            return DropdownMenuItem<String?>(
                              value: a['id']?.toString(),
                              child:
                                  Text(label, overflow: TextOverflow.ellipsis),
                            );
                          }),
                        ],
                        onChanged: (v) => setDialogState(() {
                          selectedAssessorId = v;
                          final picked = assessorOptions.where(
                            (a) => a['id']?.toString() == v,
                          );
                          assessor.text =
                              picked.isEmpty ? '' : picked.first['name']?.toString() ?? '';
                        }),
                      );
                    }),
                    const SizedBox(height: 8),
                    _dateField(
                      controller: assessmentDate,
                      label: 'Date of Assessment',
                      onChanged: () => setDialogState(() {}),
                    ),
                  ] else ...[
                    TextFormField(
                      controller: uli,
                      decoration: const InputDecoration(labelText: 'ULI'),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: referenceNumber,
                      decoration:
                          const InputDecoration(labelText: 'Reference Number'),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: contactNumber,
                      decoration:
                          const InputDecoration(labelText: 'Contact Number'),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: lastSchool,
                      decoration: const InputDecoration(
                          labelText: 'Last School Attended'),
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      title: const Text('Registration Form'),
                      value: registrationForm,
                      onChanged: (v) =>
                          setDialogState(() => registrationForm = v ?? false),
                    ),
                    CheckboxListTile(
                      title: const Text('Medical Certificate'),
                      value: medicalCertificate,
                      onChanged: (v) =>
                          setDialogState(() => medicalCertificate = v ?? false),
                    ),
                    CheckboxListTile(
                      title: const Text('Brgy. Indigency'),
                      value: brgyIndigency,
                      onChanged: (v) =>
                          setDialogState(() => brgyIndigency = v ?? false),
                    ),
                    CheckboxListTile(
                      title: const Text('Brgy. Clearance'),
                      value: brgyClearance,
                      onChanged: (v) =>
                          setDialogState(() => brgyClearance = v ?? false),
                    ),
                    CheckboxListTile(
                      title: const Text('TOR / Form 137 / 138'),
                      value: tor,
                      onChanged: (v) => setDialogState(() => tor = v ?? false),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                final payload = <String, dynamic>{
                  'assessment_center_id': selectedCenterId,
                  'last_name': lastName.text.trim(),
                  'first_name': firstName.text.trim(),
                  'middle_name': middleName.text.trim(),
                  'extension_name': extensionName.text.trim(),
                  'birthday': birthday.text.trim(),
                  'age': int.tryParse(age.text) ?? 0,
                  'qualification': qualification.text.trim(),
                };
                if (widget.type == 'assessment') {
                  payload.addAll({
                    'uli': uli.text.trim(),
                    'reference_number': referenceNumber.text.trim(),
                    'competency': competency.text.trim(),
                    'assessment_fee_paid': assessmentFeePaid,
                    'processing_fee_paid': processingFeePaid,
                    'official_receipt': officialReceipt.text.trim(),
                    'receipt_date': receiptDate.text.trim(),
                    'assessor': assessor.text.trim(),
                    'assessment_date': assessmentDate.text.trim(),
                    'contact_number': null,
                    'email': null,
                    'last_school_attended': null,
                    'registration_form': false,
                    'medical_certificate': false,
                    'brgy_indigency': false,
                    'brgy_clearance': false,
                    'tor_form137_138': false,
                  });
                } else {
                  payload.addAll({
                    'uli': uli.text.trim(),
                    'reference_number': referenceNumber.text.trim(),
                    'contact_number': contactNumber.text.trim(),
                    'email': email.text.trim(),
                    'last_school_attended': lastSchool.text.trim(),
                    'registration_form': registrationForm,
                    'medical_certificate': medicalCertificate,
                    'brgy_indigency': brgyIndigency,
                    'brgy_clearance': brgyClearance,
                    'tor_form137_138': tor,
                    'competency': null,
                    'assessment_fee_paid': false,
                    'processing_fee_paid': false,
                    'official_receipt': null,
                    'receipt_date': null,
                    'assessor': null,
                    'assessment_date': null,
                  });
                }
                Navigator.of(context).pop();
                _saveAssessee(assessee?['id'] as int?, payload);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQualificationsPanel() {
    final centers = _centers ?? [];
    if (centers.isEmpty) {
      return Card(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: ListTile(
          leading: const Icon(Icons.info_outline),
          title: Text('No ${widget.type} center yet'),
          subtitle: const Text(
            'Add a center and its TESDA qualifications in the Centers screen '
            'first.',
          ),
        ),
      );
    }

    final selected = _selectedCenterId == null
        ? null
        : centers.firstWhere(
            (c) => c['id'] == _selectedCenterId,
            orElse: () => null,
          );

    final quals = selected == null
        ? centers
            .expand((c) => (c['qualifications'] as List<dynamic>? ?? []))
            .map((q) => q.toString())
            .toSet()
            .toList()
        : (selected['qualifications'] as List<dynamic>? ?? [])
            .map((q) => q.toString())
            .toList();

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              selected == null
                  ? 'Qualifications (all ${widget.type} centers)'
                  : 'Qualifications of ${selected['name']}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (quals.isEmpty)
              const Text('No qualifications recorded for this center.')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: quals
                    .map((q) => Chip(
                          label: Text(q),
                          side: BorderSide(
                            color: AppTheme.csuMaroon.withValues(alpha: 0.35),
                          ),
                        ))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const LoadingState();
    }
    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _load);
    }
    final columns = widget.type == 'assessment'
        ? const [
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Birthday')),
            DataColumn(label: Text('Qualification')),
            DataColumn(label: Text('Competency')),
            DataColumn(label: Text('Ref No.')),
            DataColumn(label: Text('ULI')),
            DataColumn(label: Text('A. Fee')),
            DataColumn(label: Text('P. Fee')),
            DataColumn(label: Text('OR')),
            DataColumn(label: Text('Receipt Date')),
            DataColumn(label: Text('Assessor')),
            DataColumn(label: Text('Date of Assessment')),
            DataColumn(label: Text('Actions')),
          ]
        : const [
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Birthday')),
            DataColumn(label: Text('Qualification')),
            DataColumn(label: Text('Ref No.')),
            DataColumn(label: Text('ULI')),
            DataColumn(label: Text('Last School')),
            DataColumn(label: Text('Contact')),
            DataColumn(label: Text('Email')),
            DataColumn(label: Text('Reg')),
            DataColumn(label: Text('Med')),
            DataColumn(label: Text('Indi')),
            DataColumn(label: Text('Clear')),
            DataColumn(label: Text('TOR')),
            DataColumn(label: Text('Actions')),
          ];

    final list = _assessees ?? [];
    final rows = list.asMap().entries.map<DataRow>((entry) {
      final index = entry.key;
      final m = entry.value as Map<String, dynamic>;
      final selected = _selected.contains(index);
      if (widget.type == 'assessment') {
        return DataRow(
          selected: selected,
          onSelectChanged: (v) {
            setState(() {
              if (v == true) {
                _selected.add(index);
              } else {
                _selected.remove(index);
              }
            });
          },
          cells: [
            DataCell(SelectableText(m['name']?.toString() ?? '')),
            DataCell(SelectableText(_formatDate(m['birthday']))),
            DataCell(Text(m['qualification']?.toString() ?? '')),
            DataCell(Text(m['competency']?.toString() ?? '')),
            DataCell(Text(m['reference_number']?.toString() ?? '')),
            DataCell(SelectableText(m['uli']?.toString() ?? '')),
            DataCell((m['assessment_fee_paid'] == true)
                ? StatusBadge.success('Paid')
                : StatusBadge.warning('Unpaid')),
            DataCell((m['processing_fee_paid'] == true)
                ? StatusBadge.success('Paid')
                : StatusBadge.warning('Unpaid')),
            DataCell(Text(m['official_receipt']?.toString() ?? '')),
            DataCell(Text(_formatDate(m['receipt_date']))),
            DataCell(Text(m['assessor']?.toString() ?? '')),
            DataCell(Text(_formatDate(m['assessment_date']))),
            DataCell(Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () => _showForm(assessee: m),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 20, color: AppTheme.error),
                  onPressed: () => _deleteAssessee(m),
                ),
              ],
            )),
          ],
        );
      }
      return DataRow(
        selected: selected,
        onSelectChanged: (v) {
          setState(() {
            if (v == true) {
              _selected.add(index);
            } else {
              _selected.remove(index);
            }
          });
        },
        cells: [
          DataCell(Text(m['name']?.toString() ?? '')),
          DataCell(Text(m['qualification']?.toString() ?? '')),
          DataCell(Text(m['reference_number']?.toString() ?? '')),
          DataCell(Text(m['uli']?.toString() ?? '')),
          DataCell(Text(m['last_school_attended']?.toString() ?? '')),
          DataCell(Text(m['contact_number']?.toString() ?? '')),
          DataCell(Text(m['email']?.toString() ?? '')),
          DataCell((m['registration_form'] == true)
              ? StatusBadge.success('Yes')
              : StatusBadge.warning('No')),
          DataCell((m['medical_certificate'] == true)
              ? StatusBadge.success('Yes')
              : StatusBadge.warning('No')),
          DataCell((m['brgy_indigency'] == true)
              ? StatusBadge.success('Yes')
              : StatusBadge.warning('No')),
          DataCell((m['brgy_clearance'] == true)
              ? StatusBadge.success('Yes')
              : StatusBadge.warning('No')),
          DataCell((m['tor_form137_138'] == true)
              ? StatusBadge.success('Yes')
              : StatusBadge.warning('No')),
          DataCell(Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: () => _showForm(assessee: m),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 20, color: AppTheme.error),
                onPressed: () => _deleteAssessee(m),
              ),
            ],
          )),
        ],
      );
    }).toList();

    final availableQualifications = _qualificationsFor(null);
    final qualificationItems = <DropdownMenuItem<String?>>[
      const DropdownMenuItem(value: null, child: Text('All qualifications')),
      ...availableQualifications.map((q) => DropdownMenuItem<String?>(
            value: q,
            child: Text(q, overflow: TextOverflow.ellipsis),
          )),
    ];

    // Build filter options from all assessees data
    final all = _allAssessees ?? [];
    final availableDates = all
        .map((a) => _normalizeDate(a['assessment_date']))
        .where((d) => d.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final dateItems = <DropdownMenuItem<String?>>[
      const DropdownMenuItem(value: null, child: Text('All dates')),
      ...availableDates.map((d) {
        final parsed = _parseDate(d);
        final label = parsed != null ? _displayFormat.format(parsed) : d;
        return DropdownMenuItem<String?>(
          value: d,
          child: Text(label, overflow: TextOverflow.ellipsis),
        );
      }),
    ];

    final availableAssessors = all
        .map((a) => a['assessor']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final assessorItems = <DropdownMenuItem<String?>>[
      const DropdownMenuItem(value: null, child: Text('All assessors')),
      ...availableAssessors.map((a) => DropdownMenuItem<String?>(
            value: a,
            child: Text(a, overflow: TextOverflow.ellipsis),
          )),
    ];

    final competencyItems = <DropdownMenuItem<String?>>[
      const DropdownMenuItem(value: null, child: Text('All competency')),
      ..._competencyOptions.map((c) => DropdownMenuItem<String?>(
            value: c,
            child: Text(c),
          )),
    ];

    final paidItems = <DropdownMenuItem<String?>>[
      const DropdownMenuItem(value: null, child: Text('All payment')),
      const DropdownMenuItem(value: 'Paid', child: Text('Paid')),
      const DropdownMenuItem(value: 'Unpaid', child: Text('Unpaid')),
    ];

    final totalCount = all.length;
    final filteredCount = list.length;
    final hasActiveFilters = _selectedQualification != null ||
        _selectedDate != null ||
        _selectedCompetency != null ||
        _selectedAssessor != null ||
        _selectedPaid != null ||
        _search.text.trim().isNotEmpty;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppTheme.spaceLg),
          child: Wrap(
            spacing: AppTheme.spaceSm,
            runSpacing: AppTheme.spaceSm,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    labelText: 'Search',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                  onChanged: (_) => _applyFilters(),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: DropdownButtonFormField<String?>(
                  initialValue: _selectedQualification,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: qualificationItems,
                  onChanged: (v) {
                    setState(() {
                      _selectedQualification = v;
                      _selectedCenterId = _centerIdForQualification(v);
                    });
                    _applyFilters();
                  },
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: DropdownButtonFormField<String?>(
                  initialValue: _selectedDate,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  items: dateItems,
                  onChanged: (v) {
                    setState(() => _selectedDate = v);
                    _applyFilters();
                  },
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: DropdownButtonFormField<String?>(
                  initialValue: _selectedCompetency,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  items: competencyItems,
                  onChanged: (v) {
                    setState(() => _selectedCompetency = v);
                    _applyFilters();
                  },
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: DropdownButtonFormField<String?>(
                  initialValue: _selectedAssessor,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  items: assessorItems,
                  onChanged: (v) {
                    setState(() => _selectedAssessor = v);
                    _applyFilters();
                  },
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: DropdownButtonFormField<String?>(
                  initialValue: _selectedPaid,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  items: paidItems,
                  onChanged: (v) {
                    setState(() => _selectedPaid = v);
                    _applyFilters();
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Reload centers and records',
                onPressed: _load,
              ),
              OutlinedButton.icon(
                onPressed: _print,
                icon: const Icon(Icons.print, size: 18),
                label: Text(_selected.isEmpty
                    ? 'Print All'
                    : 'Print (${_selected.length})'),
              ),
              if (_exporting)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                PopupMenuButton<String>(
                  tooltip: 'Export to file',
                  onSelected: (value) {
                    switch (value) {
                      case 'pdf':
                        _exportPdf();
                        break;
                      case 'excel':
                        _exportExcel();
                        break;
                      case 'word':
                        _exportWord();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'excel',
                      child: ListTile(
                        leading: Icon(Icons.table_view, size: 20),
                        title: Text('Excel (.xlsx)'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'word',
                      child: ListTile(
                        leading: Icon(Icons.description, size: 20),
                        title: Text('Word (.doc)'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'pdf',
                      child: ListTile(
                        leading: Icon(Icons.picture_as_pdf, size: 20),
                        title: Text('PDF (.pdf)'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(20),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.download, size: 18),
                        const SizedBox(width: 8),
                        Text(_selected.isEmpty
                            ? 'Export'
                            : 'Export (${_selected.length})'),
                      ],
                    ),
                  ),
                ),
              if (widget.type == 'assessment')
                OutlinedButton.icon(
                  onPressed: _printAttendance,
                  icon: const Icon(Icons.fact_check_outlined, size: 18),
                  label: Text(_selected.isEmpty
                      ? 'Attendance'
                      : 'Attendance (${_selected.length})'),
                ),
              if (widget.type == 'assessment' && _selected.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: _showBulkUpdateDialog,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Bulk Update'),
                ),
              FilledButton.icon(
                onPressed: () => _showForm(),
                icon: const Icon(Icons.person_add, size: 18),
                label: Text('Add $_title'),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: AppTheme.spaceXxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildQualificationsPanel(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppTheme.spaceLg,
                      AppTheme.spaceSm, AppTheme.spaceLg, AppTheme.spaceSm),
                  child: Row(
                    children: [
                      Text(
                        '$_title ($filteredCount)',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (hasActiveFilters) ...[
                        const SizedBox(width: 8),
                        Text(
                          'of $totalCount',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          icon: const Icon(Icons.filter_alt_off, size: 16),
                          label: const Text('Clear filters'),
                          onPressed: () {
                            setState(() {
                              _selectedQualification = null;
                              _selectedCenterId = null;
                              _selectedDate = null;
                              _selectedCompetency = null;
                              _selectedAssessor = null;
                              _selectedPaid = null;
                              _search.clear();
                            });
                            _applyFilters();
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                // Total income for the current filter — count × center fee.
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppTheme.spaceLg,
                      0, AppTheme.spaceLg, AppTheme.spaceSm),
                  child: Card(
                    color: AppTheme.csuMaroon.withValues(alpha: 0.06),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      side: BorderSide(
                        color: AppTheme.csuMaroon.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.payments, color: AppTheme.csuMaroon),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.type == 'assessment'
                                      ? 'Total Assessment Income (this filter)'
                                      : 'Total Training Income (this filter)',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$filteredCount ${widget.type == 'assessment' ? 'assessees' : 'trainees'} × center fee',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _formatCurrency(_totalIncome),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.csuMaroon,
                                ),
                              ),
                              if (widget.type == 'assessment')
                                Text(
                                  'Collected: ${_formatCurrency(_collectedIncome)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (list.isEmpty)
                  EmptyState(
                    icon: widget.type == 'assessment'
                        ? Icons.assignment_ind
                        : Icons.school,
                    title: 'No $_title yet',
                    subtitle:
                        'Add ${widget.type == 'assessment' ? 'assessees' : 'trainees'} to get started',
                  )
                else
                  Scrollbar(
                    controller: _tableScrollController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _tableScrollController,
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        showCheckboxColumn: true,
                      headingRowColor: WidgetStateColor.resolveWith(
                          (_) => AppTheme.csuMaroon.withValues(alpha: 0.06)),
                      onSelectAll: (selected) {
                        setState(() {
                          _selected = selected == true
                              ? Set<int>.from(
                                  List.generate(list.length, (i) => i))
                              : <int>{};
                        });
                      },
                      columns: columns,
                      rows: rows,
                    ),
                  ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
