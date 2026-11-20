import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../app/app_colors.dart';
import '../../core/offline_content_store.dart';
import '../../core/vocabulary_pdf.dart';
import '../../core/user_message.dart';
import '../../widgets/decorative_border.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/icon_badge.dart';
import '../../widgets/learnlite_card.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/section_header.dart';
import '../auth/auth_gateway.dart';
import 'content_gateway.dart';

class OfflineContentScreen extends StatefulWidget {
  const OfflineContentScreen({required this.gateway, super.key});

  final DictionaryGateway gateway;

  @override
  State<OfflineContentScreen> createState() => _OfflineContentScreenState();
}

class _OfflineContentScreenState extends State<OfflineContentScreen> {
  late Future<List<ContentPackDescriptor>> _packsFuture;
  late Future<int> _storageFuture;
  String? _busyPackId;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _packsFuture = widget.gateway.availableContentPacks();
    _storageFuture = widget.gateway.offlineStorageBytes();
  }

  void _refresh() {
    setState(() {
      _errorMessage = null;
      _packsFuture = widget.gateway.availableContentPacks();
      _storageFuture = widget.gateway.offlineStorageBytes();
    });
  }

  Future<void> _download(ContentPackDescriptor pack) async {
    setState(() {
      _busyPackId = pack.id;
      _errorMessage = null;
    });
    try {
      await widget.gateway.downloadContentPack(pack.id);
      if (mounted) _refresh();
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } on FormatException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } on OfflineStorageFailure catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _busyPackId = null);
    }
  }

  Future<void> _remove(ContentPackDescriptor pack) async {
    setState(() {
      _busyPackId = pack.id;
      _errorMessage = null;
    });
    try {
      await widget.gateway.removeContentPack(pack.id);
      if (mounted) _refresh();
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } on FormatException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } on OfflineStorageFailure catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _busyPackId = null);
    }
  }

  /// Opens (print/preview, which includes "Save as PDF") or shares a saved
  /// PDF pack. Both work offline because the bytes are on the device.
  Future<void> _openPdf(ContentPackDescriptor pack, {bool share = false}) async {
    setState(() => _errorMessage = null);
    try {
      final bytes = await widget.gateway.fetchResourceBytes(
        vocabularyPdfResourceKey,
      );
      if (share) {
        await Printing.sharePdf(bytes: bytes, filename: vocabularyPdfResourceKey);
      } else {
        await Printing.layoutPdf(
          name: vocabularyPdfResourceKey,
          onLayout: (_) async => bytes,
        );
      }
    } on Object catch (error) {
      if (mounted) {
        setState(
          () => _errorMessage = userMessage(
            error,
            fallback: 'The word list could not be opened. Remove it and '
                'download it again.',
          ),
        );
      }
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () async => _refresh(),
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHeader(
                  title: 'Offline Content Packs',
                  subtitle:
                      'Only published lessons and verified dictionary entries are available to download.',
                ),
                const SizedBox(height: 16),
                FutureBuilder<int>(
                  future: _storageFuture,
                  builder: (context, snapshot) => LearnLiteCard(
                    backgroundColor: AppColors.charcoal,
                    padding: EdgeInsets.zero,
                    elevated: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 18, 8, 18),
                          child: Row(
                            children: [
                              const IconBadge(
                                icon: Icons.storage_rounded,
                                tone: IconBadgeTone.dark,
                                size: 46,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Downloaded content',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(color: AppColors.white),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      snapshot.hasError
                                          ? userMessage(
                                              snapshot.error,
                                              fallback:
                                                  'Storage usage is unavailable right now.',
                                            )
                                          : '${_formatSize(snapshot.data ?? 0)} stored on this device',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: AppColors.gold),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Refresh content packs',
                                onPressed: _refresh,
                                color: AppColors.gold,
                                icon: const Icon(Icons.refresh_rounded),
                              ),
                            ],
                          ),
                        ),
                        const DecorativeBorder(height: 8),
                      ],
                    ),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                const SectionHeader(title: 'Available packs'),
                const SizedBox(height: 12),
                FutureBuilder<List<ContentPackDescriptor>>(
                  future: _packsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const LoadingCard(height: 120);
                    }
                    if (snapshot.hasError) {
                      return LearnLiteCard(
                        child: EmptyState(
                          icon: Icons.cloud_off_outlined,
                          title: 'Content packs unavailable',
                          message: 'Connect to LearnLite to check for published resources, or retry if content was downloaded before.',
                          action: TextButton(
                            onPressed: _refresh,
                            child: const Text('Try again'),
                          ),
                        ),
                      );
                    }
                    final packs = snapshot.data ?? const [];
                    if (packs.isEmpty) {
                      return const LearnLiteCard(
                        child: EmptyState(
                          icon: Icons.download_for_offline_outlined,
                          title: 'No content packs available',
                          message: 'Published lessons and verified dictionary entries will appear here when they are available.',
                        ),
                      );
                    }
                    return Column(
                      children: [
                        for (final pack in packs) ...[
                          _PackCard(
                            pack: pack,
                            isBusy: _busyPackId == pack.id,
                            onDownload: () => _download(pack),
                            onRemove: () => _remove(pack),
                            onOpen: pack.type == 'pdf'
                                ? () => _openPdf(pack)
                                : null,
                            onShare: pack.type == 'pdf'
                                ? () => _openPdf(pack, share: true)
                                : null,
                            formatSize: _formatSize,
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _PackCard extends StatelessWidget {
  const _PackCard({
    required this.pack,
    required this.isBusy,
    required this.onDownload,
    required this.onRemove,
    required this.formatSize,
    this.onOpen,
    this.onShare,
  });

  final ContentPackDescriptor pack;
  final bool isBusy;
  final VoidCallback onDownload;
  final VoidCallback onRemove;
  final VoidCallback? onOpen;
  final VoidCallback? onShare;
  final String Function(int bytes) formatSize;

  String get _kind => switch (pack.type) {
    'dictionary' => 'Dictionary',
    'pdf' => 'Word list PDF, made from the workbooks',
    _ => 'Learning module',
  };

  @override
  Widget build(BuildContext context) => LearnLiteCard(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        IconBadge(
          icon: switch (pack.type) {
            'dictionary' => Icons.menu_book_rounded,
            'pdf' => Icons.picture_as_pdf_rounded,
            _ => Icons.auto_stories_rounded,
          },
          tone: pack.type == 'module'
              ? IconBadgeTone.red
              : IconBadgeTone.gold,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pack.title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 3),
              Text(
                pack.downloaded || pack.sizeBytes > 0
                    ? '$_kind · ${formatSize(pack.sizeBytes)}'
                    : _kind,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.gray),
              ),
            ],
          ),
        ),
        if (isBusy)
          const SizedBox(
            width: 36,
            height: 36,
            child: Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
          )
        else if (pack.downloaded)
          PopupMenuButton<String>(
            tooltip: 'Downloaded pack options',
            onSelected: (value) {
              switch (value) {
                case 'open':
                  onOpen?.call();
                case 'share':
                  onShare?.call();
                case 'remove':
                  onRemove();
              }
            },
            itemBuilder: (context) => [
              if (onOpen != null)
                const PopupMenuItem(value: 'open', child: Text('Open')),
              if (onShare != null)
                const PopupMenuItem(value: 'share', child: Text('Share or save')),
              const PopupMenuItem(value: 'remove', child: Text('Remove download')),
            ],
            child: const StatusPill(
              icon: Icons.check_circle_rounded,
              label: 'Downloaded',
              tone: IconBadgeTone.dark,
            ),
          )
        else
          IconButton.filled(
            tooltip: 'Download content pack',
            onPressed: onDownload,
            icon: const Icon(Icons.download_rounded),
          ),
      ],
    ),
  );
}
