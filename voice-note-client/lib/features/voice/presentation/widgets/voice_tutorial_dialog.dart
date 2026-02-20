import 'package:flutter/material.dart';

import '../../../../app/design_tokens.dart';

/// Step-by-step onboarding dialog for the voice accounting feature.
///
/// Shows a 3-page PageView explaining the main interaction modes.
class VoiceTutorialDialog extends StatefulWidget {
  const VoiceTutorialDialog({super.key});

  @override
  State<VoiceTutorialDialog> createState() => _VoiceTutorialDialogState();
}

class _VoiceTutorialDialogState extends State<VoiceTutorialDialog> {
  final _controller = PageController();
  int _currentPage = 0;

  static const _steps = [
    _TutorialStep(
      icon: Icons.mic_rounded,
      title: '语音说一说',
      description: '对着手机说出消费内容，例如：\n'
          '"午饭三十五"\n"打车到公司28块5"',
      hint: 'AI 会自动识别金额、分类和日期',
    ),
    _TutorialStep(
      icon: Icons.keyboard_rounded,
      title: '键盘快捷输入',
      description: '不方便说话？切换到键盘模式，\n'
          '点击快捷词或手动输入即可。',
      hint: '快捷词会根据你的使用习惯智能排序',
    ),
    _TutorialStep(
      icon: Icons.check_circle_rounded,
      title: '确认后记账',
      description: '识别结果会显示在确认卡片上，\n'
          '你可以点击任意字段修改，\n'
          '确认无误后点击"确认记账"。',
      hint: '离线时也能使用本地识别',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.xlAll),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 260,
              child: PageView.builder(
                controller: _controller,
                itemCount: _steps.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (_, i) => _StepPage(step: _steps[i]),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _PageIndicator(
              count: _steps.length,
              current: _currentPage,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: AppSpacing.lg),
            _buildActions(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(ThemeData theme) {
    final isLast = _currentPage == _steps.length - 1;
    return Row(
      children: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('跳过'),
        ),
        const Spacer(),
        FilledButton(
          onPressed: isLast
              ? () => Navigator.pop(context)
              : () => _controller.nextPage(
                    duration: AppDuration.normal,
                    curve: Curves.easeInOut,
                  ),
          child: Text(isLast ? '开始记账' : '下一步'),
        ),
      ],
    );
  }
}

// ─── Internal data class ───

class _TutorialStep {
  final IconData icon;
  final String title;
  final String description;
  final String hint;

  const _TutorialStep({
    required this.icon,
    required this.title,
    required this.description,
    required this.hint,
  });
}

// ─── Step page widget ───

class _StepPage extends StatelessWidget {
  final _TutorialStep step;

  const _StepPage({required this.step});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.primaryContainer,
            ),
            child: Icon(
              step.icon,
              size: 36,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            step.title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            step.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.5),
              borderRadius: AppRadius.xlAll,
            ),
            child: Text(
              step.hint,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onTertiaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Page indicator dots ───

class _PageIndicator extends StatelessWidget {
  final int count;
  final int current;
  final Color color;

  const _PageIndicator({
    required this.count,
    required this.current,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == current;
        return AnimatedContainer(
          duration: AppDuration.fast,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: isActive ? color : color.withValues(alpha: 0.25),
          ),
        );
      }),
    );
  }
}
