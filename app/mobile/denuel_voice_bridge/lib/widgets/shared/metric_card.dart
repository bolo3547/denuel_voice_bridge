import 'package:flutter/material.dart';
import '../../theme/adult_theme.dart';
import '../../models/models.dart';

/// Metric card for displaying speech analysis metrics (Adult Mode)
class MetricCard extends StatelessWidget {
  final String label;
  final double value;
  final String? unit;
  final MetricSeverity? severity;
  final IconData? icon;
  final bool showProgress;
  final double? maxValue;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.severity,
    this.icon,
    this.showProgress = true,
    this.maxValue = 100,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveSeverity = severity ?? SpeechMetrics.getSeverity(value);
    final color = _getSeverityColor(effectiveSeverity);
    final progress = maxValue != null ? (value / maxValue!).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdultTheme.surface,
        borderRadius: BorderRadius.circular(AdultTheme.radiusMedium),
        border: Border.all(color: AdultTheme.border),
        boxShadow: AdultTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: AdultTheme.textTertiary),
                const SizedBox(width: 6),
              ],
              Text(
                label.toUpperCase(),
                style: AdultTheme.metricLabel,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value.toStringAsFixed(unit == '%' ? 0 : 1),
                style: AdultTheme.metricValue.copyWith(color: color),
              ),
              if (unit != null) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    unit!,
                    style: AdultTheme.bodyMedium.copyWith(color: color),
                  ),
                ),
              ],
            ],
          ),
          if (showProgress && maxValue != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AdultTheme.surfaceVariant,
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 6,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              effectiveSeverity.label,
              style: AdultTheme.labelMedium.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }

  Color _getSeverityColor(MetricSeverity severity) {
    switch (severity) {
      case MetricSeverity.good:
        return AdultTheme.metricGood;
      case MetricSeverity.moderate:
        return AdultTheme.metricModerate;
      case MetricSeverity.needsWork:
        return AdultTheme.metricNeedsWork;
    }
  }
}

/// Compact metric display for inline use
class MetricChip extends StatelessWidget {
  final String label;
  final double value;
  final MetricSeverity? severity;

  const MetricChip({
    super.key,
    required this.label,
    required this.value,
    this.severity,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveSeverity = severity ?? SpeechMetrics.getSeverity(value);
    final color = _getSeverityColor(effectiveSeverity);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: AdultTheme.labelMedium.copyWith(color: AdultTheme.textSecondary),
          ),
          const SizedBox(width: 8),
          Text(
            '${value.toStringAsFixed(0)}%',
            style: AdultTheme.labelLarge.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  Color _getSeverityColor(MetricSeverity severity) {
    switch (severity) {
      case MetricSeverity.good:
        return AdultTheme.metricGood;
      case MetricSeverity.moderate:
        return AdultTheme.metricModerate;
      case MetricSeverity.needsWork:
        return AdultTheme.metricNeedsWork;
    }
  }
}
