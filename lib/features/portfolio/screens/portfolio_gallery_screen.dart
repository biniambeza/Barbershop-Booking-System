import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../models/barber_model.dart';
import '../../shared/widgets/ui_kit.dart';
import '../portfolio_service.dart';
import '../widgets/portfolio_photo_image.dart';

/// Opens [barber]'s gallery. Resolves to true when the customer tapped
/// "Book this style with ..." (the caller then starts or updates the
/// booking with that barber).
Future<bool> openPortfolioGallery(BuildContext context, {required String shopId, required Barber barber, bool canBook = false}) async {
  final booked = await Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => PortfolioGalleryScreen(shopId: shopId, barber: barber, canBook: canBook)),
  );
  return booked == true;
}

/// A barber's portfolio as a 3-column grid. The photos are fetched when
/// this screen opens (never while listing shops); a tap opens the
/// full-screen [PortfolioViewerScreen]. Pops with true when the customer
/// chose to book.
class PortfolioGalleryScreen extends StatefulWidget {
  const PortfolioGalleryScreen({super.key, required this.shopId, required this.barber, this.canBook = false, this.service});

  final String shopId;
  final Barber barber;

  /// Show "Book this style with ..." in the viewer.
  final bool canBook;
  final PortfolioService? service;

  @override
  State<PortfolioGalleryScreen> createState() => _PortfolioGalleryScreenState();
}

class _PortfolioGalleryScreenState extends State<PortfolioGalleryScreen> {
  PortfolioService get _service => widget.service ?? PortfolioService.instance;
  late Future<List<PortfolioPhoto>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.load(widget.shopId, widget.barber.id);
  }

  @override
  void didUpdateWidget(PortfolioGalleryScreen old) {
    super.didUpdateWidget(old);
    if (old.barber.id != widget.barber.id || old.shopId != widget.shopId) {
      _future = _service.load(widget.shopId, widget.barber.id);
    }
  }

  void _retry() => setState(() => _future = _service.load(widget.shopId, widget.barber.id, force: true));

  Future<void> _open(List<PortfolioPhoto> photos, int index) async {
    final book = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PortfolioViewerScreen(
          photos: photos,
          initialIndex: index,
          barber: widget.barber,
          canBook: widget.canBook,
          service: widget.service,
        ),
      ),
    );
    if (book == true && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.portfolioOfBarber(widget.barber.name))),
      body: FutureBuilder<List<PortfolioPhoto>>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return _Message(
              icon: Icons.cloud_off_rounded,
              text: l.portfolioLoadFailed,
              action: TextButton.icon(
                key: const ValueKey('portfolio-retry'),
                onPressed: _retry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(l.portfolioRetry),
              ),
            );
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          return ListenableBuilder(
            listenable: _service,
            builder: (context, _) {
              final photos = _service.cached(widget.shopId, widget.barber.id) ?? snap.data!;
              if (photos.isEmpty) return _Message(icon: Icons.photo_library_outlined, text: l.portfolioEmpty);
              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    sliver: SliverToBoxAdapter(
                      child: Text(l.portfolioPhotoCount(photos.length),
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    sliver: PortfolioGrid(photos: photos, onTap: (i) => _open(photos, i), service: widget.service),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// Square photo tiles, 3 per row, with the style name on the photo.
class PortfolioGrid extends StatelessWidget {
  const PortfolioGrid({super.key, required this.photos, required this.onTap, this.service, this.trailing});

  final List<PortfolioPhoto> photos;
  final void Function(int index) onTap;
  final PortfolioService? service;

  /// An extra tile after the photos (the "Add photo" tile when managing).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final extra = trailing == null ? 0 : 1;
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index >= photos.length) return trailing!;
          final photo = photos[index];
          return Semantics(
            button: true,
            label: photo.caption ?? l.portfolioPhotoSemantics(index + 1),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusTile + 2),
              child: Material(
                color: AppTheme.surface,
                child: InkWell(
                  key: ValueKey('portfolio-tile-${photo.id}'),
                  onTap: () => onTap(index),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      PortfolioPhotoImage(photo: photo, service: service, cacheWidth: 360),
                      if (photo.caption != null)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0x00000000), Color(0xAA000000)],
                              ),
                            ),
                            child: Text(
                              photo.caption!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: AppTheme.onHero, fontSize: 11.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
        childCount: photos.length + extra,
      ),
    );
  }
}

/// Full-screen photos with swipe and pinch-zoom, the style name, and
/// "Book this style with (barber)" (pops with true).
class PortfolioViewerScreen extends StatefulWidget {
  const PortfolioViewerScreen({
    super.key,
    required this.photos,
    required this.barber,
    this.initialIndex = 0,
    this.canBook = false,
    this.service,
    this.actions,
  });

  final List<PortfolioPhoto> photos;
  final Barber barber;
  final int initialIndex;
  final bool canBook;
  final PortfolioService? service;

  /// Extra app bar actions for the photo shown (staff: edit, delete).
  final List<Widget> Function(BuildContext context, PortfolioPhoto photo)? actions;

  @override
  State<PortfolioViewerScreen> createState() => _PortfolioViewerScreenState();
}

class _PortfolioViewerScreenState extends State<PortfolioViewerScreen> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.photos.isEmpty ? 0 : widget.photos.length - 1);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final photos = widget.photos;
    final photo = photos.isEmpty ? null : photos[_index];
    return Scaffold(
      backgroundColor: AppTheme.photoBackdrop,
      appBar: AppBar(
        backgroundColor: AppTheme.photoBackdrop,
        foregroundColor: AppTheme.onHero,
        iconTheme: IconThemeData(color: AppTheme.onHero),
        actionsIconTheme: IconThemeData(color: AppTheme.onHero),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: Text(
          photos.isEmpty ? '' : l.portfolioViewerCounter(_index + 1, photos.length),
          key: const ValueKey('portfolio-viewer-counter'),
          style: TextStyle(color: AppTheme.onHero, fontSize: 15, fontWeight: FontWeight.w600),
        ),
        actions: photo == null || widget.actions == null ? null : widget.actions!(context, photo),
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              key: const ValueKey('portfolio-viewer-pages'),
              controller: _controller,
              itemCount: photos.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: PortfolioPhotoImage(
                  key: ValueKey('portfolio-viewer-photo-${photos[i].id}'),
                  photo: photos[i],
                  service: widget.service,
                  fit: BoxFit.contain,
                  dark: true,
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (photo?.caption != null) ...[
                    Text(
                      photo!.caption!,
                      key: const ValueKey('portfolio-viewer-caption'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.onHero, fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    widget.barber.name,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.onInkMuted, fontSize: 13),
                  ),
                  if (widget.canBook) ...[
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      key: const ValueKey('portfolio-book-style'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.green,
                        foregroundColor: AppTheme.onInk,
                      ),
                      onPressed: () => Navigator.of(context).pop(true),
                      icon: const Icon(Icons.content_cut_rounded, size: 18),
                      label: Text(l.portfolioBookStyle(widget.barber.name), overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconTile(icon: icon, color: AppTheme.success, size: 56),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary)),
            if (action != null) ...[const SizedBox(height: 8), action!],
          ],
        ),
      ),
    );
  }
}
