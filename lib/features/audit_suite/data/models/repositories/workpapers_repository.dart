import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../../../../core/storage/local_store.dart';

import '../workpaper_models.dart';
import '../permissions.dart';
import '../repositories/session_repository.dart';
import 'engagements_repository.dart';

import 'workpaper_attachment_io.dart';

class WorkpapersRepository {
  WorkpapersRepository(this.store);

  final LocalStore store;

  static const _cacheKey = 'demo_workpapers_cache_v1';
  List<WorkpaperModel>? _memoryCache;

  SessionRepository get _session => SessionRepository(store);
  EngagementsRepository get _engRepo => EngagementsRepository(store);

  Future<List<WorkpaperModel>> getWorkpapers() async {
    if (_memoryCache != null) return _memoryCache!;

    final cached = store.prefs.getString(_cacheKey);
    if (cached != null && cached.trim().isNotEmpty) {
      final decoded = jsonDecode(cached) as List<dynamic>;
      _memoryCache = decoded
          .map((e) => WorkpaperModel.fromJson(e as Map<String, dynamic>))
          .toList();
      return _memoryCache!;
    }

    final seed = await _loadSeed();
    final list = (seed['workpapers'] as List<dynamic>? ?? const <dynamic>[])
        .map((e) => WorkpaperModel.fromJson(e as Map<String, dynamic>))
        .toList();

    _memoryCache = list;
    await _persist(list);
    return list;
  }

  Future<List<WorkpaperModel>> getByEngagementId(String engagementId) async {
    final list = await getWorkpapers();
    return list.where((w) => w.engagementId == engagementId).toList();
  }

  Future<WorkpaperModel?> getById(String id) async {
    final list = await getWorkpapers();
    try {
      return list.firstWhere((w) => w.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<WorkpaperModel> upsert(WorkpaperModel draft) async {
    final role = _session.current.role;
    Permissions.require(
      Permissions.canCreateEditDeleteWorkpaper(role),
      'Permission denied: Client users cannot create or edit workpapers.',
    );

    final list = [...await getWorkpapers()];

    final id = draft.id.trim().isEmpty ? _newId() : draft.id.trim();
    final normalized = draft.copyWith(
      id: id,
      updated: draft.updated.trim().isEmpty ? _todayIso() : draft.updated.trim(),
    );

    final idx = list.indexWhere((w) => w.id == id);
    if (idx >= 0) {
      list[idx] = normalized;
    } else {
      list.add(normalized);
    }

    _memoryCache = list;
    await _persist(list);
    return normalized;
  }

  Future<void> deleteById(String id) async {
    final role = _session.current.role;
    Permissions.require(
      Permissions.canCreateEditDeleteWorkpaper(role),
      'Permission denied: Client users cannot delete workpapers.',
    );

    final list = [...await getWorkpapers()];
    list.removeWhere((w) => w.id == id);

    _memoryCache = list;
    await _persist(list);
  }

  // ---------- Attachments ----------
  Future<WorkpaperModel> addAttachment({
    required String workpaperId,
    required String sourcePath,
    required String originalName,
    required int sizeBytes,
  }) async {
    final wp = await getById(workpaperId);
    if (wp == null) throw Exception('Workpaper not found: $workpaperId');

    final eng = await _engRepo.getById(wp.engagementId);
    final finalized = (eng?.status ?? '').trim().toLowerCase() == 'finalized';
    Permissions.require(!finalized, 'Engagement is finalized (locked).');

    if (kIsWeb || !store.canUseFileSystem) {
      throw UnsupportedError('Attachments are not supported in the web demo');
    }

    final docsPath = store.documentsPath!;
    final safeName = _safeFilename(originalName);
    final newId = 'att-${DateTime.now().millisecondsSinceEpoch}';

    final destDir = p.join(docsPath, 'Auditron', 'WorkpaperAttachments', wp.engagementId);
    final destPath = await WorkpaperAttachmentIO.copyInto(
      destDir: destDir,
      sourcePath: sourcePath,
      destFileName: '$newId-$safeName',
    );

    final next = WorkpaperAttachmentModel(
      id: newId,
      name: originalName,
      localPath: destPath,
      sizeBytes: sizeBytes,
      addedAtIso: DateTime.now().toUtc().toIso8601String(),
    );

    return upsertLocalOnly(
      wp.copyWith(
        attachments: [next, ...wp.attachments],
        updated: '',
      ),
    );
  }

  Future<WorkpaperModel> removeAttachment({
    required String workpaperId,
    required String attachmentId,
  }) async {
    final wp = await getById(workpaperId);
    if (wp == null) throw Exception('Workpaper not found: $workpaperId');

    final eng = await _engRepo.getById(wp.engagementId);
    final finalized = (eng?.status ?? '').trim().toLowerCase() == 'finalized';
    Permissions.require(!finalized, 'Engagement is finalized (locked).');

    final nextAttachments = wp.attachments.where((a) => a.id != attachmentId).toList();

    if (!kIsWeb && store.canUseFileSystem) {
      try {
        final removed = wp.attachments.where((a) => a.id == attachmentId).toList();
        if (removed.isNotEmpty) {
          await WorkpaperAttachmentIO.deleteIfExists(removed.first.localPath);
        }
      } catch (_) {}
    }

    return upsertLocalOnly(
      wp.copyWith(
        attachments: nextAttachments,
        updated: '',
      ),
    );
  }

  Future<WorkpaperModel> upsertLocalOnly(WorkpaperModel draft) async {
    final list = [...await getWorkpapers()];

    final id = draft.id.trim().isNotEmpty ? draft.id.trim() : _newId();
    final normalized = draft.copyWith(
      id: id,
      updated: draft.updated.trim().isEmpty ? _todayIso() : draft.updated.trim(),
    );

    final idx = list.indexWhere((w) => w.id == id);
    if (idx >= 0) {
      list[idx] = normalized;
    } else {
      list.add(normalized);
    }

    _memoryCache = list;
    await _persist(list);
    return normalized;
  }

  Future<void> clearCache() async {
    _memoryCache = null;
  }

  Future<void> resetDemo() async {
    _memoryCache = null;
    await store.prefs.remove(_cacheKey);
  }

  Future<void> _persist(List<WorkpaperModel> list) async {
    await store.prefs.setString(
      _cacheKey,
      jsonEncode(list.map((e) => e.toJson()).toList()),
    );
  }

  Future<Map<String, dynamic>> _loadSeed() async {
    final raw = await rootBundle.loadString('assets/seed/demo_data.json');
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  String _newId() => 'wp-${DateTime.now().millisecondsSinceEpoch}';

  String _todayIso() {
    final d = DateTime.now();
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  String _safeFilename(String name) {
    final cleaned = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    return cleaned.isEmpty ? 'file' : cleaned;
  }
}