import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/transfer_task.dart';


class TransferStore {
  static const _key = 'transfers_v1';
  static const _maxFinished = 40;

  Future<List<TransferTask>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return [];
      return (jsonDecode(raw) as List)
          .map((e) => TransferTask.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<TransferTask> tasks) async {
    try {
      final finished = tasks.where((t) => t.isFinished).toList();
      final keepFinished = finished.length > _maxFinished
          ? finished.sublist(finished.length - _maxFinished).toSet()
          : finished.toSet();
      final toSave = tasks.where((t) => !t.isFinished || keepFinished.contains(t));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(toSave.map((t) => t.toJson()).toList()));
    } catch (_) {}
  }
}
