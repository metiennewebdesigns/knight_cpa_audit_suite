import '../data/models/engagement_models.dart';
import '../data/models/risk_assessment_models.dart';

class AiCopilotAnswer {
  final String title;
  final String body;

  const AiCopilotAnswer({
    required this.title,
    required this.body,
  });
}

class AiCopilotLocal {
  static AiCopilotAnswer summarize({
    required EngagementModel engagement,
    required String clientName,
    required RiskAssessmentModel risk,
    required int openWorkpapers,
    required int totalWorkpapers,
    required int pbcOverdueCount,
    required int discrepancyOpenCount,
    required double discrepancyOpenTotal,
    required int integrityIssues,
    required int readinessPct,
  }) {
    final riskLevel = risk.overallLevel();
    final riskScore = risk.overallScore1to5();

    final lines = <String>[
      'Engagement: ${engagement.title}',
      'Client: $clientName',
      'Status: ${engagement.status}',
      'Updated: ${engagement.updated.isEmpty ? "—" : engagement.updated}',
      '',
      'Risk: $riskLevel ($riskScore/5)',
      'Workpapers: $openWorkpapers open / $totalWorkpapers total',
      'PBC overdue: $pbcOverdueCount',
      'Discrepancies: $discrepancyOpenCount open • \$${discrepancyOpenTotal.toStringAsFixed(2)}',
      'Integrity issues: $integrityIssues',
      'Readiness: $readinessPct%',
    ];

    return AiCopilotAnswer(
      title: 'Engagement summary',
      body: lines.join('\n'),
    );
  }

  static AiCopilotAnswer nextActions({
    required RiskAssessmentModel risk,
    required int openWorkpapers,
    required int pbcOverdueCount,
    required int discrepancyOpenCount,
    required int integrityIssues,
  }) {
    final items = <String>[];

    final riskLevel = risk.overallLevel().toLowerCase();
    if (riskLevel.contains('high')) {
      items.add('1) Review high-risk areas first (fraud risk, revenue, cash).');
      items.add('2) Confirm PBC completeness for high-risk sections.');
    } else if (riskLevel.contains('medium')) {
      items.add('1) Focus on medium-risk sections + trending variances.');
    } else {
      items.add('1) Confirm planning completeness + sampling approach.');
    }

    if (pbcOverdueCount > 0) items.add('• Send overdue PBC reminder (overdue: $pbcOverdueCount).');
    if (discrepancyOpenCount > 0) items.add('• Assign and resolve discrepancies (open: $discrepancyOpenCount).');
    if (integrityIssues > 0) items.add('• Verify evidence integrity issues (issues: $integrityIssues).');
    if (openWorkpapers > 0) items.add('• Close open workpapers and document conclusions.');

    return AiCopilotAnswer(
      title: 'Recommended next actions',
      body: items.isEmpty ? 'No actions detected.' : items.join('\n'),
    );
  }

  static AiCopilotAnswer draftPbcEmail({
    required String engagementId,
    required String clientName,
    required int overdueCount,
    required String portalLink,
    required String pin,
  }) {
    final who = clientName.trim().isEmpty ? 'Team' : clientName.trim();
    final subject = 'Reminder: Please upload overdue audit items';
    final body = '''
Subject: $subject

Hello $who,

This is a friendly reminder to upload the overdue requested items in your Auditron Client Portal.

Engagement ID: $engagementId
Portal link: $portalLink
PIN: $pin

Overdue requested items: $overdueCount

If you have already uploaded the requested items, please disregard this message.

Thank you,
Auditron
''';
    return AiCopilotAnswer(title: 'Draft PBC reminder email', body: body.trim());
  }

  static AiCopilotAnswer explainAiPriority({
    required String label,
    required int score,
    required String reason,
  }) {
    return AiCopilotAnswer(
      title: 'Why this priority?',
      body: 'AI Priority: $label ($score)\n\nReason:\n$reason',
    );
  }
}