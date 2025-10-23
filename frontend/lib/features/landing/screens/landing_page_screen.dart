// frontend/lib/features/landing/screens/landing_page_screen.dart

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class LandingPageScreen extends StatefulWidget {
  const LandingPageScreen({super.key});

  @override
  State<LandingPageScreen> createState() => _LandingPageScreenState();
}

class _LandingPageScreenState extends State<LandingPageScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _aboutKey = GlobalKey();
  final GlobalKey _technologyKey = GlobalKey();
  final GlobalKey _careersKey = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollTo(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) {
      return;
    }

    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeInOut,
      alignment: 0.1,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final landingTheme = theme.copyWith(
      textTheme: _LandingTypography.textTheme(theme.textTheme),
    );

    return Theme(
      data: landingTheme,
      child: Scaffold(
        backgroundColor: _Palette.background,
        body: Stack(
          children: [
            const _LandingBackground(),
            SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _LandingNavigationBar(
                    onNavigateToAbout: () => _scrollTo(_aboutKey),
                    onNavigateToTechnology: () => _scrollTo(_technologyKey),
                    onNavigateToCareers: () => _scrollTo(_careersKey),
                  ),
                  _HeroSection(
                    onPrimaryTap: () => context.go('/register'),
                    onSecondaryTap: () => context.go('/ranked'),
                    onLearnMoreTap: () => _scrollTo(_aboutKey),
                  ),
                  const _SectionDivider(),
                  _AboutSection(key: _aboutKey),
                  _TechnologySection(key: _technologyKey),
                  _CultureSection(key: _careersKey),
                  _CallToActionSection(
                    onJoinTap: () => context.go('/register'),
                    onContactTap: () => context.go('/login'),
                  ),
                  const _LandingFooter(),
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 32),
                ],
              ),
            ),
            Positioned(
              right: 24,
              bottom: 24 + MediaQuery.of(context).padding.bottom,
              child: _FloatingSupportButton(
                onTap: () => _scrollTo(_careersKey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LandingBackground extends StatelessWidget {
  const _LandingBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF04070B), Color(0xFF080F1C)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: const [
            _BlurredOrb(
              diameter: 420,
              color: Color(0x553A7CFF),
              offset: Offset(-120, -40),
            ),
            _BlurredOrb(
              diameter: 520,
              color: Color(0x3344C3FF),
              offset: Offset(220, 360),
            ),
            _BlurredOrb(
              diameter: 360,
              color: Color(0x3369FFE4),
              offset: Offset(-200, 680),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlurredOrb extends StatelessWidget {
  const _BlurredOrb({
    required this.diameter,
    required this.color,
    required this.offset,
  });

  final double diameter;
  final Color color;
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: offset.dx,
      top: offset.dy,
      child: IgnorePointer(
        child: Container(
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color, color.withOpacity(0)],
            ),
          ),
        ),
      ),
    );
  }
}

class _LandingNavigationBar extends StatelessWidget {
  const _LandingNavigationBar({
    required this.onNavigateToAbout,
    required this.onNavigateToTechnology,
    required this.onNavigateToCareers,
  });

  final VoidCallback onNavigateToAbout;
  final VoidCallback onNavigateToTechnology;
  final VoidCallback onNavigateToCareers;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 900;
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
                borderRadius: BorderRadius.circular(28),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 20 : 36,
                vertical: 18,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      _BrandMark(isCompact: isCompact),
                      const Spacer(),
                      if (!isCompact)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _NavButton(
                              label: 'About',
                              onTap: onNavigateToAbout,
                            ),
                            const SizedBox(width: 16),
                            _NavButton(
                              label: 'Technology',
                              onTap: onNavigateToTechnology,
                            ),
                            const SizedBox(width: 16),
                            _NavButton(
                              label: 'Careers',
                              onTap: onNavigateToCareers,
                            ),
                          ],
                        ),
                      const SizedBox(width: 20),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withOpacity(0.3)),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                        ),
                        onPressed: () => context.go('/login'),
                        child: Text(
                          'Log in',
                          style: textTheme.labelLarge!.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: _Palette.electricBlue,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 26,
                            vertical: 14,
                          ),
                        ),
                        onPressed: () => context.go('/register'),
                        child: Text(
                          'Join the platform',
                          style: textTheme.labelLarge!.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (isCompact)
                    Padding(
                      padding: const EdgeInsets.only(top: 18),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 16,
                        runSpacing: 12,
                        children: [
                          _NavButton(
                            label: 'About',
                            onTap: onNavigateToAbout,
                          ),
                          _NavButton(
                            label: 'Technology',
                            onTap: onNavigateToTechnology,
                          ),
                          _NavButton(
                            label: 'Careers',
                            onTap: onNavigateToCareers,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.isCompact});

  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: isCompact ? 36 : 44,
          height: isCompact ? 36 : 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4C7CFF), Color(0xFF4AD7F5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4C7CFF).withOpacity(0.45),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            'R',
            style: textTheme.titleMedium!.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: isCompact ? 18 : 20,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'RepDuel',
          style: textTheme.titleLarge!.copyWith(
            color: Colors.white,
            fontSize: isCompact ? 20 : 24,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge!.copyWith(
            color: Colors.white.withOpacity(0.86),
            fontSize: 15,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.onPrimaryTap,
    required this.onSecondaryTap,
    required this.onLearnMoreTap,
  });

  final VoidCallback onPrimaryTap;
  final VoidCallback onSecondaryTap;
  final VoidCallback onLearnMoreTap;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 1024;
    final textTheme = Theme.of(context).textTheme;

    return _SectionContainer(
      padding: EdgeInsets.fromLTRB(24, isCompact ? 48 : 72, 24, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: const [
              _Pill(text: 'Strength training workspace'),
              _Pill(text: 'Built for coaches and athletes'),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            'Clarity for every session.',
            style: textTheme.displaySmall!.copyWith(
              color: Colors.white,
              fontSize: isCompact ? 38 : 54,
              fontWeight: FontWeight.w600,
              height: 1.1,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'RepDuel is building a collaborative platform for strength communities. '
            'Plan training cycles, log sessions, and review progress together without juggling spreadsheets.',
            style: textTheme.bodyLarge!.copyWith(
              color: Colors.white.withOpacity(0.78),
              fontSize: isCompact ? 16 : 18,
            ),
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _Palette.electricBlue,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 18,
                  ),
                ),
                onPressed: onPrimaryTap,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Start competing',
                      style: textTheme.labelLarge!.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withOpacity(0.32)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 26,
                    vertical: 18,
                  ),
                ),
                onPressed: onSecondaryTap,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bar_chart_rounded, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'View leaderboards',
                      style: textTheme.labelLarge!.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 48),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: const [
              _StatCard(
                value: 'Collaboration',
                label: 'Shared planning and feedback keep squads aligned before every lift.',
              ),
              _StatCard(
                value: 'Accountability',
                label: 'Track intent and completion so athletes and coaches stay on the same page.',
              ),
              _StatCard(
                value: 'Insight',
                label: 'Export training history and surface trends without extra data wrangling.',
              ),
            ],
          ),
          const SizedBox(height: 40),
          TextButton.icon(
            onPressed: onLearnMoreTap,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70),
            label: Text(
              'Discover how teams scale with RepDuel',
              style: textTheme.labelLarge!.copyWith(
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
        color: Colors.white.withOpacity(0.04),
      ),
      child: Text(
        text,
        style: textTheme.labelSmall!.copyWith(
          color: Colors.white.withOpacity(0.8),
          fontSize: 13,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 600;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: isCompact ? double.infinity : 250,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withOpacity(0.03),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: textTheme.headlineSmall!.copyWith(
              color: _Palette.electricBlue,
              fontSize: 26,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: textTheme.bodyMedium!.copyWith(
              color: Colors.white.withOpacity(0.7),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 960;
    final textTheme = Theme.of(context).textTheme;

    return _SectionContainer(
      padding: const EdgeInsets.fromLTRB(24, 64, 24, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Built for strength communities.',
            style: textTheme.headlineMedium!.copyWith(
              color: Colors.white,
              fontSize: isCompact ? 28 : 36,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'RepDuel brings scheduling, feedback, and leaderboards into a single workspace so teams can stay connected '
            'wherever they train. We focus on clarity, dependable data, and helping coaches support every athlete.',
            style: textTheme.bodyLarge!.copyWith(
              color: Colors.white.withOpacity(0.74),
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 42),
          Wrap(
            spacing: 24,
            runSpacing: 24,
            children: const [
              _PrincipleCard(
                title: 'Clarity first',
                copy:
                    'Structure training blocks with shared templates and context for every athlete.',
              ),
              _PrincipleCard(
                title: 'Secure by design',
                copy:
                    'Role-based permissions and managed infrastructure protect athlete information.',
              ),
              _PrincipleCard(
                title: 'Support that listens',
                copy:
                    'We collaborate with partners to prioritise the workflows they rely on every day.',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PrincipleCard extends StatelessWidget {
  const _PrincipleCard({
    required this.title,
    required this.copy,
  });

  final String title;
  final String copy;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 960;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: isCompact ? double.infinity : 320,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withOpacity(0.02),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: _Palette.electricBlue,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: textTheme.titleMedium!.copyWith(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            copy,
            style: textTheme.bodyMedium!.copyWith(
              color: Colors.white.withOpacity(0.68),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _TechnologySection extends StatelessWidget {
  const _TechnologySection({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 1080;
    final textTheme = Theme.of(context).textTheme;

    return _SectionContainer(
      padding: const EdgeInsets.fromLTRB(24, 72, 24, 60),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Technology that keeps teams in sync.',
                      style: textTheme.headlineMedium!.copyWith(
                        color: Colors.white,
                        fontSize: isCompact ? 28 : 34,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Our tools capture reps, loads, and notes in real time so staff can make confident decisions. '
                      'We emphasise reliability, transparent data, and easy exports for the partners who trust us.',
                      style: textTheme.bodyLarge!.copyWith(
                        color: Colors.white.withOpacity(0.74),
                        fontSize: 16.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isCompact) const SizedBox(width: 48),
              if (!isCompact)
                Expanded(
                  child: _GradientPanel(
                    title: 'Command Center',
                    body:
                        'Plan, monitor, and adjust sessions from a single workspace designed for strength professionals.',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 36),
          Wrap(
            spacing: 24,
            runSpacing: 24,
            children: const [
              _CapabilityCard(
                icon: Icons.monitor_heart_rounded,
                title: 'Shared session design',
                description:
                    'Build programmes collaboratively and push updates instantly to your roster.',
              ),
              _CapabilityCard(
                icon: Icons.auto_graph_rounded,
                title: 'Live leaderboards',
                description:
                    'Highlight standout efforts and keep athletes engaged throughout each cycle.',
              ),
              _CapabilityCard(
                icon: Icons.security_rounded,
                title: 'Data ownership',
                description:
                    'Download results and history whenever you need to review or share progress.',
              ),
              _CapabilityCard(
                icon: Icons.hub_rounded,
                title: 'Open integrations',
                description:
                    'Start with clean exports today while we expand direct connections with partner tools.',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GradientPanel extends StatelessWidget {
  const _GradientPanel({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          colors: [Color(0x1A4AD7F5), Color(0x334C7CFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: textTheme.titleLarge!.copyWith(
              color: Colors.white,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            body,
            style: textTheme.bodyMedium!.copyWith(
              color: Colors.white.withOpacity(0.75),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _CapabilityCard extends StatelessWidget {
  const _CapabilityCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 960;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: isCompact ? double.infinity : 280,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withOpacity(0.03),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF4C7CFF), Color(0xFF4AD7F5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(icon, color: Colors.black87),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: textTheme.titleMedium!.copyWith(
              color: Colors.white,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: textTheme.bodyMedium!.copyWith(
              color: Colors.white.withOpacity(0.72),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _CultureSection extends StatelessWidget {
  const _CultureSection({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 900;
    final textTheme = Theme.of(context).textTheme;

    return _SectionContainer(
      padding: const EdgeInsets.fromLTRB(24, 72, 24, 72),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 24 : 36,
              vertical: isCompact ? 32 : 40,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                colors: [Color(0xFF0C1527), Color(0xFF111B33)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 32,
                  offset: const Offset(0, 24),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A team focused on athletes and coaches.',
                  style: textTheme.headlineMedium!.copyWith(
                    color: Colors.white,
                    fontSize: isCompact ? 26 : 32,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'We are a small, remote-first group of engineers, coaches, and designers working with early partners to shape '
                  'RepDuel. We value curiosity, clear communication, and thoughtful iteration that supports long-term progress.',
                  style: textTheme.bodyLarge!.copyWith(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 28),
                Wrap(
                  spacing: 24,
                  runSpacing: 16,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: const [
                    _CultureHighlight(
                      title: 'Remote-first collaboration',
                      subtitle: 'Work flexibly across time zones with intentional overlap.',
                    ),
                    _CultureHighlight(
                      title: 'Continuous learning',
                      subtitle: 'Budget for courses, certifications, and knowledge sharing.',
                    ),
                    _CultureHighlight(
                      title: 'High-trust teams',
                      subtitle: 'Define goals together and ship improvements with accountability.',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CultureHighlight extends StatelessWidget {
  const _CultureHighlight({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: textTheme.titleSmall!.copyWith(
              color: _Palette.electricBlue,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: textTheme.bodyMedium!.copyWith(
              color: Colors.white.withOpacity(0.72),
            ),
          ),
        ],
      ),
    );
  }
}

class _CallToActionSection extends StatelessWidget {
  const _CallToActionSection({
    required this.onJoinTap,
    required this.onContactTap,
  });

  final VoidCallback onJoinTap;
  final VoidCallback onContactTap;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 880;
    final textTheme = Theme.of(context).textTheme;

    return _SectionContainer(
      padding: const EdgeInsets.fromLTRB(24, 72, 24, 72),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 28 : 48,
          vertical: isCompact ? 38 : 48,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: const LinearGradient(
            colors: [Color(0xFF13223D), Color(0xFF1A2C4F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.38),
              blurRadius: 40,
              offset: const Offset(0, 26),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isCompact ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Text(
              'Bring RepDuel to your organisation',
              style: textTheme.headlineMedium!.copyWith(
                color: Colors.white,
                fontSize: isCompact ? 28 : 34,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Schedule a walkthrough with our team. We will learn about your training environment and map a rollout that matches your timeline.',
              textAlign: isCompact ? TextAlign.start : TextAlign.center,
              style: textTheme.bodyLarge!.copyWith(
                color: Colors.white.withOpacity(0.76),
              ),
            ),
            const SizedBox(height: 30),
            Wrap(
              alignment:
                  isCompact ? WrapAlignment.start : WrapAlignment.center,
              spacing: 18,
              runSpacing: 12,
              children: [
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 18,
                    ),
                  ),
                onPressed: onJoinTap,
                child: Text(
                  'Launch RepDuel',
                  style: textTheme.labelLarge!.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withOpacity(0.32)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 18,
                    ),
                  ),
                onPressed: onContactTap,
                child: Text(
                  'Contact our team',
                  style: textTheme.labelLarge!.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          ],
        ),
      ),
    );
  }
}

class _LandingFooter extends StatelessWidget {
  const _LandingFooter();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bodyStyle = textTheme.bodySmall!.copyWith(
      color: Colors.white.withOpacity(0.62),
      fontSize: 13,
    );
    final linkStyle = textTheme.labelLarge!.copyWith(
      color: Colors.white.withOpacity(0.78),
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );

    return _SectionContainer(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(color: Color(0x22FFFFFF)),
          const SizedBox(height: 28),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RepDuel',
                      style: textTheme.titleLarge!.copyWith(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Software for strength teams to plan, track, and celebrate training.',
                      style: bodyStyle,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      children: [
                        _SocialLinkButton(
                          label: 'X (Twitter)',
                          uri: _SocialLinks.x,
                          child: Text(
                            '𝕏',
                            style: textTheme.titleSmall!.copyWith(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        _SocialLinkButton(
                          label: 'Instagram',
                          uri: _SocialLinks.instagram,
                          child: const Icon(
                            Icons.camera_alt_outlined,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 32),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: Text('Client login', style: linkStyle),
                  ),
                  TextButton(
                    onPressed: () => context.go('/register'),
                    child: Text('Create account', style: linkStyle),
                  ),
                  TextButton(
                    onPressed: () => context.go('/ranked'),
                    child: Text('Leaderboards', style: linkStyle),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            '© ${DateTime.now().year} RepDuel LLC. All rights reserved.',
            style: bodyStyle,
          ),
        ],
      ),
    );
  }
}

class _SocialLinkButton extends StatelessWidget {
  const _SocialLinkButton({
    required this.label,
    required this.uri,
    required this.child,
  });

  final String label;
  final Uri uri;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () async {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            child: Ink(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.18)),
              ),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingSupportButton extends StatelessWidget {
  const _FloatingSupportButton({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      onPressed: onTap,
      icon: const Icon(Icons.people_alt_rounded),
      label: Text(
        'Join our teams',
        style: Theme.of(context).textTheme.labelLarge!.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: Colors.black,
        ),
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Divider(
        height: 1,
        thickness: 1,
        color: Color(0x22FFFFFF),
      ),
    );
  }
}

class _SectionContainer extends StatelessWidget {
  const _SectionContainer({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: child,
        ),
      ),
    );
  }
}

class _LandingTypography {
  const _LandingTypography._();

  static TextTheme textTheme(TextTheme base) {
    final inter = GoogleFonts.interTextTheme(base);

    TextStyle? poppins(TextStyle? style) {
      final resolved = style ?? const TextStyle();
      return GoogleFonts.poppins(textStyle: resolved).copyWith(fontWeight: FontWeight.w600);
    }

    TextStyle? interBody(TextStyle? style, {double? height}) {
      final resolved = style ?? const TextStyle();
      return GoogleFonts.inter(textStyle: resolved).copyWith(height: height);
    }

    return inter.copyWith(
      displayLarge: poppins(inter.displayLarge),
      displayMedium: poppins(inter.displayMedium),
      displaySmall: poppins(inter.displaySmall),
      headlineLarge: poppins(inter.headlineLarge),
      headlineMedium: poppins(inter.headlineMedium),
      headlineSmall: poppins(inter.headlineSmall),
      titleLarge: poppins(inter.titleLarge),
      titleMedium: inter.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: inter.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: interBody(inter.bodyLarge, height: 1.6),
      bodyMedium: interBody(inter.bodyMedium, height: 1.6),
      bodySmall: interBody(inter.bodySmall, height: 1.5),
      labelLarge: inter.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      labelMedium: inter.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      labelSmall: inter.labelSmall?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

class _SocialLinks {
  const _SocialLinks._();

  static final Uri x = Uri.parse('https://x.com/RepDuel');
  static final Uri instagram = Uri.parse('https://instagram.com/RepDuel');
}

class _Palette {
  static const Color background = Color(0xFF04070B);
  static const Color electricBlue = Color(0xFF4AD7F5);
}
