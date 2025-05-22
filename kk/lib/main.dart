import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:k4afa/screens/home_screen.dart';
import 'package:k4afa/screens/login_screen.dart' as login;
import 'package:k4afa/screens/signup_screen.dart' as signup;
import 'package:k4afa/screens/splash_screen.dart';
import 'package:k4afa/screens/pending_screen.dart';
import 'package:k4afa/screens/rejected_screen.dart';
import 'package:k4afa/services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(BookLibraryApp());
}

class BookLibraryApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const SplashScreen(),
      routes: {
        '/login': (context) => login.LoginScreen(),
        '/signup': (context) => signup.SignUpScreen(),
        '/home': (context) => const HomeScreen(),
        '/app_initializer': (context) => AppInitializer(),
        '/pending': (context) => PendingScreen(),
        '/rejected': (context) => RejectedScreen(),
      },
    );
  }
}

class AppInitializer extends StatefulWidget {
  @override
  _AppInitializerState createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text('Error: ${snapshot.error}'),
            ),
          );
        }

        if (snapshot.hasData) {
          return FutureBuilder<Map<String, dynamic>?>(
            future: _authService.getUserData(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (userSnapshot.hasError || userSnapshot.data == null) {
                _authService.signOut();
                return login.LoginScreen();
              }

              String status = userSnapshot.data!['status'] ?? 'pending';
              if (status == 'pending') {
                return PendingScreen();
              } else if (status == 'rejected') {
                _authService.signOut();
                return login.LoginScreen();
              } else if (status == 'approved') {
                return const HomeScreen();
              } else {
                _authService.signOut();
                return login.LoginScreen();
              }
            },
          );
        } else {
          return login.LoginScreen();
        }
      },
    );
  }
}