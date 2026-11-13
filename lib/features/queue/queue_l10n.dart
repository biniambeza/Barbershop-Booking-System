import '../../l10n/l10n.dart';
import '../../services/queue_service.dart';

/// Queue error texts in the active language.
extension QueueL10n on AppLocalizations {
  /// [QueueException]s by code; everything else via [errorText].
  String queueErrorText(Object error) {
    if (error is! QueueException) return errorText(error);
    Object? arg(int i) => i < error.args.length ? error.args[i] : null;
    switch (error.code) {
      case QueueErrorCode.notStaff:
        return queueErrNotStaff;
      case QueueErrorCode.customersOnly:
        return queueErrCustomersOnly;
      case QueueErrorCode.nameRequired:
        final max = arg(0);
        return queueErrNameRequired(max is int ? max : kQueueNameMaxLength);
      case QueueErrorCode.barberBusy:
        return queueErrBarberBusy('${arg(0) ?? ''}');
      case QueueErrorCode.notWaiting:
        return queueErrNotWaiting;
      case QueueErrorCode.notServing:
        return queueErrNotServing;
    }
  }
}
