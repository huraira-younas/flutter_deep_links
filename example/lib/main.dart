import 'package:flutter_deep_links/flutter_deep_links.dart';
import 'package:flutter/material.dart';

import 'handlers.dart';
import 'intents.dart';

void main() => runApp(const DeepLinkExampleApp());

class DeepLinkExampleApp extends StatefulWidget {
  const DeepLinkExampleApp({super.key});

  @override
  State<DeepLinkExampleApp> createState() => _DeepLinkExampleAppState();
}

class _DeepLinkExampleAppState extends State<DeepLinkExampleApp> {
  late final DeepLinkOrchestrator _orchestrator;
  final List<String> _log = <String>[];

  @override
  void initState() {
    super.initState();
    _setupDeepLinks();
  }

  Future<void> _setupDeepLinks() async {
    _orchestrator = DeepLinkOrchestrator(
      sources: [AppLinksDeepLinkSource()],
      intentResolver: resolveIntent,
      pendingStore: InMemoryDeepLinkPendingStore(),
      validationPolicy: DeepLinkValidator(
        supportedPaths: ['/profile', '/invite', '/settings'],
        expectedHost: 'example.com',
        customScheme: 'myapp',
      ),
    );

    _orchestrator.dispatcher
      ..registerHandler(ProfileHandler(_onProfile))
      ..registerHandler(InviteHandler(_onInvite))
      ..registerHandler(SettingsHandler(_onSettings));

    await _orchestrator.initialize();
    await _orchestrator.checkInitialIntent();
  }

  void _onProfile(String userId) {
    setState(() => _log.add('Navigate to profile: $userId'));
  }

  void _onInvite(String code) {
    setState(() => _log.add('Accept invite: $code'));
  }

  void _onSettings(String? section) {
    setState(() => _log.add('Open settings: ${section ?? "root"}'));
  }

  @override
  void dispose() {
    _orchestrator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Deep Link Example')),
        body: _log.isEmpty
            ? const Center(
                child: Text(
                  'Open a deep link to see it handled here.\n\n'
                  'Try:\n'
                  '  myapp://example.com/profile/42\n'
                  '  myapp://example.com/invite?code=ABC\n'
                  '  myapp://example.com/settings/notifications',
                  textAlign: TextAlign.center,
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                separatorBuilder: (_, __) => const Divider(),
                itemCount: _log.length,
                itemBuilder: (_, index) => Text(_log[index]),
              ),
      ),
    );
  }
}
