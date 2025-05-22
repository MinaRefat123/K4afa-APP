import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  Future<UserCredential> signUp(
      String email, String password, String firstName, String lastName) async {
    try {
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;
      if (user != null) {
        await _database.child('users').child(user.uid).set({
          'firstName': firstName,
          'lastName': lastName,
          'email': email,
          'role': 'user',
          'status': 'pending', 
          'createdAt': ServerValue.timestamp,
        });
      }
      return userCredential;
    } catch (e) {
      print('AuthService: Error during sign up: $e');
      rethrow;
    }
  }

  Future<User?> signIn(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } catch (e) {
      print('AuthService: Error during sign in: $e');
      rethrow;
    }
  }

  Future<String?> getUserRole() async {
    User? user = _auth.currentUser;
    if (user != null) {
      print('AuthService: Fetching user role for UID: ${user.uid}');
      try {
        DatabaseEvent event =
            await _database.child('users').child(user.uid).child('role').once();
        print('AuthService: User role fetched: ${event.snapshot.value}');
        return event.snapshot.value as String?;
      } catch (e) {
        print('AuthService: Error fetching user role: $e');
        return null;
      }
    }
    print('AuthService: No user logged in, returning null role');
    return null;
  }

  Future<Map<String, dynamic>?> getUserData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        DatabaseEvent event =
            await _database.child('users').child(user.uid).once();
        if (event.snapshot.value != null) {
          return Map<String, dynamic>.from(event.snapshot.value as Map);
        }
      } catch (e) {
        print('AuthService: Error fetching user data: $e');
      }
    }
    return null;
  }

  Stream<String?> getUserRoleStream() {
    return _auth.authStateChanges().asyncMap((User? user) async {
      if (user != null) {
        print('AuthService: Starting getUserRoleStream for UID: ${user.uid}');
        DatabaseEvent event =
            await _database.child('users').child(user.uid).child('role').once();
        print('AuthService: getUserRoleStream emitted value: ${event.snapshot.value}');
        return event.snapshot.value as String? ?? 'user';
      }
      print('AuthService: No user logged in, emitting null in getUserRoleStream');
      return null;
    }).handleError((error) {
      print('AuthService: getUserRoleStream error: $error');
      return null;
    }).asBroadcastStream();
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
      print('AuthService: User signed out successfully');
    } catch (e) {
      print('AuthService: Error during sign out: $e');
      rethrow;
    }
  }

  User? getCurrentUser() {
    return _auth.currentUser;
  }
}