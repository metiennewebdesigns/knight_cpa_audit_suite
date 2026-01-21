import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../dashboard_models.dart';

class DashboardRepository {
  const DashboardRepository();

  Future<DashboardData> loadDashboard() async {
    final raw = await rootBundle.loadString('assets/seed/seed_data.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return DashboardData.fromJson(decoded);
  }
}