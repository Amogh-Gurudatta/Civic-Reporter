import 'package:flutter/material.dart';

enum IssueSeverity { low, medium, high, unknown }

class Issue {
  final String id;
  final String classification;
  final IssueSeverity severity;
  final String description;
  final double latitude;
  final double longitude;
  final String status;
  final DateTime timestamp;
  final String imageUrl;

  Issue({
    required this.id,
    required this.classification,
    required this.severity,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.timestamp,
    this.imageUrl = '',
  });

  factory Issue.fromJson(Map<String, dynamic> json) {
    // Parse severity enum
    final severityStr = (json['severity'] ?? '').toString().toLowerCase();
    IssueSeverity severity = IssueSeverity.unknown;
    if (severityStr.contains('low')) {
      severity = IssueSeverity.low;
    } else if (severityStr.contains('medium')) {
      severity = IssueSeverity.medium;
    } else if (severityStr.contains('high')) {
      severity = IssueSeverity.high;
    }

    // Parse coordinates safely
    double parseCoordinate(dynamic val) {
      if (val == null) return 0.0;
      double parsedVal = 0.0;
      if (val is num) {
        parsedVal = val.toDouble();
      } else {
        parsedVal = double.tryParse(val.toString()) ?? 0.0;
      }
      // CRITICAL FIX: Prevent NaN or Infinity from crashing the map
      return parsedVal.isFinite ? parsedVal : 0.0;
    }

    // Parse timestamp safely
    DateTime parseDateTime(dynamic val) {
      if (val == null) return DateTime.now();
      try {
        return DateTime.parse(val.toString());
      } catch (_) {
        return DateTime.now();
      }
    }

    return Issue(
      id: json['id']?.toString() ?? '',
      classification:
          json['classification']?.toString() ?? 'General Civic Issue',
      severity: severity,
      description: json['description']?.toString() ?? '',
      latitude: parseCoordinate(json['latitude']),
      longitude: parseCoordinate(json['longitude']),
      status: json['status']?.toString() ?? 'Pending',
      timestamp: parseDateTime(json['timestamp']),
      imageUrl: json['imageUrl']?.toString() ?? '',
    );
  }

  /// Get corresponding display color for issue severity
  Color get severityColor {
    switch (severity) {
      case IssueSeverity.low:
        return Colors.green.shade600;
      case IssueSeverity.medium:
        return Colors.orange.shade600;
      case IssueSeverity.high:
        return Colors.red.shade600;
      case IssueSeverity.unknown:
        return Colors.grey.shade600;
    }
  }

  /// Get corresponding icon for issue severity
  IconData get severityIcon {
    switch (severity) {
      case IssueSeverity.low:
        return Icons.info_outline;
      case IssueSeverity.medium:
        return Icons.warning_amber_rounded;
      case IssueSeverity.high:
        return Icons.report_problem_rounded;
      case IssueSeverity.unknown:
        return Icons.help_outline_rounded;
    }
  }

  /// Get label for severity representation
  String get severityLabel {
    switch (severity) {
      case IssueSeverity.low:
        return 'Low';
      case IssueSeverity.medium:
        return 'Medium';
      case IssueSeverity.high:
        return 'High';
      case IssueSeverity.unknown:
        return 'Unknown';
    }
  }
}
