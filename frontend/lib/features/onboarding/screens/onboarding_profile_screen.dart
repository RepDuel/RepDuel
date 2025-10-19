// frontend/lib/features/onboarding/screens/onboarding_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/user.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../widgets/loading_spinner.dart';

class OnboardingProfileScreen extends ConsumerStatefulWidget {
  const OnboardingProfileScreen({super.key});

  @override
  ConsumerState<OnboardingProfileScreen> createState() => _OnboardingProfileScreenState();
}

class _OnboardingProfileScreenState extends ConsumerState<OnboardingProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();

  final List<String> _genderOptions = const [
    'Female',
    'Male',
    'Non-binary',
    'Prefer not to say',
  ];

  static const double _kgToLbs = 2.2046226218;

  bool _isSaving = false;
  String? _selectedGender;
  String _preferredUnit = 'kg';

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).valueOrNull?.user;
    _hydrateFromUser(user);
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  void _hydrateFromUser(User? user) {
    if (user == null) return;
    _selectedGender = user.gender;
    _preferredUnit = user.preferredUnit;
    if (user.weight != null) {
      final displayWeight = _preferredUnit == 'kg'
          ? user.weight!
          : user.weight! * _kgToLbs;
      _weightController.text = displayWeight.toStringAsFixed(1);
    }
  }

  void _updateWeightForUnit(String newUnit) {
    final text = _weightController.text.trim();
    final parsed = double.tryParse(text);
    if (parsed == null) return;

    double converted;
    if (newUnit == 'kg' && _preferredUnit == 'lbs') {
      converted = parsed / _kgToLbs;
    } else if (newUnit == 'lbs' && _preferredUnit == 'kg') {
      converted = parsed * _kgToLbs;
    } else {
      converted = parsed;
    }
    _weightController.text = converted.toStringAsFixed(1);
  }

  String? _validateWeight(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Optional field
    }
    final parsed = double.tryParse(value.trim());
    if (parsed == null || parsed <= 0) {
      return 'Enter a positive number';
    }
    if (parsed > 500) {
      return 'That looks too high — double check the value';
    }
    return null;
  }

  Future<void> _completeOnboarding() async {
    if (_isSaving) return;
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isSaving = true);

    final inputWeight = _weightController.text.trim();
    final parsedWeight = inputWeight.isEmpty ? null : double.tryParse(inputWeight);
    final weightInKg = parsedWeight == null
        ? null
        : (_preferredUnit == 'kg' ? parsedWeight : parsedWeight / _kgToLbs);
    final weightMultiplier = _preferredUnit == 'kg' ? 1.0 : _kgToLbs;

    final success = await ref.read(authProvider.notifier).updateUser(
          gender: _selectedGender,
          weight: weightInKg,
          weightMultiplier: weightMultiplier,
          preferredUnit: _preferredUnit,
        );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved!'),
          backgroundColor: Colors.green,
        ),
      );
      context.go('/routines');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save profile. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isSaving = false);
    }
  }

  void _skipOnboarding() {
    context.go('/routines');
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.valueOrNull?.user;

    if (authState.isLoading && user == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: LoadingSpinner()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Let\'s personalize things'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _skipOnboarding,
            child: const Text('Skip', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                const Text(
                  'We use a few details to tailor training plans, leaderboards, and recommendations for you.',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 32),

                const Text(
                  'Gender',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedGender,
                  dropdownColor: const Color(0xFF1C1C1C),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF1C1C1C),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  hint: const Text('Select an option', style: TextStyle(color: Colors.white54)),
                  items: _genderOptions
                      .map(
                        (g) => DropdownMenuItem<String>(
                          value: g,
                          child: Text(g),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _selectedGender = value),
                ),

                const SizedBox(height: 28),
                const Text(
                  'Body weight',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _weightController,
                        style: const TextStyle(color: Colors.white),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          hintText: 'e.g. 70',
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: const Color(0xFF1C1C1C),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: _validateWeight,
                      ),
                    ),
                    const SizedBox(width: 16),
                    ToggleButtons(
                      isSelected: [
                        _preferredUnit == 'kg',
                        _preferredUnit == 'lbs',
                      ],
                      color: Colors.white70,
                      selectedColor: Colors.black,
                      fillColor: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      borderColor: Colors.white24,
                      selectedBorderColor: Colors.white,
                      onPressed: (index) {
                        final newUnit = index == 0 ? 'kg' : 'lbs';
                        if (newUnit == _preferredUnit) return;
                        setState(() {
                          _updateWeightForUnit(newUnit);
                          _preferredUnit = newUnit;
                        });
                      },
                      children: const [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('kg'),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('lbs'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Optional, but helps us calibrate recommendations and leaderboards.',
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                ),

                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _completeOnboarding,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSaving
                        ? const LoadingSpinner(size: 22)
                        : const Text(
                            'Save and continue',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: _isSaving ? null : _skipOnboarding,
                    child: const Text(
                      'Maybe later',
                      style: TextStyle(color: Colors.white54),
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
