import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/legal_links.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../shared/widgets/ui_kit.dart';
import 'privacy_policy_text.dart';

/// Opens [url] outside the app; false when no browser could take it.
typedef LinkLauncher = Future<bool> Function(Uri url);

Future<bool> _launchExternal(Uri url) async {
  try {
    return await launchUrl(url, mode: LaunchMode.externalApplication);
  } catch (e) {
    debugPrint('Could not open $url: $e');
    return false;
  }
}

/// Tests: replaces url_launcher (null restores it).
@visibleForTesting
LinkLauncher? debugLinkLauncher;

Future<bool> openExternalLink(String url) => (debugLinkLauncher ?? _launchExternal)(Uri.parse(url));

/// Opens the privacy policy on the website ([kPrivacyPolicyUrl]) and, when
/// no browser can open it (offline, no browser app, tests), the copy
/// bundled in the app.
Future<void> openPrivacyPolicy(BuildContext context) async {
  final navigator = Navigator.of(context);
  final opened = await openExternalLink(kPrivacyPolicyUrl);
  if (!opened) {
    await navigator.push(MaterialPageRoute<void>(builder: (_) => const PrivacyPolicyScreen()));
  }
}

/// The privacy policy bundled in the app, in the app's language, with a
/// link to the web page and the account deletion page.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  Future<void> _open(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.l10n.privacyLinkFailed;
    if (!await openExternalLink(url)) messenger.showSnackBar(SnackBar(content: Text(failed)));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final sections = privacyPolicySections(Localizations.localeOf(context).languageCode);
    return Scaffold(
      appBar: AppBar(title: Text(l.privacyPolicyTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              key: const ValueKey('privacy-policy-list'),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                HeroCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.privacy_tip_outlined, size: 28),
                      const SizedBox(height: 10),
                      Text(
                        l.privacyPolicyTitle,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.onInk),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l.privacyPolicyUpdated(kPrivacyPolicyUpdated),
                        style: const TextStyle(fontSize: 12, color: AppTheme.onInkMuted),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _PillLink(
                            key: const ValueKey('privacy-open-web'),
                            icon: Icons.open_in_new_rounded,
                            label: l.privacyOpenWeb,
                            onTap: () => _open(context, kPrivacyPolicyUrl),
                          ),
                          _PillLink(
                            key: const ValueKey('privacy-open-delete-page'),
                            icon: Icons.person_remove_outlined,
                            label: l.privacyDeletePageLink,
                            onTap: () => _open(context, kDeleteAccountUrl),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                for (final s in sections) ...[
                  AppCard(child: _SectionBody(section: s)),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PillLink extends StatelessWidget {
  const _PillLink({super.key, required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.10),
      shape: StadiumBorder(side: BorderSide(color: Colors.white.withValues(alpha: 0.16))),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: AppTheme.onInk),
              const SizedBox(width: 6),
              Flexible(
                child: Text(label,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.onInk)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionBody extends StatelessWidget {
  const _SectionBody({required this.section});

  final PolicySection section;

  @override
  Widget build(BuildContext context) {
    const body = TextStyle(fontSize: 14, height: 1.45, color: AppTheme.textPrimary);
    final lines = section.body.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(section.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        for (final line in lines)
          if (line.trim().isEmpty)
            const SizedBox(height: 8)
          else if (line.startsWith('• '))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 7, right: 8),
                    child: Icon(Icons.circle, size: 6, color: AppTheme.green),
                  ),
                  Expanded(child: SelectableText(line.substring(2), style: body)),
                ],
              ),
            )
          else
            Padding(padding: const EdgeInsets.only(bottom: 4), child: SelectableText(line, style: body)),
      ],
    );
  }
}

/// "By signing up you agree to our Privacy Policy" with the link, for the
/// sign-in / registration screen.
class PrivacyConsentNote extends StatelessWidget {
  const PrivacyConsentNote({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(l.privacyConsentPrefix, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        InkWell(
          key: const ValueKey('privacy-consent-link'),
          borderRadius: BorderRadius.circular(6),
          onTap: () => openPrivacyPolicy(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
            child: Text(
              l.privacyPolicyTitle,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.success,
                decoration: TextDecoration.underline,
                decorationColor: AppTheme.success,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
