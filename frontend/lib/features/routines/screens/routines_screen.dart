import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';

import '../../../widgets/main_bottom_nav_bar.dart';
import '../widgets/routine_card.dart';
import '../widgets/add_routine_card.dart';
import 'routine_play_screen.dart';
import 'custom_routine_screen.dart';
import '../../../core/config/env.dart';
import '../../../core/models/routine.dart';
import '../../../core/services/secure_storage_service.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../theme/app_theme.dart';

class RoutinesScreen extends ConsumerStatefulWidget {
  const RoutinesScreen({super.key});

  @override
  ConsumerState<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends ConsumerState<RoutinesScreen> {
  late Future<List<Routine>> _future;
  final Set<String> _deletingIds = {};

  static const _unauthorizedMessage = 'Unauthorized (401). Please log in.';
  static const _genericFailMessage = 'Failed to load routines';

  @override
  void initState() {
    super.initState();
    _future = _fetchRoutines();
  }

  Future<List<Routine>> _fetchRoutines() async {
    final storage = SecureStorageService();
    final token = await storage.readToken();

    final response = await http.get(
      Uri.parse('${Env.baseUrl}/api/v1/routines/'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    );

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
    setState(() {
      _future = _fetchRoutines();
    });
    await _future;
  }

  void _onAddRoutinePressed() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CustomRoutineScreen()),
    ).then((changed) {
      if (changed == true && mounted) _refresh();
    });
  }

  Future<void> _confirmAndDeleteRoutine(Routine routine) async {
    if (_deletingIds.contains(routine.id)) return;

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
                backgroundColor: AppTheme.errorColor, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _deleteRoutine(routine.id);
  }

  Future<void> _deleteRoutine(String routineId) async {
    final storage = SecureStorageService();
    final token = await storage.readToken();

    if (token == null || token.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('You must be logged in to delete routines.')),
      );
      context.go('/login');
      return;
    }

    setState(() {
      _deletingIds.add(routineId);
    });

    try {
      final res = await http.delete(
        Uri.parse('${Env.baseUrl}/api/v1/routines/$routineId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (!mounted) return;

      if (res.statusCode == 204) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Routine deleted.')));
        await _refresh();
      } else if (res.statusCode == 401) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Session expired. Please log in again.')),
        );
        context.go('/login');
      } else if (res.statusCode == 403) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not allowed to delete this routine.')),
        );
      } else if (res.statusCode == 404) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Routine not found (maybe already deleted).')),
        );
        await _refresh();
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
          _deletingIds.remove(routineId);
        });
      }
    }
  }

  Future<void> _editRoutine(Routine routine) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => CustomRoutineScreen.edit(initial: routine)),
    );
    if (changed == true && mounted) _refresh();
  }

  Widget _buildRoutineTile(Routine routine, String? currentUserId) {
    final isDeleting = _deletingIds.contains(routine.id);
    final canEditDelete =
        routine.userId != null && routine.userId == currentUserId;

    return Stack(
      children: [
        GestureDetector(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => RoutinePlayScreen(routine: routine)),
            );
            if (!mounted) return;
            _refresh();
          },
          child: RoutineCard(
            name: routine.name,
            imageUrl: routine.imageUrl ??
                'https://media.istockphoto.com/id/1147544807/vector/thumbnail-image-vector-graphic.jpg?s=612x612&w=0&k=20&c=rnCKVbdxqkjlcs3xH87-9gocETqpspHFXu5dIGB4wuM=',
            duration: '${routine.totalDurationMinutes} min',
            difficultyLevel: 2,
          ),
        ),
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
                      child: Row(children: [
                        Icon(Icons.edit),
                        SizedBox(width: 8),
                        Text('Edit')
                      ])),
                  PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete_outline, color: AppTheme.errorColor),
                        SizedBox(width: 8),
                        Text('Delete')
                      ])),
                ],
                icon: Icon(Icons.more_vert, color: Theme.of(context).colorScheme.onTertiary),
              ),
            ),
          ),
        if (isDeleting)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor.withAlpha(102),
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
    final currentUser = ref.watch(authStateProvider).user;
    final currentUserId = currentUser?.id;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Routines'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        centerTitle: true,
        elevation: 0,
        actions: const [],
      ),
      body: FutureBuilder<List<Routine>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            final message = snapshot.error?.toString() ?? _genericFailMessage;
            final isUnauthorized = message.contains('401');

            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(message,
                      style: theme.textTheme.bodyLarge,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  if (isUnauthorized)
                    ElevatedButton(
                        onPressed: () => context.go('/login'),
                        child: const Text('Login'))
                  else
                    ElevatedButton(
                        onPressed: _refresh, child: const Text('Retry')),
                ],
              ),
            );
          }

          final routines = snapshot.data ?? <Routine>[];

          return RefreshIndicator(
            onRefresh: _refresh,
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: routines.length + 1,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount:
                    (MediaQuery.of(context).size.width ~/ 250).clamp(2, 6),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.6,
              ),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return AddRoutineCard(
                      onPressed: _onAddRoutinePressed);
                }
                final routine = routines[index - 1];
                return _buildRoutineTile(routine, currentUserId);
              },
            ),
          );
        },
      ),
      bottomNavigationBar: MainBottomNavBar(
        currentIndex: 2,
        onTap: (index) {
          switch (index) {
            case 0:
              context.go('/normal');
              break;
            case 1:
              context.go('/ranked');
              break;
            case 2:
              // Current screen, do nothing.
              break;
            case 3:
              context.go('/profile');
              break;
          }
        },
      ),
    );
  }
}