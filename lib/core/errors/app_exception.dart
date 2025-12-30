import 'package:flutter/material.dart';

class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic details;

  AppException(this.message, {this.code, this.details});

  // Get appropriate icon based on error code
  IconData get icon {
    switch (code) {
      case 'NETWORK_ERROR':
        return Icons.wifi_off_rounded;
      case 'TIMEOUT':
        return Icons.schedule_rounded;
      case 'UNAUTHORIZED':
        return Icons.lock_outline_rounded;
      case 'BAD_REQUEST':
        return Icons.error_outline_rounded;
      case 'SERVER_ERROR':
        return Icons.cloud_off_rounded;
      case 'CONFIG_ERROR':
        return Icons.settings_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  // Factory methods for common error types
  factory AppException.config(String? error) {
    return AppException(
      error ?? 'Configuration error',
      code: 'CONFIG_ERROR',
    );
  }

  factory AppException.timeout(dynamic details) {
    return AppException(
      'Request timeout',
      code: 'TIMEOUT',
      details: details,
    );
  }

  factory AppException.unknown(String message) {
    return AppException(
      message,
      code: 'UNKNOWN_ERROR',
    );
  }

  factory AppException.network(String message) {
    return NetworkException(message, code: 'NETWORK_ERROR');
  }

  factory AppException.badRequest(String message) {
    return AppException(
      message,
      code: 'BAD_REQUEST',
    );
  }

  factory AppException.unauthorized(String message) {
    return AuthException(message, code: 'UNAUTHORIZED');
  }

  factory AppException.server(String message) {
    return AppException(
      message,
      code: 'SERVER_ERROR',
    );
  }

  @override
  String toString() => message;
}

class NetworkException extends AppException {
  NetworkException(super.message, {super.code, super.details});
}

class AuthException extends AppException {
  AuthException(super.message, {super.code, super.details});
}

class ValidationException extends AppException {
  ValidationException(super.message, {super.code, super.details});
}
