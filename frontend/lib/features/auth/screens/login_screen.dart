// frontend/lib/features/auth/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../widgets/loading_spinner.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (_formKey.currentState?.validate() ?? false) {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      await ref.read(authProvider.notifier).login(email, password);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AuthState>>(authProvider, (previous, next) {
      next.whenOrNull(
        error: (error, stackTrace) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error.toString()),
              backgroundColor: Colors.red,
            ),
          );
        },
        data: (authState) {
          if (authState.user != null) {
            // Navigate back to the originally requested route if provided
            final from = GoRouterState.of(context).uri.queryParameters['from'];
            if (from != null && from.isNotEmpty) {
              context.go(from);
            } else {
              context.go('/profile');
            }
          }
        },
      );
    });

    final authStateAsync = ref.watch(authProvider);
    final isLoading = authStateAsync.isLoading;
    final theme = ref.watch(themeProvider);

    Color withOpacity(Color color, double opacity) =>
        color.withAlpha((opacity * 255).round());

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        title: Text('Login', style: TextStyle(color: theme.primary)),
        backgroundColor: theme.background,
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _emailController,
                  style: TextStyle(color: theme.primary),
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    labelStyle: TextStyle(color: theme.primary),
                    enabledBorder: OutlineInputBorder(
                      borderSide:
                          BorderSide(color: withOpacity(theme.primary, 0.5)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: theme.accent, width: 2.0),
                    ),
                  ),
                  validator: (value) {
                    if (value == null ||
                        value.isEmpty ||
                        !value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  style: TextStyle(color: theme.primary),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: TextStyle(color: theme.primary),
                    enabledBorder: OutlineInputBorder(
                      borderSide:
                          BorderSide(color: withOpacity(theme.primary, 0.5)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: theme.accent, width: 2.0),
                    ),
                  ),
                  validator: (value) =>
                      value!.isEmpty ? 'Please enter your password' : null,
                  onFieldSubmitted: (_) => isLoading ? null : _submit(),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.accent,
                    foregroundColor: theme.background,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0)),
                  ),
                  child: isLoading
                      ? const LoadingSpinner(size: 24)
                      : const Text('Login'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.go('/register'),
                  child: Text(
                    'Don\'t have an account? Sign up',
                    style: TextStyle(color: withOpacity(theme.primary, 0.7)),
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
