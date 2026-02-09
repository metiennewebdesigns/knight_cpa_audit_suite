import '../data/models/engagement_models.dart';
import '../data/models/risk_assessment_models.dart';

class AiPriorityResult {
  final String label; // Low | Medium | High | Critical
  final int score; // 0-100
  final String reason;

  const AiPriorityResult({
    required this.label,
    required this.score,
    required this.reason,
  });
}

class AiPriorityScorer {
  static AiPriorityResult score({
    required EngagementModel engagement,
    required RiskAssessmentModel? risk,
    required int pbcOverdueCount,
    required int integrityIssues,
    required int openWorkpapers,
    required int totalWorkpapers,
    required int discrepancyOpenCount,
    required double discrepancyOpenTotal,
  }) {
    final status = engagement.status.trim().toLowerCase();
    if (status == 'finalized' || status == 'archived') {
      return const AiPriorityResult(
        label: 'Low',
        score: 5,
        reason: 'Engagement is finalized/archived.',
      );
    }

    int score = 0;
    final reasons = <String>[];

    // ---- Risk (biggest driver) ----
    final level = (risk?.overallLevel() ?? '').trim().toLowerCase();
    final score5 = risk?.overallScore1to5() ?? 0;

    if (level.contains('high')) {
      score += 45;
      reasons.add('Risk: High');
    } else if (level.contains('medium') || level.contains('moderate')) {
      score += 30;
      reasons.add('Risk: Medium');
    } else if (level.contains('low')) {
      score += 15;
      reasons.add('Risk: Low');
    } else {
      score += 20;
      reasons.add('Risk: Not assessed');
    }

    if (score5 >= 5) score += 8;
    if (score5 == 4) score += 4;
    if (score5 <= 2) score -= 3;

    // ---- PBC overdue ----
    if (pbcOverdueCount > 0) {
      score += 12;
      reasons.add('PBC overdue: $pbcOverdueCount');
      if (pbcOverdueCount >= 3) score += 6;
    }

    // ---- Integrity ----
    if (integrityIssues > 0) {
      score += 18;
      reasons.add('Integrity issues: $integrityIssues');
      if (integrityIssues >= 3) score += 6;
    }

    // ---- Workpapers open ----
    if (totalWorkpapers > 0) {
      final ratio = openWorkpapers / totalWorkpapers;
      if (ratio >= 0.6 && openWorkpapers >= 8) {
        score += 12;
        reasons.add('Many open workpapers ($openWorkpapers/$totalWorkpapers)');
      } else if (openWorkpapers >= 5) {
        score += 6;
        reasons.add('Open workpapers: $openWorkpapers');
      }
    } else if (openWorkpapers > 0) {
      score += 6;
      reasons.add('Open workpapers: $openWorkpapers');
    }

    // ---- Discrepancies ----
    if (discrepancyOpenCount > 0 || discrepancyOpenTotal > 0) {
      score += 15;
      reasons.add('Discrepancies open: $discrepancyOpenCount');
      if (discrepancyOpenTotal >= 10000) score += 6;
    }

    // clamp
    if (score < 0) score = 0;
    if (score > 100) score = 100;

    String label;
    if (score >= 90) label = 'Critical';
    else if (score >= 70) label = 'High';
    else if (score >= 40) label = 'Medium';
    else label = 'Low';

    return AiPriorityResult(
      label: label,
      score: score,
      reason: reasons.isEmpty ? 'No signals available.' : reasons.join(' • '),
    );
  }
}