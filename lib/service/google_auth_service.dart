import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// The scopes required by this application.
// #docregion Initialize
const List<String> scopes = <String>[
  'email',
  'https://www.googleapis.com/auth/contacts.readonly',
];

class GoogleAuthService {
  // instance of auth
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  // Get current user
  User? getCurrentUser() {
    return _firebaseAuth.currentUser;
  }

  // Email sign in
  Future<UserCredential> signInWithEmailPassword(
    String email,
    String password,
  ) async {
    try {
      // sign user in
      UserCredential userCredential = await _firebaseAuth
          .signInWithEmailAndPassword(email: email, password: password);

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.code);
    }
  }

  // Email sign up
  Future<UserCredential> signUpWithEmailPassword(
    String email,
    String password,
  ) async {
    try {
      // create user
      UserCredential userCredential = await _firebaseAuth
          .createUserWithEmailAndPassword(email: email, password: password);

      return userCredential;
    } on FirebaseException catch (e) {
      throw Exception(e.code);
    }
  }

  // sign out
  Future<void> signOut() async {
    return await _firebaseAuth.signOut();
  }

  // google sign in
  Future<UserCredential?> signInWithGoogle() async {
    // begin interactive sign in process
    final GoogleSignInAccount? gUser = await GoogleSignIn(
      // Optional clientId
      // clientId: 'your-client_id.apps.googleusercontent.com',
      // scopes: scopes,
    ).signIn();

    // user cancels google sign in pop up screen
    if (gUser == null) return null;

    // obtain auth details from request
    final GoogleSignInAuthentication gAuth = await gUser.authentication;

    // create a new credential for user
    final credential = GoogleAuthProvider.credential(
      accessToken: gAuth.accessToken,
      idToken: gAuth.idToken,
    );

    // finally, sign in!
    return await _firebaseAuth.signInWithCredential(credential);
  }

  // Possible error messages
  String getErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'Exception: wrong-password':
        return 'The password is incorrect. Please try again.';
      case 'Exception: user-not-found':
        return 'No user found with this email. Please sign up.';
      case 'Exception: invalid-email':
        return 'This email does not exist';
      default:
        return 'An unexpected error occurred. Please try again later.';
    }
  }
}
