import 'package:flutter/material.dart';

class TableEditor extends StatefulWidget {
  final ValueChanged<List<Map<String, String>>?> onChanged;
  final List<Map<String, String>>? initialTable;

  const TableEditor({
    super.key,
    required this.onChanged,
    this.initialTable,
  });

  @override
  State<TableEditor> createState() => _TableEditorState();
}

class _TableEditorState extends State<TableEditor> {
  late bool _enabled;
  late List<String> _headers;
  late List<List<String>> _rows;

  static const _defaultHeaders = ['Column 1', 'Column 2', 'Column 3'];
  static const double _colWidth = 120;
  static const double _headerColWidth = 110;
  static const double _actionColWidth = 40;

  @override
  void initState() {
    super.initState();
    _enabled = widget.initialTable != null && widget.initialTable!.isNotEmpty;
    _headers = List.from(_defaultHeaders);
    _rows = [List.filled(_defaultHeaders.length, '')];
    if (_enabled) {
      _headers = (widget.initialTable!.first.keys).toList();
      _rows = widget.initialTable!
          .map((m) => _headers.map((h) => m[h] ?? '').toList())
          .toList();
    }
  }

  void _notify() {
    if (!_enabled) {
      widget.onChanged(null);
      return;
    }
    final out = <Map<String, String>>[];
    for (final cells in _rows) {
      final row = <String, String>{};
      for (var i = 0; i < _headers.length; i++) {
        row[_headers[i]] = i < cells.length ? cells[i] : '';
      }
      out.add(row);
    }
    widget.onChanged(out);
  }

  void _addRow() {
    setState(() {
      _rows.add(List.filled(_headers.length, ''));
    });
    _notify();
  }

  void _removeRow(int index) {
    setState(() {
      _rows.removeAt(index);
      if (_rows.isEmpty) _rows.add(List.filled(_headers.length, ''));
    });
    _notify();
  }

  void _addColumn() {
    setState(() {
      _headers.add('Column ${_headers.length + 1}');
      for (var i = 0; i < _rows.length; i++) {
        _rows[i].add('');
      }
    });
    _notify();
  }

  void _removeColumn(int index) {
    if (_headers.length <= 1) return;
    setState(() {
      _headers.removeAt(index);
      for (var i = 0; i < _rows.length; i++) {
        if (index < _rows[i].length) _rows[i].removeAt(index);
      }
    });
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Include table', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Switch(
              value: _enabled,
              onChanged: (v) {
                setState(() => _enabled = v);
                _notify();
              },
            ),
          ],
        ),
        if (_enabled) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: _addColumn,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add column'),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: _addRow,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add row'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    for (var i = 0; i < _headers.length; i++)
                      SizedBox(
                        width: _headerColWidth,
                        key: ValueKey('header_$i'),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Expanded(
                              child: TextFormField(
                                key: ValueKey('h_$i'),
                                initialValue: _headers[i],
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(vertical: 4),
                                  hintText: 'Column',
                                ),
                                onChanged: (v) {
                                  _headers[i] = v;
                                  _notify();
                                },
                              ),
                            ),
                            InkWell(
                              onTap: () => _removeColumn(i),
                              child: const Padding(
                                padding: EdgeInsets.only(left: 2),
                                child: Icon(Icons.close, size: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(width: _actionColWidth),
                  ],
                ),
                const Divider(height: 1),
                // Data rows
                for (var r = 0; r < _rows.length; r++) ...[
                  Row(
                    key: ValueKey('row_$r'),
                    children: [
                      for (var c = 0; c < _headers.length; c++)
                        SizedBox(
                          width: _colWidth,
                          key: ValueKey('cell_${r}_$c'),
                          child: TextFormField(
                            key: ValueKey('tf_${r}_$c'),
                            initialValue: c < _rows[r].length ? _rows[r][c] : '',
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 4),
                            ),
                            onChanged: (v) {
                              if (c < _rows[r].length) {
                                _rows[r][c] = v;
                              }
                              _notify();
                            },
                          ),
                        ),
                      SizedBox(
                        width: _actionColWidth,
                        child: IconButton(
                          icon: const Icon(Icons.delete, size: 16),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _removeRow(r),
                        ),
                      ),
                    ],
                  ),
                  if (r < _rows.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
