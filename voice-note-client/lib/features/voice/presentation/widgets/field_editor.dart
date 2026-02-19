import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/design_tokens.dart';
import '../../../../core/di/database_provider.dart';

/// Callback with edited field name and new value.
typedef FieldEditCallback = void Function(String field, dynamic value);

/// Shows a bottom sheet editor for the given [field].
///
/// Supported fields: amount, category, date, account, description.
Future<void> showFieldEditor({
  required BuildContext context,
  required WidgetRef ref,
  required String field,
  required dynamic currentValue,
  required FieldEditCallback onSave,
  String transactionType = 'EXPENSE',
}) async {
  HapticFeedback.selectionClick();
  switch (field) {
    case 'amount':
      await _showAmountEditor(context, currentValue as double?, onSave);
    case 'category':
      await _showCategoryPicker(
        context,
        ref,
        currentValue as String?,
        transactionType,
        onSave,
      );
    case 'date':
      await _showDatePicker(context, currentValue as String?, onSave);
    case 'account':
      await _showAccountPicker(context, ref, currentValue as String?, onSave);
    case 'description':
      await _showDescriptionEditor(context, currentValue as String?, onSave);
  }
}

// ─── Amount Editor ───

Future<void> _showAmountEditor(
  BuildContext context,
  double? current,
  FieldEditCallback onSave,
) async {
  final result = await showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (ctx) => _AmountEditorSheet(current: current),
  );
  if (result != null) onSave('amount', result);
}

/// StatefulWidget so the TextEditingController is disposed only when
/// the widget is unmounted (after the exit animation), not when the
/// showModalBottomSheet future completes.
class _AmountEditorSheet extends StatefulWidget {
  final double? current;
  const _AmountEditorSheet({this.current});

  @override
  State<_AmountEditorSheet> createState() => _AmountEditorSheetState();
}

class _AmountEditorSheetState extends State<_AmountEditorSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.current?.toStringAsFixed(2) ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final parsed = double.tryParse(_controller.text);
    if (parsed != null && parsed > 0) {
      FocusScope.of(context).unfocus();
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) Navigator.pop(context, parsed);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('金额', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            ],
            decoration: const InputDecoration(
              prefixText: '¥ ',
              border: OutlineInputBorder(),
              hintText: '0.00',
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submit,
              child: const Text('确定'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Category Picker ───

Future<void> _showCategoryPicker(
  BuildContext context,
  WidgetRef ref,
  String? current,
  String transactionType,
  FieldEditCallback onSave,
) async {
  final type = transactionType == 'INCOME' ? 'income' : 'expense';
  final categories = await ref.read(categoryDaoProvider).getVisible(type);

  if (!context.mounted) return;

  final result = await showModalBottomSheet<String>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (ctx) => _ListPickerSheet(
      title: '选择分类',
      items: categories.map((c) => _PickerItem(id: c.name, label: c.name)).toList(),
      selectedId: current,
    ),
  );
  if (result != null) onSave('category', result);
}

// ─── Date Picker ───

Future<void> _showDatePicker(
  BuildContext context,
  String? current,
  FieldEditCallback onSave,
) async {
  DateTime initial;
  try {
    initial = current != null ? DateTime.parse(current) : DateTime.now();
  } catch (_) {
    initial = DateTime.now();
  }

  final picked = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2020),
    lastDate: DateTime.now(),
  );
  if (picked != null) {
    onSave('date', DateFormat('yyyy-MM-dd').format(picked));
  }
}

// ─── Account Picker ───

Future<void> _showAccountPicker(
  BuildContext context,
  WidgetRef ref,
  String? current,
  FieldEditCallback onSave,
) async {
  final accounts = await ref.read(accountDaoProvider).getActive();
  if (!context.mounted) return;

  final result = await showModalBottomSheet<String>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (ctx) => _ListPickerSheet(
      title: '选择账户',
      items: accounts.map((a) => _PickerItem(id: a.name, label: a.name)).toList(),
      selectedId: current,
    ),
  );
  if (result != null) onSave('account', result);
}

// ─── Description Editor ───

Future<void> _showDescriptionEditor(
  BuildContext context,
  String? current,
  FieldEditCallback onSave,
) async {
  final result = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (ctx) => _DescriptionEditorSheet(current: current),
  );
  if (result != null) onSave('description', result);
}

class _DescriptionEditorSheet extends StatefulWidget {
  final String? current;
  const _DescriptionEditorSheet({this.current});

  @override
  State<_DescriptionEditorSheet> createState() =>
      _DescriptionEditorSheetState();
}

class _DescriptionEditorSheetState extends State<_DescriptionEditorSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.current ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    FocusScope.of(context).unfocus();
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) Navigator.pop(context, text);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('备注', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '添加备注信息',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submit,
              child: const Text('确定'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Reusable list picker bottom sheet ───

class _PickerItem {
  final String id;
  final String label;
  const _PickerItem({required this.id, required this.label});
}

class _ListPickerSheet extends StatelessWidget {
  final String title;
  final List<_PickerItem> items;
  final String? selectedId;

  const _ListPickerSheet({
    required this.title,
    required this.items,
    this.selectedId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
                iconSize: AppIconSize.md,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.4,
          ),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: items.length,
            itemBuilder: (ctx, i) {
              final item = items[i];
              final isSelected = item.id == selectedId;
              return ListTile(
                title: Text(item.label),
                trailing: isSelected
                    ? Icon(
                        Icons.check_rounded,
                        color: theme.colorScheme.primary,
                      )
                    : null,
                selected: isSelected,
                onTap: () => Navigator.pop(ctx, item.id),
              );
            },
          ),
        ),
      ],
    );
  }
}
