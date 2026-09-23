import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

// Turns auth, database, function and network errors into short, plain messages.
String friendlyError(Object error) {
  if (error is TimeoutException) {
    return 'The server took too long to respond. Please try again.';
  }

  final raw = switch (error) {
    AuthException e => e.message,
    PostgrestException e => e.message,
    FunctionException e =>
      (e.details is Map ? e.details['error'] : null)?.toString() ?? '',
    _ => error.toString(),
  };
  final m = raw.toLowerCase();

  if (m.contains('socketexception') ||
      m.contains('failed host lookup') ||
      m.contains('clientexception') ||
      m.contains('network')) {
    return 'No internet connection. Please check your connection and try again.';
  }
  if (m.contains('invalid login credentials')) {
    return 'Incorrect email or password.';
  }
  if (m.contains('email not confirmed')) {
    return 'Please verify your email first. Check your inbox for the code.';
  }
  if (m.contains('already registered') || m.contains('already exists')) {
    return 'An account with this email already exists. Try logging in.';
  }
  if (m.contains('should be different')) {
    return 'Your new password must be different from your current one.';
  }
  if (m.contains('password') &&
      (m.contains('weak') || m.contains('at least'))) {
    return 'Your password is too weak. Please follow the requirements.';
  }
  if (m.contains('expired') || (m.contains('invalid') && m.contains('token'))) {
    return 'That code is invalid or has expired. Please request a new one.';
  }
  if (m.contains('rate limit') || m.contains('too many')) {
    return 'Too many attempts. Please wait a minute and try again.';
  }
  if (m.contains('jwt') || m.contains('not signed in')) {
    return 'Your session has ended. Please log in again.';
  }
  if (m.contains('could not generate a plan')) {
    return "We couldn't create a plan right now. Please try again.";
  }

  // Messages written by our Edge Functions are already user-facing.
  if (error is FunctionException && raw.isNotEmpty) return raw;

  // Database details are never shown; other short plain messages are kept.
  final plain = raw.replaceFirst('Exception: ', '');
  if (error is PostgrestException ||
      plain.isEmpty ||
      plain.length > 120 ||
      RegExp(
        r'exception|error:|null|[{}\[\]]',
        caseSensitive: false,
      ).hasMatch(plain)) {
    return 'Something went wrong. Please try again.';
  }
  return plain;
}
