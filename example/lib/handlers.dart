import 'package:deep_link_orchestrator/deep_link_orchestrator.dart';
import 'package:flutter/widgets.dart';

import 'intents.dart';

class ProfileHandler extends DeepLinkHandler {
  @override
  bool get requiresAuthentication => false;

  ProfileHandler(this.onNavigate);

  final void Function(String userId) onNavigate;

  @override
  bool canHandle(DeepLinkIntent intent) => intent is ProfileIntent;

  @override
  Future<void> handle({
    required DeepLinkHandlerContext context,
    required DeepLinkIntent intent,
  }) async {
    final profile = intent as ProfileIntent;
    debugPrint('[ProfileHandler] Navigating to user: ${profile.userId}');
    onNavigate(profile.userId);
  }
}

class InviteHandler extends DeepLinkHandler {
  InviteHandler(this.onInvite);

  final void Function(String code) onInvite;

  @override
  bool get requiresAuthentication => true;

  @override
  bool canHandle(DeepLinkIntent intent) => intent is InviteIntent;

  @override
  Future<void> handle({
    required DeepLinkHandlerContext context,
    required DeepLinkIntent intent,
  }) async {
    final invite = intent as InviteIntent;
    debugPrint('[InviteHandler] Accepting invite: ${invite.inviteCode}');
    onInvite(invite.inviteCode);
  }
}

class SettingsHandler extends DeepLinkHandler {
  @override
  bool get requiresAuthentication => false;

  SettingsHandler(this.onNavigate);

  final void Function(String? section) onNavigate;

  @override
  bool canHandle(DeepLinkIntent intent) => intent is SettingsIntent;

  @override
  Future<void> handle({
    required DeepLinkHandlerContext context,
    required DeepLinkIntent intent,
  }) async {
    final settings = intent as SettingsIntent;
    debugPrint(
      '[SettingsHandler] Opening settings: ${settings.section ?? "root"}',
    );
    onNavigate(settings.section);
  }
}
