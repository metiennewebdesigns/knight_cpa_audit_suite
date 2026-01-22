import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

import '../models/dashboard_models.dart';

class DashboardRepository {
  const DashboardRepository();

  /// Loads dashboard seed data from assets/seed/seed_data.json
  Future<DashboardData> loadDashboard() async {
    final raw = await rootBundle.loadString('assets/seed/seed_data.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return DashboardData.fromJson(decoded);
  }
}