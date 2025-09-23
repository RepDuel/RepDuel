// frontend/lib/features/routines/screens/routine_import_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:repduel/widgets/loading_spinner.dart';

import '../../../core/providers/api_providers.dart';
import '../../../core/providers/auth_provider.dart';
import '../screens/routines_screen.dart' show routinesProvider;

/// Handles opening a shared routine link by cloning it into the
/// current user's account, then redirecting back to the routines tab.
class RoutineImportScreen extends ConsumerStatefulWidget {
  const RoutineImportScreen({super.key, required this.routineId});

  final String routineId;

  @override
  ConsumerState<RoutineImportScreen> createState() =>
      _RoutineImportScreenState();
}

class _RoutineImportScreenState extends ConsumerState<RoutineImportScreen> {
  String? _error;
  bool _isImporting = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _importRoutine());
  }

  Future<void> _importRoutine() async {
    final messenger = ScaffoldMessenger.of(context);
    final authState = ref.read(authProvider);
    final user = authState.valueOrNull?.user;

    if (user == null) {
      setState(() {
        _isImporting = false;
        _error = 'Please log in to save shared routines.';
      });
      return;
    }

    try {
      final client = ref.read(privateHttpClientProvider);
      final sourceRes = await client.get('/routines/${widget.routineId}');

      if (sourceRes.statusCode != 200) {
        throw Exception('Routine not found (status ${sourceRes.statusCode}).');
      }

      final data = Map<String, dynamic>.from(sourceRes.data as Map);
      final ownerId = data['user_id']?.toString();
      if (ownerId != null && ownerId == user.id.toString()) {
        if (!mounted) return;
        context.go('/routines');
        messenger.showSnackBar(
          const SnackBar(
            content: Text('You already have this routine in your library.'),
          ),
        );
        return;
      }

      final scenariosJson = (data['scenarios'] as List<dynamic>? ?? [])
          .map((raw) => Map<String, dynamic>.from(raw as Map))
          .map((scenario) => {
                'scenario_id': scenario['scenario_id'] ?? scenario['id'],
                'name': scenario['name'] ?? 'Exercise',
                'sets': (scenario['sets'] as num?)?.toInt() ?? 0,
                'reps': (scenario['reps'] as num?)?.toInt() ?? 0,
              })
          .toList();

      final payload = {
        'name': data['name'] ?? 'Shared Routine',
        'image_url': data['image_url'],
        'scenarios': scenariosJson,
      };

      final createRes = await client.post('/routines/', data: payload);
      if (createRes.statusCode != 201 && createRes.statusCode != 200) {
        final detail =
            (createRes.data is Map && (createRes.data as Map)['detail'] != null)
                ? (createRes.data as Map)['detail'].toString()
                : 'Failed to save routine (status ${createRes.statusCode}).';
        throw Exception(detail);
      }

      final createdData = Map<String, dynamic>.from(createRes.data as Map);
      final createdName = createdData['name'] ?? payload['name'];

      ref.invalidate(routinesProvider);

      if (!mounted) return;

      context.go('/routines');
      messenger.showSnackBar(
        SnackBar(
          content: Text('Added "$createdName" to your routines.'),
        ),
      );
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _isImporting = false;
        _error = err.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _isImporting
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LoadingSpinner(),
                    SizedBox(height: 16),
                    Text(
                      'Adding shared routine…',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.redAccent, size: 40),
                    const SizedBox(height: 16),
                    Text(
                      _error ??
                          'Something went wrong while importing this routine.',
                      style: const TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => context.go('/routines'),
                      child: const Text('Back to routines'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
