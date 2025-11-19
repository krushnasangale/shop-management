import 'package:flutter/material.dart';
import 'package:nkt/main.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const MyHomePage(title: '# NK Nagarwala'),
        ),
      );
    } on FirebaseAuthException catch (e, st) {
      String message = 'Login failed. Please try again.';
      if (e.code == 'user-not-found') {
        message = 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        message = 'Incorrect password provided.';
      } else if (e.code == 'invalid-email') {
        message = 'The email address is invalid.';
      }
      debugPrint('FirebaseAuthException during login: ${e.code} ${e.message}');
      debugPrint('$st');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      debugPrint('Unhandled exception during login: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final fillColor = isDarkMode ? Colors.grey[850] : Colors.grey[200];
    final labelColor = Theme.of(context).textTheme.bodyLarge?.color;
    final hintColor = Theme.of(context).textTheme.bodyMedium?.color;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- App Icon (Optional) ---
                Icon(
                  Icons.account_circle,
                  size: 80,
                  color: Colors.blue,
                ),
                const SizedBox(height: 40),

                // Email
                Text(
                  'Email',
                  style: TextStyle(color: labelColor, fontWeight: FontWeight.w600, fontSize: 16),
                ),
                const SizedBox(height: 8.0),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'Enter your username or email',
                    hintStyle: TextStyle(color: hintColor),
                    filled: true,
                    fillColor: fillColor,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: Icon(Icons.email, color: hintColor),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Please enter email';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Password
                Text(
                  'Password',
                  style: TextStyle(color: labelColor, fontWeight: FontWeight.w600, fontSize: 16),
                ),
                const SizedBox(height: 8.0),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: 'Enter your password',
                    hintStyle: TextStyle(color: hintColor),
                    filled: true,
                    fillColor: fillColor,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: Icon(Icons.lock_outline, color: hintColor),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Please enter password';
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // Login Button
                SizedBox(
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _loading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text(
                            'Login',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}