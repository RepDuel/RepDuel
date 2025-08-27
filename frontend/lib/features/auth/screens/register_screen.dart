// frontend/lib/features/auth/screens/register_screen.dart

import 'dart:async'; // For potential future async operations if needed
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/auth_provider.dart'; // Import auth provider
import '../../../widgets/error_display.dart'; // For displaying errors
import '../../../widgets/loading_spinner.dart'; // For displaying loading state

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

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Handles the registration submission process.
  Future<void> _submit() async {
    // Validate the form fields first.
    if (_formKey.currentState?.validate() ?? false) {
      final email = _emailController.text.trim();
      final username = _usernameController.text.trim();
      final password = _passwordController.text.trim();

      // Attempt to register using the AuthNotifier.
      // The register method now returns void and updates the provider state directly.
      // We'll watch the provider state to react to success/failure.
      await ref.read(authProvider.notifier).register(username, email, password);

      // The UI will react to the state change in the build method.
      // Explicit success/failure feedback might still be useful via snackbars
      // or error messages if the provider sets an error state.
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch the authProvider to get the AsyncValue<AuthState>.
    final authStateAsyncValue = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: Colors.black, // Assuming a dark theme
      appBar: AppBar(
        title: const Text('Sign Up'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        // Use .when() to handle loading, error, and data states from AsyncValue.
        child: authStateAsyncValue.when(
          loading: () => const Center(child: LoadingSpinner()), // Show spinner when loading
          error: (error, stackTrace) => Center( // Show error if auth fails
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ErrorDisplay(message: error.toString()), // Display the error message
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _submit, // Retry registration attempt
                  child: const Text('Retry Registration'),
                ),
              ],
            ),
          ),
          data: (authState) { // authState is the actual AuthState object here
            // Check if registration resulted in immediate login state or if user is already logged in.
            // If user is logged in, navigate away. This should ideally be handled by router guards.
            if (authState.user != null && authState.token != null) {
              // Schedule navigation after build is complete to avoid errors.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                context.go('/profile'); // Redirect to profile if already logged in
              });
              return const Center(child: LoadingSpinner()); // Show loading while redirecting
            }

            // --- Registration form is shown when not loading, not errored, and not logged in ---
            return Form(
              key: _formKey,
              child: Column(
                children: [
                  // Display registration error from authState.error if it exists and is not loading.
                  // Note: AuthNotifier now uses AsyncValue.error, so check .hasError.
                  if (authState.error != null && authState.error!.isNotEmpty)
                    Padding( // Add padding around the error display
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: ErrorDisplay(message: authState.error!),
                    ),
                  
                  TextFormField(
                    controller: emailController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: const TextStyle(color: Colors.white70),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: const BorderSide(color: Colors.tealAccent, width: 2.0),
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) => value!.isEmpty ? 'Please enter your email' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: usernameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Username',
                      labelStyle: const TextStyle(color: Colors.white70),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: const BorderSide(color: Colors.tealAccent, width: 2.0),
                      ),
                    ),
                    validator: (value) => value!.isEmpty ? 'Please enter your username' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: const TextStyle(color: Colors.white70),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: const BorderSide(color: Colors.tealAccent, width: 2.0),
                      ),
                    ),
                    validator: (value) => value!.isEmpty ? 'Please enter your password' : null,
                    onFieldSubmitted: (_) => _submit(), // Allow submission on keyboard action
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _submit, // Call the submit logic
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.tealAccent[400], // Primary accent color
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    child: const Text('Sign Up'),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.go('/login'), // Use GoRouter for navigation
                    child: Text(
                      'Already have an account? Log in',
                      style: TextStyle(color: Colors.white.withOpacity(0.7)), // Subtle text color
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}