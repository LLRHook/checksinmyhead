import 'package:flutter/foundation.dart';

class ApiConfig {
  static String get baseUrl {
    if (kReleaseMode) {
      return 'https://billington-api.onrender.com';
    }
    return 'http://localhost:8080';
  }
}
