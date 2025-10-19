// frontend/lib/features/auth/screens/register_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../widgets/loading_spinner.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _pendingOnboardingRedirect = false;

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (_formKey.currentState?.validate() ?? false) {
      final email = _emailController.text.trim();
      final username = _usernameController.text.trim();
      final password = _passwordController.text;

      final registered =
          await ref.read(authProvider.notifier).register(username, email, password);
      if (!mounted) return;
      if (registered) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created! Let\'s finish setting things up.'),
            backgroundColor: Colors.green,
          ),
        );
        _pendingOnboardingRedirect = true;
        final loggedIn =
            await ref.read(authProvider.notifier).login(email, password);
        if (!loggedIn) {
          _pendingOnboardingRedirect = false;
        }
      }
    }
  }

  String _mapAuthError(Object error) {
    final raw = error.toString();
    final normalized = raw.toLowerCase();
    final usernameTaken =
        normalized.contains('username') && normalized.contains('already') &&
            (normalized.contains('taken') || normalized.contains('exists'));
    if (usernameTaken) {
      return 'That username is already taken. Try a different one.';
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AuthState>>(authProvider, (previous, next) {
      next.whenOrNull(
        error: (error, stackTrace) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_mapAuthError(error)),
              backgroundColor: Colors.red,
            ),
          );
        },
        data: (authState) {
          final user = authState.user;
          if (_pendingOnboardingRedirect && user != null) {
            _pendingOnboardingRedirect = false;
            if (!mounted) return;
            context.go('/onboarding/profile');
          }
        },
      );
    });

    final authStateAsync = ref.watch(authProvider);
    final isLoading = authStateAsync.isLoading;

    Color withOpacity(Color color, double opacity) =>
        color.withAlpha((opacity * 255).round());

    final formContent = Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _usernameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Username',
                  labelStyle: const TextStyle(color: Colors.white70),
                  enabledBorder: OutlineInputBorder(
                    borderSide:
                        BorderSide(color: withOpacity(Colors.white, 0.5)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide:
                        BorderSide(color: Colors.white, width: 2.0),
                  ),
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter a username' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: const TextStyle(color: Colors.white70),
                  enabledBorder: OutlineInputBorder(
                    borderSide:
                        BorderSide(color: withOpacity(Colors.white, 0.5)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide:
                        BorderSide(color: Colors.white, width: 2.0),
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
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: const TextStyle(color: Colors.white70),
                  enabledBorder: OutlineInputBorder(
                    borderSide:
                        BorderSide(color: withOpacity(Colors.white, 0.5)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide:
                        BorderSide(color: Colors.white, width: 2.0),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Password cannot be empty';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => isLoading ? null : _submit(),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0)),
                ),
                child: isLoading
                    ? const LoadingSpinner(size: 24)
                    : const Text('Sign Up'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go('/login'),
                child: Text(
                  'Already have an account? Log in',
                  style: TextStyle(color: withOpacity(Colors.white, 0.7)),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Sign Up'),
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        child: isLoading
            ? const Center(
                key: ValueKey('register-loading'),
                child: LoadingSpinner(),
              )
            : KeyedSubtree(
                key: const ValueKey('register-form'),
                child: formContent,
              ),
      ),
    );
  }
}
