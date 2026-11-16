import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import 'receipt_image.dart';
import 'subscription_receipts_service.dart';

/// A receipt's photo from either source: inline base64 (free plan) or
/// Firebase Storage (`imagePath`, Blaze), with a loading and an error
/// state. [compact] (list thumbnails) shows [placeholder] on error;
/// otherwise the error has a message and a retry button.
class ReceiptPhoto extends StatefulWidget {
  const ReceiptPhoto({
    super.key,
    required this.payment,
    this.service,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.compact = false,
    this.placeholder,
    this.imageKey,
  });

  final SubscriptionPayment payment;

  /// Defaults to [SubscriptionReceiptsService.instance].
  final SubscriptionReceiptsService? service;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool compact;

  /// Shown by a [compact] photo that cannot be loaded.
  final Widget? placeholder;

  /// Key of the [Image] once it is shown.
  final Key? imageKey;

  @override
  State<ReceiptPhoto> createState() => _ReceiptPhotoState();
}

class _ReceiptPhotoState extends State<ReceiptPhoto> {
  /// Inline photos decode synchronously (no loading flash).
  Uint8List? _inline;
  Future<Uint8List>? _future;

  SubscriptionReceiptsService get _service => widget.service ?? SubscriptionReceiptsService.instance;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(ReceiptPhoto old) {
    super.didUpdateWidget(old);
    if (old.payment.receiptImage != widget.payment.receiptImage || old.payment.imagePath != widget.payment.imagePath) {
      _resolve();
    }
  }

  void _resolve() {
    final p = widget.payment;
    _inline = p.hasInlineImage ? decodeReceiptImage(p.receiptImage) : null;
    _future = _inline == null && p.hasStoredImage ? _service.loadReceiptPhoto(p) : null;
  }

  void _retry() => setState(_resolve);

  Widget _image(Uint8List bytes) => Image.memory(
        bytes,
        key: widget.imageKey,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        gaplessPlayback: true,
        errorBuilder: (context, _, __) => _error(context),
      );

  Widget _box(Widget child) => SizedBox(width: widget.width, height: widget.height, child: Center(child: child));

  Widget _error(BuildContext context) {
    if (widget.compact) {
      return widget.placeholder ??
          _box(Icon(Icons.broken_image_outlined, color: AppTheme.textSecondary));
    }
    final l = context.l10n;
    return Padding(
      key: const ValueKey('receipt-photo-error'),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, color: AppTheme.textSecondary, size: 32),
          const SizedBox(height: 8),
          Text(l.rcptPhotoLoadFailed,
              textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 4),
          TextButton.icon(
            key: const ValueKey('receipt-photo-retry'),
            onPressed: _retry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(l.rcptPhotoRetry),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inline = _inline;
    if (inline != null) return _image(inline);
    final future = _future;
    if (future == null) return _error(context);
    return FutureBuilder<Uint8List>(
      future: future,
      builder: (context, snap) {
        if (snap.hasData) return _image(snap.data!);
        if (snap.hasError) return _error(context);
        return _box(
          SizedBox(
            key: const ValueKey('receipt-photo-loading'),
            width: widget.compact ? 18 : 28,
            height: widget.compact ? 18 : 28,
            child: const CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
    );
  }
}
