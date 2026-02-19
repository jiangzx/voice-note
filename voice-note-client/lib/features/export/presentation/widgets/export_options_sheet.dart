import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/design_tokens.dart';
import '../../domain/export_config.dart';
import '../providers/export_providers.dart';
import 'export_progress_dialog.dart';

/// Bottom sheet for configuring and triggering data export.
class ExportOptionsSheet extends ConsumerStatefulWidget {
  const ExportOptionsSheet({
    super.key,
    this.initialDateFrom,
    this.initialDateTo,
    this.initialType,
  });

  final DateTime? initialDateFrom;
  final DateTime? initialDateTo;
  final String? initialType;

  @override
  ConsumerState<ExportOptionsSheet> createState() => _ExportOptionsSheetState();
}

class _ExportOptionsSheetState extends ConsumerState<ExportOptionsSheet> {
  ExportFormat _format = ExportFormat.csv;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  String? _type;

  @override
  void initState() {
    super.initState();
    _dateFrom = widget.initialDateFrom;
    _dateTo = widget.initialDateTo;
    _type = widget.initialType;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('数据导出', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.lg),

          // Format selector
          Text('导出格式', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<ExportFormat>(
            segments: ExportFormat.values
                .map((f) => ButtonSegment(value: f, label: Text(f.label)))
                .toList(),
            selected: {_format},
            onSelectionChanged: (s) => setState(() => _format = s.first),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Date range
          Text('时间范围', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _DateChip(
                  label: _dateFrom != null
                      ? DateFormat('yyyy-MM-dd').format(_dateFrom!)
                      : '开始日期',
                  onTap: () => _pickDate(isFrom: true),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Text('至'),
              ),
              Expanded(
                child: _DateChip(
                  label: _dateTo != null
                      ? DateFormat('yyyy-MM-dd').format(_dateTo!)
                      : '结束日期',
                  onTap: () => _pickDate(isFrom: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Type filter
          Text('交易类型', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<String?>(
            segments: const [
              ButtonSegment(value: null, label: Text('全部')),
              ButtonSegment(value: 'expense', label: Text('支出')),
              ButtonSegment(value: 'income', label: Text('收入')),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Export button
          FilledButton.icon(
            onPressed: _startExport,
            icon: const Icon(Icons.file_download),
            label: const Text('开始导出'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _dateFrom : _dateTo) ?? now,
      firstDate: DateTime(2020),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _dateFrom = picked;
        } else {
          _dateTo = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
        }
      });
    }
  }

  void _startExport() {
    final config = ExportConfig(
      format: _format,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
      transactionType: _type,
    );

    Navigator.of(context).pop();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ExportProgressDialog(
        config: config,
        exportService: ref.read(exportServiceProvider),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
    );
  }
}
