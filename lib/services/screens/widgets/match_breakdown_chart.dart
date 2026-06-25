import 'package:flutter/material.dart';

import '../../matching_engine.dart';

/// Bar chart + field list for roommate compatibility breakdown.
class MatchBreakdownChart extends StatelessWidget {
  final StudentMatch match;
  final bool showCategorySummary;

  const MatchBreakdownChart({
    super.key,
    required this.match,
    this.showCategorySummary = true,
  });

  Color _colorForScore(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final fields = match.fieldScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: match.compatibilityScore / 100,
                      strokeWidth: 7,
                      backgroundColor: Colors.grey.withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation(_colorForScore(match.compatibilityScore)),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${match.compatibilityScore.toInt()}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: _colorForScore(match.compatibilityScore),
                          ),
                        ),
                        const Text('Match', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Overall compatibility',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      match.compatibilityScore >= 75
                          ? 'Strong match — lifestyle, budget & habits align well.'
                          : 'Partial match — review fields below before sending a request.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showCategorySummary && match.attributeScores.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text('By category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: match.attributeScores.entries.map((e) {
              return Chip(
                avatar: CircleAvatar(
                  backgroundColor: _colorForScore(e.value).withValues(alpha: 0.2),
                  child: Text(
                    '${e.value.toInt()}',
                    style: TextStyle(fontSize: 10, color: _colorForScore(e.value), fontWeight: FontWeight.bold),
                  ),
                ),
                label: Text(e.key, style: const TextStyle(fontSize: 12)),
                backgroundColor: _colorForScore(e.value).withValues(alpha: 0.08),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 16),
        const Text('Field-by-field match', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 10),
        if (fields.isEmpty)
          const Text('No breakdown available.', style: TextStyle(color: Colors.grey, fontSize: 12))
        else
          ...fields.map((entry) => _FieldBar(
                label: entry.key,
                score: entry.value,
                color: _colorForScore(entry.value),
              )),
      ],
    );
  }
}

class _FieldBar extends StatelessWidget {
  final String label;
  final double score;
  final Color color;

  const _FieldBar({
    required this.label,
    required this.score,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final matched = score >= 75;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                matched ? Icons.check_circle : Icons.info_outline,
                size: 16,
                color: matched ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ),
              Text(
                '${score.toInt()}%',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 8,
              backgroundColor: Colors.grey.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}
