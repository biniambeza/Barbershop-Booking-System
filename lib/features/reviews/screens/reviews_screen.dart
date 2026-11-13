import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../services/app_repository.dart';
import '../../../services/reviews_service.dart';
import '../reviews_l10n.dart';
import '../widgets/review_widgets.dart';

/// All reviews of a shop, or of one of its barbers ([barberId]), newest
/// first, [kReviewPageSize] at a time, under the rating summary and star
/// distribution. The shop owner gets Reply / Edit reply on each review;
/// everyone else (customers, barbers) reads only.
class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key, required this.shopId, this.barberId, this.title, this.service});

  final String shopId;
  final String? barberId;

  /// App bar title (defaults to "Reviews").
  final String? title;
  final ReviewsService? service;

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  final List<Review> _reviews = [];
  RatingDistribution? _distribution;
  Object? _cursor;
  bool _hasMore = false;
  bool _loading = false;
  Object? _error;

  ReviewsService get _service => widget.service ?? ReviewsService.instance;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _reviews.clear();
      _cursor = null;
      _hasMore = false;
      _distribution = null;
      _error = null;
    });
    _service.loadDistribution(widget.shopId, barberId: widget.barberId).then((d) {
      if (mounted) setState(() => _distribution = d);
    }, onError: (Object _) {});
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _service.loadPage(widget.shopId, barberId: widget.barberId, cursor: _cursor);
      if (!mounted) return;
      setState(() {
        _reviews.addAll(page.reviews);
        _cursor = page.cursor;
        _hasMore = page.hasMore;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reply(Review review) async {
    final updated = await showReplyDialog(context, review, service: widget.service);
    if (updated == null || !mounted) return;
    setState(() {
      final i = _reviews.indexWhere((r) => r.id == updated.id);
      if (i >= 0) _reviews[i] = updated;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final repo = AppRepository.instance;
    final canReply = _service.canReply(widget.shopId);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title ?? l.reviewsTitle)),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          key: const ValueKey('reviews-list'),
          padding: const EdgeInsets.all(16),
          children: [
            ListenableBuilder(
              listenable: repo,
              builder: (context, _) => RatingSummaryCard(
                summary: widget.barberId == null
                    ? _service.shopSummary(widget.shopId)
                    : _service.barberSummary(widget.barberId!),
                distribution: _distribution,
              ),
            ),
            const SizedBox(height: 16),
            for (final review in _reviews)
              ReviewTile(
                review: review,
                barberName: widget.barberId == null ? repo.getBarberById(review.barberId)?.name : null,
                onReply: canReply ? () => _reply(review) : null,
                showAwaitingReply: canReply,
              ),
            if (!_loading && _error == null && _reviews.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  l.reviewsEmpty,
                  key: const ValueKey('reviews-empty'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    Text(
                      l.reviewsLoadFailed,
                      key: const ValueKey('reviews-load-failed'),
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                    TextButton(onPressed: _loadMore, child: Text(l.reviewsRetry)),
                  ],
                ),
              ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_hasMore && _error == null)
              Center(
                child: OutlinedButton(
                  key: const ValueKey('reviews-load-more'),
                  onPressed: _loadMore,
                  child: Text(l.reviewsLoadMore),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Owner: adds or edits the public reply to [review]. Returns the updated
/// review, or null when dismissed.
Future<Review?> showReplyDialog(BuildContext context, Review review, {ReviewsService? service}) {
  return showDialog<Review>(
    context: context,
    builder: (_) => _ReplyDialog(review: review, service: service ?? ReviewsService.instance),
  );
}

class _ReplyDialog extends StatefulWidget {
  const _ReplyDialog({required this.review, required this.service});

  final Review review;
  final ReviewsService service;

  @override
  State<_ReplyDialog> createState() => _ReplyDialogState();
}

class _ReplyDialogState extends State<_ReplyDialog> {
  late final TextEditingController _text = TextEditingController(text: widget.review.reply ?? '');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updated = await widget.service.saveReply(widget.review, _text.text);
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(l.reviewsReplySaved)));
      Navigator.of(context).pop(updated);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = l.reviewsErrorText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final review = widget.review;
    return AlertDialog(
      backgroundColor: AppTheme.darkSurface,
      title: Text(review.hasReply ? l.reviewsEditReply : l.reviewsReplyAction),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StarRatingDisplay(rating: review.rating.toDouble(), size: 14),
            if (review.hasComment) ...[
              const SizedBox(height: 6),
              Text(review.comment!, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            ],
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('review-reply-field'),
              controller: _text,
              enabled: !_busy,
              autofocus: true,
              minLines: 2,
              maxLines: 5,
              maxLength: kReviewReplyMaxLength,
              decoration: InputDecoration(labelText: l.reviewsReplyLabel),
            ),
            if (_error != null)
              Text(
                _error!,
                key: const ValueKey('review-reply-error'),
                style: const TextStyle(color: Colors.redAccent, fontSize: 12.5),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: Text(l.cancel)),
        ElevatedButton(
          key: const ValueKey('save-reply'),
          onPressed: _busy ? null : _save,
          child: Text(l.reviewsReplySave),
        ),
      ],
    );
  }
}
