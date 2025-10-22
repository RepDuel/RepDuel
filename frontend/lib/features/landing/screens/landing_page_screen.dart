// frontend/lib/features/landing/screens/landing_page_screen.dart

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

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

    return Scaffold(
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
              theme: theme,
            ),
          ),
        ],
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
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final isCompact = MediaQuery.of(context).size.width < 900;

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
                          style: textTheme.bodyMedium?.copyWith(
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
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
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
            style: GoogleFonts.rubik(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: isCompact ? 18 : 20,
              letterSpacing: 1.4,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'RepDuel',
          style: GoogleFonts.rubik(
            color: Colors.white,
            fontSize: isCompact ? 20 : 24,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
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
          style: GoogleFonts.rubik(
            color: Colors.white.withOpacity(0.86),
            fontSize: 15,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.4,
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
              _Pill(text: 'Precision Strength Platform'),
              _Pill(text: 'AI Training Intelligence'),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            'Where elite training meets scientific clarity.',
            style: GoogleFonts.michroma(
              color: Colors.white,
              fontSize: isCompact ? 38 : 54,
              fontWeight: FontWeight.w500,
              height: 1.1,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'RepDuel brings the intensity of competition to your personal bests — '
            'an integrated arena for athletes, coaches, and teams to programme, '
            'measure, and lead with conviction.',
            style: GoogleFonts.rubik(
              color: Colors.white.withOpacity(0.78),
              fontSize: isCompact ? 16 : 18,
              height: 1.6,
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
                  children: const [
                    Text(
                      'Start competing',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(width: 10),
                    Icon(Icons.arrow_forward_rounded, size: 20),
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
                  children: const [
                    Icon(Icons.bar_chart_rounded, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'View leaderboards',
                      style: TextStyle(
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
                value: '38K+',
                label: 'Total ranked attempts this season',
              ),
              _StatCard(
                value: '120+',
                label: 'Collegiate teams using RepDuel analytics',
              ),
              _StatCard(
                value: '24/7',
                label: 'Real-time monitoring and recovery insights',
              ),
            ],
          ),
          const SizedBox(height: 40),
          TextButton.icon(
            onPressed: onLearnMoreTap,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70),
            label: Text(
              'Discover how teams scale with RepDuel',
              style: GoogleFonts.rubik(
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
        color: Colors.white.withOpacity(0.04),
      ),
      child: Text(
        text,
        style: GoogleFonts.rubik(
          color: Colors.white.withOpacity(0.8),
          fontSize: 13,
          letterSpacing: 0.6,
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
            style: GoogleFonts.michroma(
              color: _Palette.electricBlue,
              fontSize: 30,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: GoogleFonts.rubik(
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

    return _SectionContainer(
      padding: const EdgeInsets.fromLTRB(24, 64, 24, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Built for institutions that lead the field.',
            style: GoogleFonts.michroma(
              color: Colors.white,
              fontSize: isCompact ? 28 : 36,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'RepDuel unifies sports science, performance coaching, and team operations into a single operating system. '
            'From national teams to emerging programmes, organisations choose RepDuel to translate granular lift data '
            'into decisive strategy.',
            style: GoogleFonts.rubik(
              color: Colors.white.withOpacity(0.74),
              fontSize: 17,
              height: 1.65,
            ),
          ),
          const SizedBox(height: 42),
          Wrap(
            spacing: 24,
            runSpacing: 24,
            children: const [
              _PrincipleCard(
                title: 'Performance without compromise',
                copy:
                    'Real-time telemetry, readiness scoring, and data rooms engineered for directors of performance.',
              ),
              _PrincipleCard(
                title: 'Security-first architecture',
                copy:
                    'Enterprise SSO, field-level encryption, and regional data residency keep athlete information protected.',
              ),
              _PrincipleCard(
                title: 'Global expertise',
                copy:
                    'Our applied scientists partner with your staff to model workloads, travel, and recovery at scale.',
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
                  style: GoogleFonts.rubik(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            copy,
            style: GoogleFonts.rubik(
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
                      'Technology that anticipates the next rep.',
                      style: GoogleFonts.michroma(
                        color: Colors.white,
                        fontSize: isCompact ? 28 : 34,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Machine learning models surface readiness, fatigue risk, and tactical opportunities in real-time. '
                      'Our infrastructure scales from academy squads to Olympic delegations with the same fidelity.',
                      style: GoogleFonts.rubik(
                        color: Colors.white.withOpacity(0.74),
                        fontSize: 16.5,
                        height: 1.6,
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
                        'Live control over sessions, leaderboards, and athlete availability. Deploy new programmes with instant analytics.',
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
                title: 'Adaptive Readiness',
                description:
                    'Combines HRV, bar speed, and workload trends to deliver personalised session prescriptions.',
              ),
              _CapabilityCard(
                icon: Icons.auto_graph_rounded,
                title: 'Predictive Leaderboards',
                description:
                    'Forecast podium movement based on historic intent, federation standards, and travel windows.',
              ),
              _CapabilityCard(
                icon: Icons.security_rounded,
                title: 'Compliance by default',
                description:
                    'GDPR, HIPAA, and NCAA frameworks embedded into data flows with audit-ready exports.',
              ),
              _CapabilityCard(
                icon: Icons.hub_rounded,
                title: 'Open ecosystem',
                description:
                    'APIs, webhooks, and native integrations with AMS, wearables, and roster management tools.',
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
            style: GoogleFonts.rubik(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            body,
            style: GoogleFonts.rubik(
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
            style: GoogleFonts.rubik(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: GoogleFonts.rubik(
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
                  'People who build the future of sport.',
                  style: GoogleFonts.michroma(
                    color: Colors.white,
                    fontSize: isCompact ? 26 : 32,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Engineers, applied scientists, strategists, and former athletes collaborate in our global labs to design '
                  'the tools that decide championships. We hire with intention, partner deeply with federations, and cultivate '
                  'an environment where bold ideas stand up to the pressure of competition.',
                  style: GoogleFonts.rubik(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 16,
                    height: 1.7,
                  ),
                ),
                const SizedBox(height: 28),
                Wrap(
                  spacing: 24,
                  runSpacing: 16,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: const [
                    _CultureHighlight(
                      title: 'Global performance labs',
                      subtitle: 'Chicago · London · Singapore',
                    ),
                    _CultureHighlight(
                      title: 'Investment in learning',
                      subtitle: 'Individual research budgets and mentorship',
                    ),
                    _CultureHighlight(
                      title: 'High-trust teams',
                      subtitle: 'Autonomy with measurable outcomes',
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
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.rubik(
              color: _Palette.electricBlue,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: GoogleFonts.rubik(
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
              'RepDuel at your organisation',
              style: GoogleFonts.michroma(
                color: Colors.white,
                fontSize: isCompact ? 28 : 34,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Schedule a strategic session with our applied performance team. We will map your goals, infrastructure, and launch plan in under two weeks.',
              textAlign: isCompact ? TextAlign.start : TextAlign.center,
              style: GoogleFonts.rubik(
                color: Colors.white.withOpacity(0.76),
                height: 1.6,
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
                  child: const Text(
                    'Launch RepDuel',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
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
                  child: const Text(
                    'Contact our team',
                    style: TextStyle(
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
    final textStyle = GoogleFonts.rubik(
      color: Colors.white.withOpacity(0.62),
      fontSize: 13,
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
                      style: GoogleFonts.rubik(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Competition-grade performance intelligence for strength programmes worldwide.',
                      style: textStyle,
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
                    child: const Text('Client login'),
                  ),
                  TextButton(
                    onPressed: () => context.go('/register'),
                    child: const Text('Create account'),
                  ),
                  TextButton(
                    onPressed: () => context.go('/ranked'),
                    child: const Text('Leaderboards'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            '© ${DateTime.now().year} RepDuel Technologies. All rights reserved.',
            style: textStyle,
          ),
        ],
      ),
    );
  }
}

class _FloatingSupportButton extends StatelessWidget {
  const _FloatingSupportButton({
    required this.onTap,
    required this.theme,
  });

  final VoidCallback onTap;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      onPressed: onTap,
      icon: const Icon(Icons.people_alt_rounded),
      label: Text(
        'Join our teams',
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
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

class _Palette {
  static const Color background = Color(0xFF04070B);
  static const Color electricBlue = Color(0xFF4AD7F5);
}
