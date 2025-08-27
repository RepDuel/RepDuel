// frontend/lib/features/auth/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/auth_provider.dart'; // Import auth provider
import '../../../core/providers/theme_provider.dart'; // Assuming themeProvider is correctly set up
import '../../../widgets/error_display.dart'; // For displaying errors
import '../../../widgets/loading_spinner.dart'; // For displaying loading state

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

  /// Handles the login submission process.
  Future<void> _submit() async {
    // Validate the form fields first.
    if (_formKey.currentState?.validate() ?? false) {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      // Attempt to log in using the AuthNotifier.
      // The login method now returns void and updates the provider state directly.
      // We'll watch the provider state to react to success/failure.
      await ref.read(authProvider.notifier).login(email, password);

      // No need for explicit 'success' boolean return if state is managed by provider.
      // The UI will react to state changes in the build method.
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch the authProvider to get the AsyncValue<AuthState>.
    final authStateAsyncValue = ref.watch(authProvider);
    final theme = ref.watch(themeProvider); // Assuming themeProvider is correctly set up

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        title: Text('Login', style: TextStyle(color: theme.primary)),
        backgroundColor: theme.background,
        foregroundColor: theme.primary,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        // Use .when() to handle the different states of authStateAsyncValue.
        child: authStateAsyncValue.when(
          loading: () => const Center(child: LoadingSpinner()), // Show spinner when loading
          error: (error, stackTrace) => Center( // Show error if auth fails
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ErrorDisplay(message: error.toString()), // Display the error message
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    // Retry login attempt or refresh auth state.
                    // For simplicity, let's assume re-entering credentials and submitting will work.
                    // If _initAuth failed, this might need a specific retry mechanism.
                    _submit(); // Trigger login again
                  },
                  child: const Text('Retry Login'),
                ),
              ],
            ),
          ),
          data: (authState) { // authState is the actual AuthState object here
            // Check if user is already logged in (e.g., session persisted)
            // If so, navigate away from login screen. This should ideally be handled by router guards.
            // However, a local check here can prevent showing login fields unnecessarily.
            if (authState.user != null && authState.token != null) {
              // Use WidgetsBinding.instance.addPostFrameCallback to ensure navigation happens after build
              WidgetsBinding.instance.addPostFrameCallback((_) {
                context.go('/profile'); // Redirect to profile if already logged in
              });
              // Return an empty container or loading spinner while redirecting.
              return const Center(child: LoadingSpinner()); 
            }

            // --- User is not logged in, show login form ---
            return Form(
              key: _formKey,
              child: Column(
                children: [
                  // Display login error from authState.error if it exists and is not loading.
                  // Note: AuthNotifier now uses AsyncValue.error, so check .hasError.
                  if (authState.error != null && authState.error!.isNotEmpty)
                    Padding( // Add padding around the error display
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: ErrorDisplay(message: authState.error!),
                    ),
                  
                  TextFormField(
                    controller: _emailController,
                    style: TextStyle(color: theme.primary),
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: TextStyle(color: theme.primary),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide(color: theme.primary.withOpacity(0.5)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide(color: theme.accent, width: 2.0),
                      ),
                    ),
                    validator: (value) => value!.isEmpty ? 'Please enter your email' : null,
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
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide(color: theme.primary.withOpacity(0.5)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide(color: theme.accent, width: 2.0),
                      ),
                    ),
                    validator: (value) => value!.isEmpty ? 'Please enter your password' : null,
                    onFieldSubmitted: (_) => _submit(), // Allow submission on keyboard action
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _submit, // Call the submit logic
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.accent,
                      foregroundColor: theme.background,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    child: const Text('Login'),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.go('/register'), // Use GoRouter for navigation
                    child: Text(
                      'Don\'t have an account? Sign up',
                      style: TextStyle(color: theme.primary.withOpacity(0.7)),
                    ),
                  ),
                ],
              ),
            ),
          },
        ),
      ),
    );
  }
}