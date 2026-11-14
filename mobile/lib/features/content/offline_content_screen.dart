import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../core/offline_content_store.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/learnlite_card.dart';
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
                const SectionHeader(title: 'Offline Content Packs'),
                const SizedBox(height: 8),
                Text(
                  'Only published lessons and verified dictionary entries are available to download.',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: AppColors.gray),
                ),
                const SizedBox(height: 18),
                FutureBuilder<int>(
                  future: _storageFuture,
                  builder: (context, snapshot) => LearnLiteCard(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.storage_outlined,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Downloaded content',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                snapshot.hasError
                                    ? 'Storage usage is unavailable: ${snapshot.error}'
                                    : '${_formatSize(snapshot.data ?? 0)} stored on this device',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppColors.gray),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Refresh content packs',
                          onPressed: _refresh,
                          icon: const Icon(Icons.refresh),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppColors.primary),
                  ),
                ],
                const SizedBox(height: 18),
                FutureBuilder<List<ContentPackDescriptor>>(
                  future: _packsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(28),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return Column(
                        children: [
                          const EmptyState(
                            icon: Icons.cloud_off_outlined,
                            title: 'Content packs unavailable',
                            message: 'Connect to LearnLite to check for published resources, or retry if content was downloaded before.',
                          ),
                          TextButton(
                            onPressed: _refresh,
                            child: const Text('Try again'),
                          ),
                        ],
                      );
                    }
                    final packs = snapshot.data ?? const [];
                    if (packs.isEmpty) {
                      return const EmptyState(
                        icon: Icons.download_for_offline_outlined,
                        title: 'No content packs available',
                        message: 'Published lessons and verified dictionary entries will appear here when they are available.',
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
  });

  final ContentPackDescriptor pack;
  final bool isBusy;
  final VoidCallback onDownload;
  final VoidCallback onRemove;
  final String Function(int bytes) formatSize;

  @override
  Widget build(BuildContext context) => LearnLiteCard(
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: AppColors.lightPink,
            shape: BoxShape.circle,
          ),
          child: Icon(
            pack.type == 'dictionary'
                ? Icons.menu_book_outlined
                : Icons.auto_stories_outlined,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pack.title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 3),
              Text(
                '${pack.type == 'dictionary' ? 'Dictionary' : 'Learning module'} · ${formatSize(pack.sizeBytes)}',
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
              if (value == 'remove') onRemove();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'remove', child: Text('Remove download')),
            ],
            child: const Chip(
              avatar: Icon(Icons.check_circle_outline, size: 18),
              label: Text('Downloaded'),
            ),
          )
        else
          IconButton(
            tooltip: 'Download content pack',
            onPressed: onDownload,
            icon: const Icon(Icons.download_outlined, color: AppColors.primary),
          ),
      ],
    ),
  );
}
