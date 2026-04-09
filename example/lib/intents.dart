import 'package:flutter_deep_links/flutter_deep_links.dart';

// ---------------------------------------------------------------------------
// Concrete intents
// ---------------------------------------------------------------------------

class ProfileIntent extends DeepLinkIntent {
  const ProfileIntent({
    required this.userId,
    required super.sourceId,
    required super.uri,
  });

  final String userId;
}

class InviteIntent extends DeepLinkIntent {
  const InviteIntent({
    required this.inviteCode,
    required super.sourceId,
    required super.uri,
  });

  final String inviteCode;
}

class SettingsIntent extends DeepLinkIntent {
  const SettingsIntent({
    required super.sourceId,
    required super.uri,
    this.section,
  });

  final String? section;
}

// ---------------------------------------------------------------------------
// Intent resolver
// ---------------------------------------------------------------------------

DeepLinkIntent resolveIntent(DeepLinkIntent intent) {
  final segments = intent.uri.pathSegments;
  final params = intent.uri.queryParameters;

  if (segments.firstOrNull == 'profile' && segments.length > 1) {
    return ProfileIntent(
      userId: segments[1],
      sourceId: intent.sourceId,
      uri: intent.uri,
    );
  }

  if (segments.firstOrNull == 'invite' && params.containsKey('code')) {
    return InviteIntent(
      inviteCode: params['code']!,
      sourceId: intent.sourceId,
      uri: intent.uri,
    );
  }

  if (segments.firstOrNull == 'settings') {
    return SettingsIntent(
      section: segments.elementAtOrNull(1),
      sourceId: intent.sourceId,
      uri: intent.uri,
    );
  }

  return intent;
}
