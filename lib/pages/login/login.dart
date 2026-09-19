import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flashbill/main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flashbill/l10n/app_localizations.dart';
import 'package:flashbill/pages/login/register.dart';
import 'package:flashbill/services/auth_service.dart';
import 'package:flashbill/theme/adaptive.dart';
import 'package:flashbill/widgets/app_loader.dart';
import 'package:flashbill/widgets/continue_with_google_button.dart';
import 'package:flashbill/widgets/language_selector.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      if (userCredential.user != null) {
        await AuthService.finishSignIn(userCredential.user!.uid);
      }

      if (!mounted) return;
      _goHome();
    } on FirebaseAuthException catch (e, st) {
      final loc = AppLocalizations.of(context);
      String message = loc?.loginFailed ?? 'Login failed. Please try again.';
      if (e.code == 'user-not-found') {
        message = loc?.userNotFound ?? 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        message = loc?.incorrectPassword ?? 'Incorrect password provided.';
      } else if (e.code == 'invalid-email') {
        message = loc?.invalidEmail ?? 'The email address is invalid.';
      }
      debugPrint('FirebaseAuthException during login: ${e.code} ${e.message}');
      debugPrint('$st');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _loading = true);
    AppLoader.show(message: AppLocalizations.of(context)?.signIn ?? 'Sign In');
    try {
      final credential = await AuthService.signInWithGoogle();
      final user = credential.user;
      if (user == null) {
        throw Exception('Google sign-in failed');
      }

      final hasProfile = await AuthService.hasShopProfile(user.uid);
      if (!hasProfile) {
        return;
      }

      await AuthService.finishSignIn(user.uid);
      if (!mounted) return;
      _goHome();
    } on FirebaseAuthException catch (e) {
      if (AuthService.isCancelled(e)) return;
      if (!mounted) return;
      final loc = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc?.googleSignInFailed ?? 'Google sign-in failed'),
        ),
      );
    } catch (e) {
      if (AuthService.isCancelled(e)) return;
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      AppLoader.hide();
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const MyHomePage(title: '# NK Nagarwala'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;
    final loc = AppLocalizations.of(context);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primary.withValues(alpha: 0.92),
              scheme.primary,
              scheme.primaryContainer,
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              const Positioned(
                top: 8,
                right: 8,
                child: LanguageMenuButton(filledTonal: true),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: size.width > 600 ? 440 : double.infinity,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildHeader(scheme, loc),
                        const SizedBox(height: 36),
                        _buildLoginCard(scheme, loc),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme scheme, AppLocalizations? loc) {
    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: scheme.surface,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(Icons.storefront_rounded, size: 40, color: scheme.primary),
        ),
        const SizedBox(height: 20),
        Text(
          loc?.welcomeBack ?? 'Welcome Back',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: scheme.onPrimary,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          loc?.signInToContinue ?? 'Sign in to continue',
          style: TextStyle(
            fontSize: 16,
            color: scheme.onPrimary.withValues(alpha: 0.82),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard(ColorScheme scheme, AppLocalizations? loc) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTextField(
                controller: _emailController,
                label: loc?.email ?? 'Email',
                hint: loc?.enterEmailOrUsername ?? 'Enter your email or username',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return loc?.pleaseEnterEmailOrUsername ??
                        'Please enter email or username';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _passwordController,
                label: loc?.password ?? 'Password',
                hint: loc?.enterPassword ?? 'Enter your password',
                icon: Icons.lock_outline_rounded,
                obscureText: !_showPassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _showPassword
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                  ),
                  onPressed: () {
                    setState(() => _showPassword = !_showPassword);
                  },
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return loc?.pleaseEnterPassword ?? 'Please enter password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 28),
              _buildLoginButton(loc),
              const SizedBox(height: 16),
              GoogleAuthDivider(label: loc?.orLabel ?? 'or'),
              const SizedBox(height: 16),
              ContinueWithGoogleButton(
                label: loc?.continueWithGoogle ?? 'Continue with Google',
                loading: _loading,
                onPressed: _loginWithGoogle,
              ),
              const SizedBox(height: 16),
              _buildSignUpRow(loc),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    if (Adaptive.isCupertino) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          CupertinoTextFormFieldRow(
            controller: controller,
            placeholder: hint,
            keyboardType: keyboardType,
            obscureText: obscureText,
            prefix: Icon(icon, size: 20),
            validator: validator,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ],
      );
    }

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
      ),
    );
  }

  Widget _buildLoginButton(AppLocalizations? loc) {
    final child = _loading
        ? SizedBox(height: 22, width: 22, child: Adaptive.progress())
        : Text(loc?.signIn ?? 'Sign In');

    if (Adaptive.isCupertino) {
      return CupertinoButton.filled(
        onPressed: _loading ? null : _login,
        child: child,
      );
    }

    return FilledButton(onPressed: _loading ? null : _login, child: child);
  }

  Widget _buildSignUpRow(AppLocalizations? loc) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(loc?.dontHaveAccount ?? "Don't have an account?"),
        TextButton(
          onPressed: _loading
              ? null
              : () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RegisterPage()),
                  );
                },
          child: Text(loc?.signUp ?? 'Sign Up'),
        ),
      ],
    );
  }
}

