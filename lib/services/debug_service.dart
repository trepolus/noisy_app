import 'dart:async';
import 'package:flutter/foundation.dart';

class DebugService {
  static final DebugService _instance = DebugService._internal();
  factory DebugService() => _instance;
  DebugService._internal();

  final _logController = StreamController<String>.broadcast();
  Stream<String> get logStream => _logController.stream;
  List<String> _logHistory = [];
  static const int _maxLogHistory = 100;

  void log(String message) {
    final timestamp = DateTime.now().toString().split('.').first;
    final logMessage = '[$timestamp] $message';
    
    debugPrint(logMessage); // Still print to console
    _logHistory.add(logMessage);
    
    // Keep log history size manageable
    if (_logHistory.length > _maxLogHistory) {
      _logHistory.removeAt(0);
    }
    
    _logController.add(logMessage);
  }

  List<String> get logHistory => List.unmodifiable(_logHistory);

  void clear() {
    _logHistory.clear();
    _logController.add('Logs cleared');
  }

  void dispose() {
    _logController.close();
  }
} 