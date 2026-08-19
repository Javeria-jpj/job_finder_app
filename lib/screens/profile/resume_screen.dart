import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/resume_controller.dart';
import '../../models/resume_file.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/error_banner.dart';

/// Upload, replace, download or remove the user's resume.
class ResumeScreen extends StatelessWidget {
  const ResumeScreen({super.key});

  Future<void> _upload(BuildContext context) async {
    final controller = context.read<ResumeController>();
    final uploaded = await controller.pickAndUpload();

    if (!context.mounted || !uploaded) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Resume uploaded.')));
  }

  Future<void> _download(BuildContext context) async {
    final controller = context.read<ResumeController>();
    await controller.download();
  }

  Future<void> _remove(BuildContext context) async {
    final controller = context.read<ResumeController>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove resume?'),
        content: const Text(
          'The file will be deleted from your account. You can upload another '
          'at any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await controller.remove();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = context.watch<ResumeController>();
    final resume = controller.resume;

    return Scaffold(
      appBar: AppBar(title: const Text('My Resume')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.gutter),
              children: [
                if (controller.error != null) ...[
                  ErrorBanner(message: controller.error!),
                  const SizedBox(height: AppSpacing.gutter),
                ],
                if (resume == null)
                  _EmptyState(
                    busy: controller.busy,
                    onUpload: () => _upload(context),
                  )
                else
                  _ResumeCard(
                    resume: resume,
                    busy: controller.busy,
                    onReplace: () => _upload(context),
                    onDownload: () => _download(context),
                    onRemove: () => _remove(context),
                  ),
                const SizedBox(height: AppSpacing.gutter),
                AppCard(
                  color: AppColors.surfaceContainerHigh,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 20,
                        color: AppColors.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'PDF or Word, up to '
                          '${ResumeFile.maxBytes ~/ 1024} KB. The file is '
                          'stored on your account, so it follows you to any '
                          'device you sign in on.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.busy, required this.onUpload});

  final bool busy;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              height: 64,
              width: 64,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.primaryFixed,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.upload_file,
                size: 28,
                color: AppColors.secondary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.gutter),
          Text(
            'Upload your resume',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Attach a PDF or Word document so it is ready when you apply.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.gutter),
          FilledButton.icon(
            onPressed: busy ? null : onUpload,
            icon: busy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : const Icon(Icons.add, size: 18),
            label: Text(busy ? 'Uploading…' : 'Choose file'),
          ),
        ],
      ),
    );
  }
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({
    required this.resume,
    required this.busy,
    required this.onReplace,
    required this.onDownload,
    required this.onRemove,
  });

  final ResumeFile resume;
  final bool busy;
  final VoidCallback onReplace;
  final VoidCallback onDownload;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 48,
                width: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primaryFixed,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Text(
                  resume.extensionLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      resume.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(_subtitle(resume), style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.gutter),
          // Wrap, not Row: three buttons do not fit across a phone.
          Wrap(
            spacing: AppSpacing.base,
            runSpacing: AppSpacing.base,
            children: [
              FilledButton.icon(
                onPressed: busy ? null : onReplace,
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: const Text('Replace'),
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : onDownload,
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('Download'),
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : onRemove,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Remove'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _subtitle(ResumeFile resume) {
    final updatedAt = resume.updatedAt;
    if (updatedAt == null) return resume.sizeLabel;

    final date =
        '${updatedAt.day.toString().padLeft(2, '0')}/'
        '${updatedAt.month.toString().padLeft(2, '0')}/'
        '${updatedAt.year}';
    return '${resume.sizeLabel} · Uploaded $date';
  }
}
