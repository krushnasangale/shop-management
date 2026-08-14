import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flashbill/l10n/app_localizations.dart';
import 'package:flashbill/theme/adaptive.dart';
import 'package:material_ui/material_ui.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? _currentPasswordError;
  String? _newPasswordError;
  String? _confirmPasswordError;
  var _showCurrentPassword = false;
  var _showNewPassword = false;
  var _showConfirmPassword = false;
  var _isSaving = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _validate(AppLocalizations? loc) {
    var hasError = false;
    setState(() {
      _currentPasswordError = null;
      _newPasswordError = null;
      _confirmPasswordError = null;

      if (_currentPasswordController.text.isEmpty) {
        _currentPasswordError =
            loc?.currentPasswordRequired ?? 'Current password is required';
        hasError = true;
      }
      if (_newPasswordController.text.isEmpty) {
        _newPasswordError =
            loc?.newPasswordRequired ?? 'New password is required';
        hasError = true;
      } else if (_newPasswordController.text.length < 6) {
        _newPasswordError =
            loc?.passwordMinLength ?? 'Password must be at least 6 characters';
        hasError = true;
      }
      if (_confirmPasswordController.text.isEmpty) {
        _confirmPasswordError =
            loc?.confirmPasswordRequired ?? 'Please confirm your password';
        hasError = true;
      } else if (_newPasswordController.text !=
          _confirmPasswordController.text) {
        _confirmPasswordError =
            loc?.passwordsDoNotMatch ?? 'Passwords do not match';
        hasError = true;
      }
    });
    return !hasError;
  }

  Future<void> _save() async {
    final loc = AppLocalizations.of(context);
    if (!_validate(loc) || _isSaving) return;

    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              loc?.userNotAuthenticated ?? 'User not authenticated',
            ),
          ),
        );
        return;
      }

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPasswordController.text,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(_newPasswordController.text);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            loc?.passwordChangedSuccessfully ??
                'Password changed successfully!',
          ),
        ),
      );
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      var errorMessage =
          loc?.failedToChangePassword ?? 'Failed to change password';
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        errorMessage =
            loc?.currentPasswordIncorrect ?? 'Current password is incorrect';
      } else if (e.code == 'weak-password') {
        errorMessage = loc?.newPasswordTooWeak ?? 'New password is too weak';
      } else if (e.code == 'requires-recent-login') {
        errorMessage =
            loc?.reauthenticateRequired ??
            'Please log out and log in again for security';
      }
      if (mounted) {
        setState(() => _currentPasswordError = errorMessage);
      }
    } catch (e) {
      var errorMessage =
          loc?.failedToChangePassword ?? 'Failed to change password';
      if (e.toString().contains('wrong-password')) {
        errorMessage =
            loc?.currentPasswordIncorrect ?? 'Current password is incorrect';
      } else if (e.toString().contains('weak-password')) {
        errorMessage = loc?.newPasswordTooWeak ?? 'New password is too weak';
      } else if (e.toString().contains('requires-recent-login')) {
        errorMessage =
            loc?.reauthenticateRequired ??
            'Please log out and log in again for security';
      }
      if (mounted) {
        setState(() => _currentPasswordError = errorMessage);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final title = loc?.changePassword ?? 'Change Password';

    if (Adaptive.isCupertino) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(middle: Text(title)),
        child: SafeArea(child: _buildBody(loc)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _buildBody(loc),
    );
  }

  Widget _buildBody(AppLocalizations? loc) {
    return AutofillGroup(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _sectionLabel(title: loc?.changePassword ?? 'Change Password'),
                _PasswordGroup(
                  children: [
                    _PasswordField(
                      controller: _currentPasswordController,
                      label: loc?.currentPassword ?? 'Current Password',
                      errorText: _currentPasswordError,
                      obscure: !_showCurrentPassword,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.password],
                      onToggle: () {
                        setState(
                          () => _showCurrentPassword = !_showCurrentPassword,
                        );
                      },
                      onChanged: () {
                        if (_currentPasswordError != null) {
                          setState(() => _currentPasswordError = null);
                        }
                      },
                    ),
                    _PasswordField(
                      controller: _newPasswordController,
                      label: loc?.newPassword ?? 'New Password',
                      helperText:
                          loc?.passwordMinLength ??
                          'Password must be at least 6 characters',
                      errorText: _newPasswordError,
                      obscure: !_showNewPassword,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newPassword],
                      onToggle: () {
                        setState(() => _showNewPassword = !_showNewPassword);
                      },
                      onChanged: () {
                        if (_newPasswordError != null) {
                          setState(() => _newPasswordError = null);
                        }
                      },
                    ),
                    _PasswordField(
                      controller: _confirmPasswordController,
                      label: loc?.confirmNewPassword ?? 'Confirm New Password',
                      errorText: _confirmPasswordError,
                      obscure: !_showConfirmPassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.newPassword],
                      onSubmit: _isSaving ? null : _save,
                      onToggle: () {
                        setState(
                          () => _showConfirmPassword = !_showConfirmPassword,
                        );
                      },
                      onChanged: () {
                        if (_confirmPasswordError != null) {
                          setState(() => _confirmPasswordError = null);
                        }
                      },
                    ),
                  ],
                ),
              ]),
            ),
          ),
          Adaptive.sliverBottomAction(
            child: _SaveButton(
              loading: _isSaving,
              label: loc?.changePassword ?? 'Change Password',
              onPressed: _isSaving ? null : _save,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel({required String title}) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _PasswordGroup extends StatelessWidget {
  const _PasswordGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (Adaptive.isCupertino) {
      return CupertinoFormSection.insetGrouped(
        margin: EdgeInsets.zero,
        children: children,
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) const Divider(height: 1, indent: 56),
          ],
        ],
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggle,
    required this.onChanged,
    required this.textInputAction,
    required this.autofillHints,
    this.helperText,
    this.errorText,
    this.onSubmit,
  });

  final TextEditingController controller;
  final String label;
  final String? helperText;
  final String? errorText;
  final bool obscure;
  final VoidCallback onToggle;
  final VoidCallback onChanged;
  final TextInputAction textInputAction;
  final Iterable<String> autofillHints;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final leading = Icon(Icons.lock_outline, color: scheme.primary, size: 22);

    if (Adaptive.isCupertino) {
      return CupertinoFormRow(
        prefix: Text(label),
        error: errorText != null ? Text(errorText!) : null,
        helper: helperText != null && errorText == null
            ? Text(helperText!)
            : null,
        child: Row(
          children: [
            Expanded(
              child: CupertinoTextField(
                controller: controller,
                obscureText: obscure,
                placeholder: label,
                decoration: const BoxDecoration(),
                padding: const EdgeInsets.symmetric(vertical: 11),
                textInputAction: textInputAction,
                autofillHints: autofillHints,
                onChanged: (_) => onChanged(),
                onSubmitted: (_) => onSubmit?.call(),
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: onToggle,
              child: Icon(
                obscure ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
              ),
            ),
          ],
        ),
      );
    }

    return ListTile(
      visualDensity: const VisualDensity(horizontal: 0, vertical: -0.5),
      leading: leading,
      title: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: scheme.onSurfaceVariant,
        ),
      ),
      subtitle: TextField(
        controller: controller,
        obscureText: obscure,
        textInputAction: textInputAction,
        autofillHints: autofillHints,
        onChanged: (_) => onChanged(),
        onSubmitted: (_) => onSubmit?.call(),
        style: Theme.of(context).textTheme.bodyLarge,
        decoration: InputDecoration(
          hintText: label,
          helperText: helperText,
          errorText: errorText,
          isDense: true,
          filled: false,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.only(top: 3, bottom: 5),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
        ),
      ),
      trailing: IconButton(
        icon: Icon(
          obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        ),
        onPressed: onToggle,
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.loading,
    required this.label,
    required this.onPressed,
  });

  final bool loading;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? SizedBox(width: 18, height: 18, child: Adaptive.progress())
        : Text(label);

    if (Adaptive.isCupertino) {
      return SizedBox(
        width: double.infinity,
        child: CupertinoButton.filled(onPressed: onPressed, child: child),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: Adaptive.compactFilled,
        child: child,
      ),
    );
  }
}
