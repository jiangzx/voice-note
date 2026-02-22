import 'package:flutter/material.dart';

import '../../../../app/design_tokens.dart';
import '../../../../core/extensions/date_extensions.dart';

/// Date range presets for filtering.
enum DateRangePreset { today, thisWeek, thisMonth, thisYear, custom }

/// Filter bar with date range chips, type filter, and search.
class FilterBar extends StatefulWidget {
  const FilterBar({
    super.key,
    required this.selectedDatePreset,
    required this.selectedType,
    required this.searchQuery,
    required this.onDatePresetChanged,
    required this.onTypeChanged,
    required this.onSearchChanged,
    required this.onAdvancedFilter,
  });

  final DateRangePreset selectedDatePreset;
  final String? selectedType;
  final String searchQuery;
  final ValueChanged<DateRangePreset> onDatePresetChanged;
  final ValueChanged<String?> onTypeChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onAdvancedFilter;

  @override
  State<FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends State<FilterBar> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchQuery);
  }

  @override
  void didUpdateWidget(FilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery &&
        widget.searchQuery != _searchController.text) {
      _searchController.text = widget.searchQuery;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xs,
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '搜索描述...',
              prefixIcon: const Icon(Icons.search, size: 20),
              border: const OutlineInputBorder(),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                vertical: AppSpacing.sm,
              ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        widget.onSearchChanged('');
                      },
                      tooltip: '清除搜索',
                    ),
                  IconButton(
                    icon: const Icon(Icons.tune, size: 20),
                    onPressed: widget.onAdvancedFilter,
                    tooltip: '高级筛选',
                  ),
                ],
              ),
            ),
            onChanged: (value) {
              widget.onSearchChanged(value);
              setState(() {});
            },
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              _dateChip('今天', DateRangePreset.today),
              _dateChip('本周', DateRangePreset.thisWeek),
              _dateChip('本月', DateRangePreset.thisMonth),
              _dateChip('本年', DateRangePreset.thisYear),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              _typeChip('全部', null),
              _typeChip('支出', 'expense'),
              _typeChip('收入', 'income'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dateChip(String label, DateRangePreset preset) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: ChoiceChip(
        label: Text(label),
        selected: widget.selectedDatePreset == preset,
        onSelected: (_) => widget.onDatePresetChanged(preset),
      ),
    );
  }

  Widget _typeChip(String label, String? type) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: ChoiceChip(
        label: Text(label),
        selected: widget.selectedType == type,
        onSelected: (_) => widget.onTypeChanged(type),
      ),
    );
  }
}

/// Resolves a DateRangePreset to actual DateTime range.
({DateTime from, DateTime to}) resolveDateRange(DateRangePreset preset) {
  switch (preset) {
    case DateRangePreset.today:
      return DateRanges.today();
    case DateRangePreset.thisWeek:
      return DateRanges.thisWeek();
    case DateRangePreset.thisMonth:
      return DateRanges.thisMonth();
    case DateRangePreset.thisYear:
      return DateRanges.thisYear();
    case DateRangePreset.custom:
      return DateRanges.thisMonth();
  }
}
