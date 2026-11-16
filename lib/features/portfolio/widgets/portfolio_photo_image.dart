import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../portfolio_service.dart';

/// One portfolio photo from either source: inline base64 (free plan, shown
/// at once) or Cloud Storage (downloaded when this widget is first built,
/// so a grid only fetches the tiles on screen). [cacheWidth] limits the
/// decoded size (grid thumbnails).
class PortfolioPhotoImage extends StatefulWidget {
  const PortfolioPhotoImage({
    super.key,
    required this.photo,
    this.service,
    this.fit = BoxFit.cover,
    this.cacheWidth,
    this.dark = false,
  });

  final PortfolioPhoto photo;

  /// Defaults to [PortfolioService.instance].
  final PortfolioService? service;
  final BoxFit fit;
  final int? cacheWidth;

  /// Spinner and error icon for a dark background (the viewer).
  final bool dark;

  @override
  State<PortfolioPhotoImage> createState() => _PortfolioPhotoImageState();
}

class _PortfolioPhotoImageState extends State<PortfolioPhotoImage> {
  Future<Uint8List>? _future;

  PortfolioService get _service => widget.service ?? PortfolioService.instance;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(PortfolioPhotoImage old) {
    super.didUpdateWidget(old);
    if (old.photo.cacheKey != widget.photo.cacheKey) _resolve();
  }

  void _resolve() {
    _future = widget.photo.inlineBytes == null ? _service.loadBytes(widget.photo) : null;
  }

  Color get _muted => widget.dark ? AppTheme.onInkMuted : AppTheme.textTertiary;

  Widget _image(Uint8List bytes) => Image.memory(
        bytes,
        fit: widget.fit,
        cacheWidth: widget.cacheWidth,
        gaplessPlayback: true,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, _, __) => _error(),
      );

  Widget _error() => GestureDetector(
        key: ValueKey('portfolio-photo-error-${widget.photo.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: widget.photo.inlineBytes == null ? () => setState(_resolve) : null,
        child: Center(child: Icon(Icons.broken_image_outlined, color: _muted)),
      );

  @override
  Widget build(BuildContext context) {
    final inline = widget.photo.inlineBytes;
    if (inline != null) return _image(inline);
    return FutureBuilder<Uint8List>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasData) return _image(snap.data!);
        if (snap.hasError) return _error();
        return Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: _muted),
          ),
        );
      },
    );
  }
}
