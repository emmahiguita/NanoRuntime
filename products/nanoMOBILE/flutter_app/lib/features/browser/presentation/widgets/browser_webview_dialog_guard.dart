import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/features/browser/application/browser_credential_notifier.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_dialog_helper.dart';

/// Presenta diálogos nativos solo mientras la vista del navegador existe.
///
/// Separa UI de seguridad del ciclo de vida del WebView. Así un callback tardío
/// devuelve una respuesta segura sin intentar usar un Overlay ya destruido.
class BrowserWebViewDialogGuard {
  BrowserWebViewDialogGuard({
    required this.context,
    required this.ref,
    required this.isAlive,
  });

  final BuildContext Function() context;
  final WidgetRef ref;
  final bool Function() isAlive;

  void showBlocked({required String url, required String reason}) {
    if (!isAlive()) return;
    BrowserDialogHelper.showFirewallBlockedDialog(
      context: context(),
      url: url,
      reason: reason,
    );
  }

  Future<ServerTrustAuthResponse> requestServerTrust(
    URLAuthenticationChallenge challenge,
  ) async {
    if (!isAlive()) return _cancelServerTrust();
    final response = await BrowserDialogHelper.showSslWarningDialog(
      context: context(),
      host: challenge.protectionSpace.host,
    );
    return isAlive() ? response ?? _cancelServerTrust() : _cancelServerTrust();
  }

  Future<HttpAuthResponse> requestHttpAuth(
    URLAuthenticationChallenge challenge,
  ) async {
    if (!isAlive()) return _cancelHttpAuth();
    final host = challenge.protectionSpace.host;
    final saved = await ref
        .read(browserCredentialProvider.notifier)
        .getCredentialsForDomain(host);
    if (!isAlive()) return _cancelHttpAuth();

    final response = await BrowserDialogHelper.showHttpAuthDialog(
      context: context(),
      host: host,
      realm: challenge.protectionSpace.realm ?? '',
      initialUser: saved.firstOrNull?.username,
      initialPass: saved.firstOrNull?.password,
    );
    if (!isAlive() || response == null) return _cancelHttpAuth();

    if (response.action == HttpAuthResponseAction.PROCEED &&
        response.username.isNotEmpty &&
        response.password.isNotEmpty) {
      await ref
          .read(browserCredentialProvider.notifier)
          .saveCredential(
            domain: host,
            username: response.username,
            password: response.password,
          );
    }
    return response;
  }

  Future<PermissionResponse> requestPermission(
    PermissionRequest request,
  ) async {
    if (!isAlive()) return _deny(request);
    final action = await BrowserDialogHelper.showPermissionPromptDialog(
      context: context(),
      origin: request.origin.toString(),
      resources: request.resources,
    );
    return isAlive()
        ? PermissionResponse(resources: request.resources, action: action)
        : _deny(request);
  }

  ServerTrustAuthResponse _cancelServerTrust() =>
      ServerTrustAuthResponse(action: ServerTrustAuthResponseAction.CANCEL);

  HttpAuthResponse _cancelHttpAuth() =>
      HttpAuthResponse(action: HttpAuthResponseAction.CANCEL);

  PermissionResponse _deny(PermissionRequest request) => PermissionResponse(
    resources: request.resources,
    action: PermissionResponseAction.DENY,
  );
}
