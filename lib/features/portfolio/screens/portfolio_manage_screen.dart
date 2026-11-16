import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../models/barber_model.dart';
import '../../shared/widgets/ui_kit.dart';
import '../portfolio_l10n.dart';
import '../portfolio_service.dart';
import 'portfolio_gallery_screen.dart';

/// Returns a compressed base64 JPEG, or null when the person cancels.
typedef PortfolioPhotoPicker = Future<String?> Function({required bool camera});

/// The barber (their own) or the shop owner (any of the shop's barbers):
/// add photos from the camera or gallery with an optional style name, edit
/// the name, delete. At most [kMaxPortfolioPhotos].
class PortfolioManageScreen extends StatefulWidget {
  const PortfolioManageScreen({super.key, required this.shopId, required this.barber, this.service, this.picker});

  final String shopId;
  final Barber barber;
  final PortfolioService? service;

  /// Defaults to [PortfolioImagePicker.pick] (tests pass a fake).
  final PortfolioPhotoPicker? picker;

  @override
  State<PortfolioManageScreen> createState() => _PortfolioManageScreenState();
}

class _PortfolioManageScreenState extends State<PortfolioManageScreen> {
  PortfolioService get _service => widget.service ?? PortfolioService.instance;
  late Future<List<PortfolioPhoto>> _future;
  PortfolioImagePicker? _defaultPicker;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _service.load(widget.shopId, widget.barber.id, force: true);
  }

  @override
  void didUpdateWidget(PortfolioManageScreen old) {
    super.didUpdateWidget(old);
    if (old.barber.id != widget.barber.id || old.shopId != widget.shopId) {
      _future = _service.load(widget.shopId, widget.barber.id, force: true);
    }
  }

  void _retry() => setState(() => _future = _service.load(widget.shopId, widget.barber.id, force: true));

  Future<String?> _pick({required bool camera}) {
    final picker = widget.picker;
    if (picker != null) return picker(camera: camera);
    return (_defaultPicker ??= PortfolioImagePicker()).pick(camera: camera);
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      _toast(done);
    } catch (e) {
      if (mounted) _toast(context.l10n.portfolioErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    final l = context.l10n;
    final camera = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const ValueKey('portfolio-pick-camera'),
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l.portfolioTakePhoto),
              onTap: () => Navigator.pop(context, true),
            ),
            ListTile(
              key: const ValueKey('portfolio-pick-gallery'),
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l.portfolioChooseFromGallery),
              onTap: () => Navigator.pop(context, false),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (camera == null || !mounted) return;
    String? image;
    try {
      setState(() => _busy = true);
      image = await _pick(camera: camera);
    } catch (e) {
      if (mounted) _toast(context.l10n.portfolioErrorText(e is PortfolioException ? e : const PortfolioImageException()));
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (image == null || !mounted) return;
    final caption = await _askCaption(null);
    if (caption == null || !mounted) return;
    final b64 = image;
    await _run(
      () => _service.add(shopId: widget.shopId, barberId: widget.barber.id, base64Jpeg: b64, caption: caption),
      l.portfolioAdded,
    );
  }

  /// The style name dialog. Returns '' for "no name", null on cancel.
  Future<String?> _askCaption(String? initial) {
    return showDialog<String>(
      context: context,
      builder: (_) => _CaptionDialog(initial: initial),
    );
  }

  Future<void> _photoActions(PortfolioPhoto photo, List<PortfolioPhoto> photos) async {
    final l = context.l10n;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const ValueKey('portfolio-action-view'),
              leading: const Icon(Icons.fullscreen_rounded),
              title: Text(l.portfolioTitle),
              subtitle: photo.caption == null ? null : Text(photo.caption!),
              onTap: () => Navigator.pop(context, 'view'),
            ),
            ListTile(
              key: const ValueKey('portfolio-action-caption'),
              leading: const Icon(Icons.edit_outlined),
              title: Text(l.portfolioEditCaption),
              onTap: () => Navigator.pop(context, 'caption'),
            ),
            ListTile(
              key: const ValueKey('portfolio-action-delete'),
              leading: const Icon(Icons.delete_outline, color: AppTheme.danger),
              title: Text(l.portfolioDeletePhoto, style: const TextStyle(color: AppTheme.danger)),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'view':
        await Navigator.of(context).push(MaterialPageRoute<bool>(
          fullscreenDialog: true,
          builder: (_) => PortfolioViewerScreen(
            photos: photos,
            initialIndex: photos.indexOf(photo),
            barber: widget.barber,
            service: widget.service,
          ),
        ));
      case 'caption':
        final caption = await _askCaption(photo.caption);
        if (caption == null || !mounted) return;
        await _run(() => _service.setCaption(photo, caption), l.portfolioCaptionSaved);
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l.portfolioDeleteConfirmTitle),
            content: Text(l.portfolioDeleteConfirmBody),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
              TextButton(
                key: const ValueKey('portfolio-delete-confirm'),
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
                child: Text(l.delete),
              ),
            ],
          ),
        );
        if (ok != true || !mounted) return;
        await _run(() => _service.remove(photo), l.portfolioDeleted);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.portfolioManageTitle)),
      body: Stack(
        children: [
          FutureBuilder<List<PortfolioPhoto>>(
            future: _future,
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l.portfolioLoadFailed, style: const TextStyle(color: AppTheme.textSecondary)),
                      TextButton.icon(
                        key: const ValueKey('portfolio-retry'),
                        onPressed: _retry,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(l.portfolioRetry),
                      ),
                    ],
                  ),
                );
              }
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              return ListenableBuilder(
                listenable: _service,
                builder: (context, _) {
                  final photos = _service.cached(widget.shopId, widget.barber.id) ?? snap.data!;
                  final full = photos.length >= kMaxPortfolioPhotos;
                  return CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        sliver: SliverToBoxAdapter(child: _summary(photos.length, full)),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                        sliver: PortfolioGrid(
                          photos: photos,
                          service: widget.service,
                          onTap: (i) => _photoActions(photos[i], photos),
                          trailing: full ? null : _AddTile(onTap: _busy ? null : _add),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x33000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _summary(int count, bool full) {
    final l = context.l10n;
    return HeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(widget.barber.name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.onInk)),
              ),
              HeroChip(
                key: const ValueKey('portfolio-count'),
                icon: Icons.photo_library_outlined,
                label: l.portfolioCountOfMax(count, kMaxPortfolioPhotos),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(l.portfolioManageIntro(kMaxPortfolioPhotos),
              style: const TextStyle(color: AppTheme.onInkMuted, fontSize: 13)),
          const SizedBox(height: 12),
          AppProgressBar(value: count / kMaxPortfolioPhotos),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.public_rounded, size: 15, color: AppTheme.onInkMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(l.portfolioPublicNotice, style: const TextStyle(color: AppTheme.onInkMuted, fontSize: 12)),
              ),
            ],
          ),
          if (full) ...[
            const SizedBox(height: 10),
            Text(l.portfolioFull(kMaxPortfolioPhotos),
                key: const ValueKey('portfolio-full'),
                style: const TextStyle(color: AppTheme.onInk, fontSize: 12.5, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusTile + 2),
        side: const BorderSide(color: AppTheme.hairline, width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey('portfolio-add'),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_a_photo_outlined, color: AppTheme.green),
            const SizedBox(height: 6),
            Text(context.l10n.portfolioAddPhoto,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          ],
        ),
      ),
    );
  }
}

class _CaptionDialog extends StatefulWidget {
  const _CaptionDialog({this.initial});

  final String? initial;

  @override
  State<_CaptionDialog> createState() => _CaptionDialogState();
}

class _CaptionDialogState extends State<_CaptionDialog> {
  late final TextEditingController _text = TextEditingController(text: widget.initial ?? '');

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.portfolioEditCaption),
      content: TextField(
        key: const ValueKey('portfolio-caption-field'),
        controller: _text,
        autofocus: true,
        maxLength: kMaxPortfolioCaptionLength,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: l.portfolioCaptionLabel, hintText: l.portfolioCaptionHint),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        TextButton(
          key: const ValueKey('portfolio-caption-save'),
          onPressed: () => Navigator.pop(context, _text.text),
          child: Text(l.save),
        ),
      ],
    );
  }
}
