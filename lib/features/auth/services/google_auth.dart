import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Web OAuth client ID from Google Cloud; Supabase accepts tokens issued for it.
const googleWebClientId =
    '1044934712379-iltoevg2hhgfcmqnecf9pmmicui6dhs0.apps.googleusercontent.com';

// Called once at startup, before any Google sign-in.
Future<void> initGoogleSignIn() =>
    GoogleSignIn.instance.initialize(serverClientId: googleWebClientId);

// Signs in with Google and returns true when the account still needs a profile.
Future<bool> signInWithGoogle() async {
  final account = await GoogleSignIn.instance.authenticate();
  final idToken = account.authentication.idToken;
  if (idToken == null) {
    throw const AuthException('Google did not return a sign-in token.');
  }

  const scopes = ['email', 'profile'];
  final authorization =
      await account.authorizationClient.authorizationForScopes(scopes) ??
      await account.authorizationClient.authorizeScopes(scopes);

  final supabase = Supabase.instance.client;
  final response = await supabase.auth.signInWithIdToken(
    provider: OAuthProvider.google,
    idToken: idToken,
    accessToken: authorization.accessToken,
  );

  final profile = await supabase
      .from('user_profiles')
      .select('id')
      .eq('id', response.user!.id)
      .maybeSingle();
  return profile == null;
}

// Clears the Google account too, so the next sign-in shows the account picker.
Future<void> signOutOfGoogle() => GoogleSignIn.instance.signOut();
