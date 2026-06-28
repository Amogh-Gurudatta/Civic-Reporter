class ApiConfig {
  /// Base API URL dynamically set to work on physical devices, Android emulator and iOS simulator.
  static String get baseUrl {
    // if (kIsWeb) {
    //   return 'http://localhost:8000';
    // }
    // try {
    //   if (Platform.isAndroid) {
    //     // Android emulator addresses localhost at 10.0.2.2
    //     return 'http://10.0.2.2:8000';
    //   }
    // } catch (_) {
    //   // Fallback for platform check exceptions
    // }
    // return 'http://localhost:8000';
    return 'https://civic-backend-446777296937.asia-south1.run.app';
  }

  static String get reportIssueUrl => '$baseUrl/report-issue';
  static String get issuesUrl => '$baseUrl/issues';
}
