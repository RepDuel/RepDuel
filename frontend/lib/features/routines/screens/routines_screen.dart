// frontend/lib/features/routines/screens/routines_screen.dart

import 'dart:async'; // For TimeoutException
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/env.dart';
import '../../../core/models/routine.dart';
import '../../../core/providers/auth_provider.dart'; // Import auth provider
import '../../../core/services/secure_storage_service.dart'; // Might not be directly needed for token access anymore
import '../widgets/add_routine_card.dart';
import '../widgets/routine_card.dart';

class RoutinesScreen extends ConsumerStatefulWidget {
  const RoutinesScreen({super.key});

  @override
  ConsumerState<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends ConsumerState<RoutinesScreen> {
  late Future<List<Routine>> _futureExercises; // Renamed to _futureExercises for clarity if it fetches exercises
  final Set<String> _deletingIds = {};

  static const _unauthorizedMessage = 'Unauthorized (401). Please log in.';
  static const _genericFailMessage = 'Failed to load routines';
  static const _kgToLbs = 2.20462;

  @override
  void initState() {
    super.initState();
    // Fetch routines when the widget is initialized. This will be called after
    // auth state is potentially resolved by the router or initial load.
    _futureExercises = _fetchRoutines(); 
  }

  // Fetch routines: This function now needs to safely access the token.
  Future<List<Routine>> _fetchRoutines() async {
    // Safely get token from authProvider
    final token = ref.read(authProvider).valueOrNull?.token;

    if (token == null) {
      // If no token, the request would be blocked by the interceptor,
      // but it's good practice to handle it here too to prevent unnecessary calls.
      throw Exception(_unauthorizedMessage); 
    }

    final response = await http.get(
      Uri.parse('${Env.baseUrl}/api/v1/routines/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token', // Token is now guaranteed non-null here
      },
    ).timeout(const Duration(seconds: 10)); // Added timeout for robustness

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((json) => Routine.fromJson(json)).toList();
    } else if (response.statusCode == 401) {
      throw Exception(_unauthorizedMessage);
    } else {
      throw Exception('$_genericFailMessage (HTTP ${response.statusCode})');
    }
  }

  Future<void> _refresh() async {
    // Re-fetch routines. This should be called when auth state is ready.
    setState(() {
      _futureExercises = _fetchRoutines();
    });
    await _futureExercises; // Wait for fetch to complete
  }

  void _onAddRoutinePressed(List<Routine> routines) async {
    // Safely access user and token
    final authStateData = ref.read(authProvider).valueOrNull;
    final user = authStateData?.user;
    // final token = authStateData?.token; // Token not needed for this check, but user is.

    if (user == null) {
      // If user is null, they are not authenticated. Prompt login.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to create routines.")),
      );
      GoRouter.of(context).go('/login');
      return;
    }

    final isFree = user.subscriptionLevel == null || user.subscriptionLevel == 'free';
    // Count routines belonging to the current user
    final hasReachedLimit = routines.where((r) => r.userId == user.id).length >= 3;

    if (isFree && hasReachedLimit) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Upgrade Required'),
          content: const Text(
              'Free users can only create up to 3 custom routines. Upgrade to unlock more.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // Use GoRouter for navigation
                GoRouter.of(context).push('/subscribe'); 
              },
              child: const Text('Upgrade'),
            ),
          ],
        ),
      );
      return;
    }

    // Navigate to CustomRoutineScreen using GoRouter
    final changed = await context.push<bool>('/routines/custom'); // Assuming '/routines/custom' is the correct route
    if (changed == true && mounted) _refresh(); // Refresh if data changed
  }

  Future<void> _confirmAndDeleteRoutine(Routine routine) async {
    if (_deletingIds.contains(routine.id)) return; // Prevent concurrent deletion

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete routine?'),
        content: Text(
            'Are you sure you want to delete "${routine.name}"?\nThis cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return; // User cancelled

    await _deleteRoutine(routine.id);
  }

  Future<void> _deleteRoutine(String routineId) async {
    // Safely get token
    final token = ref.read(authProvider).valueOrNull?.token;

    if (token == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to delete routines.')),
      );
      GoRouter.of(context).go('/login'); // Redirect to login
      return;
    }

    setState(() {
      _deletingIds.add(routineId);
    });

    try {
      final res = await http.delete(
        Uri.parse('${Env.baseUrl}/api/v1/routines/$routineId'),
        headers: {'Authorization': 'Bearer $token'}, // Use the safely retrieved token
      );

      if (!mounted) return;

      if (res.statusCode == 204) { // Success, no content
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Routine deleted.')));
        await _refresh(); // Refresh the list
      } else if (res.statusCode == 401) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session expired. Please log in again.')),
        );
        GoRouter.of(context).go('/login'); // Redirect to login
      } else if (res.statusCode == 403) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not allowed to delete this routine.')),
        );
      } else if (res.statusCode == 404) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Routine not found (maybe already deleted).')),
        );
        await _refresh(); // Refresh to reflect potential deletion
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed (HTTP ${res.statusCode}).')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _deletingIds.remove(routineId); // Remove from deleting set
        });
      }
    }
  }

  Future<void> _editRoutine(Routine routine) async {
    // Use GoRouter for named navigation with extra data
    final changed = await context.pushNamed<bool>('editRoutine', extra: routine);
    if (changed == true && mounted) _refresh(); // Refresh if routine was changed
  }

  Widget _buildRoutineTile(Routine routine, String? currentUserId) {
    final isDeleting = _deletingIds.contains(routine.id);
    // Check ownership using routine.userId and currentUserId
    final canEditDelete = routine.userId != null && routine.userId == currentUserId;

    return Stack(
      children: [
        GestureDetector(
          onTap: () async {
            // Navigate using GoRouter, passing the routine object as extra
            final changed = await context.pushNamed<bool>('playRoutine', extra: routine);
            if (changed == true && mounted) _refresh(); // Refresh if routine was played and state changed
          },
          child: RoutineCard(
            name: routine.name,
            // Provide a fallback image URL
            imageUrl: routine.imageUrl ?? 'https://via.placeholder.com/150', 
            duration: '${routine.totalDurationMinutes} min',
            difficultyLevel: 2, // Assuming difficulty is static or derived elsewhere
          ),
        ),
        // Edit/Delete options only for the current user's routines
        if (canEditDelete)
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.transparent,
              child: PopupMenuButton<String>(
                tooltip: 'Options',
                onSelected: (value) {
                  if (value == 'edit') {
                    _editRoutine(routine);
                  } else if (value == 'delete') {
                    _confirmAndDeleteRoutine(routine);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [Icon(Icons.edit), SizedBox(width: 8), Text('Edit')])),
                  PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [Icon(Icons.delete_outline, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
                ],
                icon: const Icon(Icons.more_vert, color: Colors.white70),
              ),
            ),
          ),
        // Show loading indicator while deleting
        if (isDeleting)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(102),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch the auth provider to get AsyncValue<AuthState>
    final authStateAsyncValue = ref.watch(authProvider);

    // Use .when() to handle loading, error, and data states for authentication.
    return authStateAsyncValue.when(
      loading: () => const Scaffold( // Display loading screen while auth state is loading
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => Scaffold( // Display error message if auth fails to load
        backgroundColor: Colors.black,
        body: Center(child: Text('Auth Error: $error', style: const TextStyle(color: Colors.red))),
      ),
      data: (authState) { // authState is the actual AuthState object here
        final user = authState.user;
        final token = authState.token; // Token is needed for fetching and deleting

        // If user or token is null, it means the user is not authenticated.
        // The router should handle redirecting to login. We'll show a message here.
        if (user == null || token == null) {
          // This case should ideally be handled by the router redirecting to login.
          // As a fallback, we show a message prompting login.
          return Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Please log in to view your routines.', style: TextStyle(color: Colors.white, fontSize: 16)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => GoRouter.of(context).go('/login'), // Use GoRouter for navigation
                    child: const Text('Go to Login'),
                  ),
                ],
              ),
            ),
          );
        }

        // --- User is logged in and data is available ---
        // Use FutureBuilder to fetch and display routines once auth is ready.
        return FutureBuilder<List<Routine>>(
          future: _futureExercises, // Use the future initialized in initState
          builder: (context, snapshot) {
            // Loading state for exercises
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // Error state for exercises
            if (snapshot.hasError) {
              final message = snapshot.error?.toString() ?? _genericFailMessage;
              final isUnauthorized = message.contains('401');

              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message,
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    if (isUnauthorized)
                      ElevatedButton(
                        onPressed: () => GoRouter.of(context).go('/login'), // Redirect on unauthorized
                        child: const Text('Login'),
                      )
                    else
                      ElevatedButton(
                        onPressed: _refresh, // Retry fetching exercises
                        child: const Text('Retry'),
                      ),
                  ],
                ),
              );
            }

            // Data ready for exercises
            final routines = snapshot.data ?? <Routine>[];

            return RefreshIndicator(
              onRefresh: _refresh, // Refresh the list of routines
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: routines.length + 1, // +1 for the "Add Routine" card
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: (MediaQuery.of(context).size.width ~/ 250).clamp(2, 6), // Responsive grid count
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.6, // Adjust aspect ratio as needed
                ),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    // The first item is the "Add Routine" card
                    return AddRoutineCard(onPressed: () => _onAddRoutinePressed(routines));
                  }
                  // For subsequent items, build RoutineCard
                  final routine = routines[index - 1];
                  return _buildRoutineTile(routine, user.id); // Pass current user ID
                },
              ),
            );
          },
        );
      },
    );
  }
}