import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../theme/adult_theme.dart';
import 'session_play_screen.dart';

/// Scenario selection screen for Adult Mode
class ScenarioSelectionScreen extends StatelessWidget {
  final ScenarioType? preselectedScenario;

  const ScenarioSelectionScreen({
    super.key,
    this.preselectedScenario,
  });

  @override
  Widget build(BuildContext context) {
    // If preselected, go directly to session
    if (preselectedScenario != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => SessionPlayScreen(scenario: preselectedScenario!),
          ),
        );
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AdultTheme.background,
      appBar: AppBar(
        title: const Text('Choose Scenario'),
        backgroundColor: AdultTheme.background,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Practice real-world conversations',
              style: AdultTheme.bodyLarge,
            ),
            const SizedBox(height: 24),

            // Scenario cards
            ...ScenarioType.values.map((scenario) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _ScenarioCard(
                  scenario: scenario,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SessionPlayScreen(scenario: scenario),
                      ),
                    );
                  },
                ),
              );
            }),

            const SizedBox(height: 24),

            // Free practice option
            _FreePracticeCard(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SessionPlayScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  final ScenarioType scenario;
  final VoidCallback onTap;

  const _ScenarioCard({
    required this.scenario,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AdultTheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AdultTheme.border),
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AdultTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    scenario.icon,
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scenario.displayName,
                      style: AdultTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      scenario.description,
                      style: AdultTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: AdultTheme.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FreePracticeCard extends StatelessWidget {
  final VoidCallback onTap;

  const _FreePracticeCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AdultTheme.primary, width: 2),
            color: AdultTheme.primary.withOpacity(0.05),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AdultTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.mic_rounded,
                  color: AdultTheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Free Practice',
                      style: AdultTheme.titleMedium.copyWith(
                        color: AdultTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Practice anything with real-time feedback',
                      style: AdultTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AdultTheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
