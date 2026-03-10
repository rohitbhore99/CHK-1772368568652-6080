import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user.dart' as models;

class AuthService {
  final firebase_auth.FirebaseAuth _firebaseAuth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Stream<firebase_auth.User?> get authStateChanges => _firebaseAuth.authStateChanges();

  firebase_auth.User? get currentUser => _firebaseAuth.currentUser;

  Future<firebase_auth.UserCredential> loginWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      return userCredential;
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  Future<firebase_auth.UserCredential> signupWithEmailPassword({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    try {
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      // Create user document in Firestore
      final user = models.User(
        id: userCredential.user!.uid,
        email: email.trim(),
        name: name.trim(),
        role: role,
      );

      await _db.collection('users').doc(userCredential.user!.uid).set(user.toMap());

       if (role == 'teacher') {
        await _db.collection('teachers').doc(userCredential.user!.uid).set({
          'userId': userCredential.user!.uid,
          'classes': [],
          'department': 'General',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      return userCredential;
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  Future<String?> getUserRole(String userId) async {
    try {
      final doc = await _db.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data()?['role'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<models.User?> getUserData(String userId) async {
    try {
      final doc = await _db.collection('users').doc(userId).get();
      if (doc.exists) {
        return models.User.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<firebase_auth.UserCredential> signInWithGoogle() async {
    try {
       final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        throw 'Google sign in was cancelled';
      }

       final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

       final credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

       final userCredential = await _firebaseAuth.signInWithCredential(credential);

       final userDoc = await _db.collection('users').doc(userCredential.user!.uid).get();
      if (!userDoc.exists) {
         final user = models.User(
          id: userCredential.user!.uid,
          email: userCredential.user!.email!,
          name: userCredential.user!.displayName ?? 'Unknown User',
          role: 'student', // Default role for Google sign-in
        );

        await _db.collection('users').doc(userCredential.user!.uid).set(user.toMap());
      }

      return userCredential;
    } catch (e) {
      throw 'Google sign in failed: $e';
    }
  }

  Future<void> logout() async {
    await _googleSignIn.signOut();
    await _firebaseAuth.signOut();
  }

  Future<void> resetPassword(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  String _handleAuthException(firebase_auth.FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'The email address is already in use.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled.';
      default:
        return e.message ?? 'An authentication error occurred.';
    }
  }
}
