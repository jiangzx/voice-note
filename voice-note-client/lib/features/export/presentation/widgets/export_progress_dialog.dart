import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../app/design_tokens.dart';
import '../../domain/export_config.dart';
import '../../domain/export_service.dart';

/// Dialog showing export progress with cancel and share actions.
class ExportProgressDialog extends StatefulWidget {
  const ExportProgressDialog({
    super.key,
    required this.config,
    required this.exportService,
  });

  final ExportConfig config;
  final ExportService exportService;

  @override
  State<ExportProgressDialog> createState() => _ExportProgressDialogState();
}

class _ExportProgressDialogState extends State<ExportProgressDialog> {
  int _processed = 0;
  int _total = 0;
  bool _cancelled = false;
  bool _done = false;
  bool _noData = false;
  String? _error;
  File? _exportedFile;
  final GlobalKey _shareButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _runExport();
  }

  Future<void> _runExport() async {
    try {
      final file = await widget.exportService.export(
        config: widget.config,
        onProgress: (processed, total) {
          if (mounted) {
            setState(() {
              _processed = processed;
              _total = total;
            });
          }
        },
        isCancelled: () => _cancelled,
      );

      if (!mounted) return;

      if (file == null) {
        setState(() {
          if (_cancelled) {
            Navigator.of(context).pop();
          } else {
            _noData = true;
            _done = true;
          }
        });
      } else {
        setState(() {
          _exportedFile = file;
          _done = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _done = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(_done ? (_noData ? '无数据' : (_error != null ? '导出失败' : '导出完成')) : '正在导出...'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_done) ...[
            LinearProgressIndicator(
              value: _total > 0 ? _processed / _total : null,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              _total > 0 ? '已导出 $_processed/$_total 条' : '正在统计数据...',
              style: theme.textTheme.bodyMedium,
            ),
          ],
          if (_noData)
            const Text('没有符合条件的数据'),
          if (_error != null)
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          if (_done && _exportedFile != null)
            Column(
              children: [
                Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 48),
                const SizedBox(height: AppSpacing.sm),
                Text('已导出 $_total 条记录'),
              ],
            ),
        ],
      ),
      actions: [
        if (!_done)
          TextButton(
            onPressed: () {
              _cancelled = true;
            },
            child: const Text('取消'),
          ),
        if (_done && (_noData || _error != null))
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        if (_done && _exportedFile != null) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
          FilledButton.icon(
            key: _shareButtonKey,
            onPressed: () async {
              Rect? origin;
              final box = _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
              if (box != null && box.hasSize) {
                origin = box.localToGlobal(Offset.zero) & box.size;
              }
              await widget.exportService.share(_exportedFile!, sharePositionOrigin: origin);
            },
            icon: const Icon(Icons.share),
            label: const Text('分享'),
          ),
        ],
      ],
    );
  }
}
