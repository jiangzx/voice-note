import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/design_tokens.dart';
import '../../../../core/utils/id_generator.dart' as id_gen;
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../../shared/widgets/error_state_widget.dart';
import '../../../../shared/widgets/shimmer_placeholder.dart';
import '../../domain/entities/account_entity.dart';
import '../providers/account_providers.dart';

/// Account management screen for creating, editing, and archiving accounts.
class AccountManageScreen extends ConsumerWidget {
  const AccountManageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('账户管理')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: accountsAsync.when(
        data: (accounts) {
          if (accounts.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.account_balance_wallet_outlined,
              title: '暂无账户',
            );
          }

          return ListView.builder(
            itemCount: accounts.length,
            itemBuilder: (context, index) {
              final account = accounts[index];
              return ListTile(
                leading: CircleAvatar(child: Text(account.name[0])),
                title: Text(account.name),
                subtitle: Text(_accountTypeLabel(account.type)),
                trailing: account.isPreset
                    ? const Chip(label: Text('默认'))
                    : PopupMenuButton<String>(
                        onSelected: (action) {
                          if (action == 'edit') {
                            _showEditDialog(context, ref, account);
                          } else if (action == 'archive') {
                            _archiveAccount(context, ref, account);
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'edit', child: Text('编辑')),
                          const PopupMenuItem(
                            value: 'archive',
                            child: Text('归档'),
                          ),
                        ],
                      ),
                onTap: () => _showEditDialog(context, ref, account),
              );
            },
          );
        },
        loading: () => ShimmerPlaceholder.listPlaceholder(itemCount: 3),
        error: (e, _) => ErrorStateWidget(
          message: '加载失败: $e',
          onRetry: () => ref.invalidate(accountListProvider),
        ),
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    String selectedType = 'cash';

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('新建账户'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '账户名称',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: selectedType,
                style: (Theme.of(ctx).textTheme.titleMedium ??
                        const TextStyle(fontSize: 16))
                    .copyWith(
                        fontSize:
                            Theme.of(ctx).textTheme.titleMedium?.fontSize ??
                                16,
                        height:
                            Theme.of(ctx).textTheme.titleMedium?.height ?? 1.0),
                decoration: const InputDecoration(
                  labelText: '账户类型',
                  border: OutlineInputBorder(),
                ),
                items: _accountTypes.entries
                    .map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    )
                    .toList(),
                onChanged: (v) =>
                    setDialogState(() => selectedType = v ?? 'cash'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                final repo = await ref.read(accountRepositoryProvider.future);
                final now = DateTime.now();
                await repo.create(
                  AccountEntity(
                    id: id_gen.generateId(),
                    name: nameController.text.trim(),
                    type: selectedType,
                    icon: 'material:account_balance_wallet',
                    color: 'FF009688',
                    isPreset: false,
                    sortOrder: 999,
                    initialBalance: 0,
                    isArchived: false,
                    createdAt: now,
                    updatedAt: now,
                  ),
                );
                ref.invalidate(accountListProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    AccountEntity account,
  ) {
    final nameController = TextEditingController(text: account.name);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑账户'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: '账户名称',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              final repo = await ref.read(accountRepositoryProvider.future);
              await repo.update(
                account.copyWith(name: nameController.text.trim()),
              );
              ref.invalidate(accountListProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _archiveAccount(
    BuildContext context,
    WidgetRef ref,
    AccountEntity account,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('归档账户'),
        content: Text('确定要归档"${account.name}"吗？归档后不会再出现在账户列表中。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('归档'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final repo = await ref.read(accountRepositoryProvider.future);
    await repo.archive(account.id);
    ref.invalidate(accountListProvider);
  }

  String _accountTypeLabel(String type) {
    return _accountTypes[type] ?? type;
  }

  static const _accountTypes = {
    'cash': '现金',
    'bank_card': '银行卡',
    'credit_card': '信用卡',
    'wechat': '微信',
    'alipay': '支付宝',
    'custom': '自定义',
  };
}
