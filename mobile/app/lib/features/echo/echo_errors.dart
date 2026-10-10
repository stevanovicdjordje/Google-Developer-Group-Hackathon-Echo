import '../../data/repositories.dart';
import '../../l10n/app_localizations.dart';

/// User-facing text for a failed Echo call.
String echoErrorText(AppLocalizations l10n, Object error) =>
    switch (error is EchoException ? error.kind : EchoErrorKind.failed) {
      EchoErrorKind.aiBusy => l10n.echoErrorAiBusy,
      EchoErrorKind.rateLimited => l10n.echoErrorRateLimited,
      EchoErrorKind.offline => l10n.echoErrorOffline,
      EchoErrorKind.noTranscript => l10n.echoErrorNoTranscript,
      EchoErrorKind.failed => l10n.echoErrorFailed,
    };
