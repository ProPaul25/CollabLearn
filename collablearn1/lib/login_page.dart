// lib/login_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collablearn1/register_page.dart';
import 'package:collablearn1/email_verification_page.dart'; // ADDED Import

class LoginPage extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  const LoginPage({
    super.key,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- Email/Password Login Function (UPDATED for Verification Check) ---
  Future<void> _login() async {
    final loginIdentifier = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (loginIdentifier.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your credentials and password.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String emailToLogin;
      final bool isEmail = loginIdentifier.contains('@');

      if (isEmail) {
        emailToLogin = loginIdentifier;
      } else {
        // Query the PUBLIC 'user_lookups' collection for ID/Entry No login
        final lookupDoc = await FirebaseFirestore.instance
            .collection('user_lookups')
            .doc(loginIdentifier)
            .get();

        if (lookupDoc.exists) {
          emailToLogin = lookupDoc.data()!['email'] as String;
        } else {
          // If no user was found, the credentials are invalid.
          throw FirebaseAuthException(code: 'user-not-found');
        }
      }

      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailToLogin,
        password: password,
      );
      
      final user = userCredential.user;

      // === NEW: VERIFICATION CHECK ===
      if (user != null && !user.emailVerified) {
        // If user logged in but email is NOT verified, sign them out and redirect
        await FirebaseAuth.instance.signOut();
        
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Your email is not verified. Redirecting to verification screen.'), 
                    backgroundColor: Colors.orange
                ),
            );
            // Redirect to EmailVerificationPage
            Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (context) => EmailVerificationPage(
                        onToggleTheme: widget.onToggleTheme,
                        isDarkMode: widget.isDarkMode
                    ),
                ),
            );
        }
        return; // Stop login process
      }
      // === END VERIFICATION CHECK ===


    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential' || e.code == 'invalid-email') {
        message = 'Invalid credentials. Please check your details and try again.';
      } else {
        message = 'An unexpected error occurred. Please try again.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } 
    finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- Forgot Password Function (unchanged) ---
  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter your Email or Entry No in the field above.'), backgroundColor: Colors.orange),
        );
      }
      return;
    }
    
    setState(() => _isLoading = true); 

    try {
      String emailToReset;
      if (!email.contains('@')) {
        final lookupDoc = await FirebaseFirestore.instance
            .collection('user_lookups')
            .doc(email)
            .get();
        if (lookupDoc.exists) {
          emailToReset = lookupDoc.data()!['email'] as String;
        } else {
          throw FirebaseAuthException(code: 'user-not-found');
        }
      } else {
        emailToReset = email;
      }

      await FirebaseAuth.instance.sendPasswordResetEmail(email: emailToReset);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password reset link sent to $emailToReset!'), 
            backgroundColor: Colors.green
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'user-not-found') {
        message = 'No user found with that ID or email.';
      } else {
        message = e.message ?? 'Failed to send reset email. Please try again.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An unexpected error occurred.'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    const String backgroundImage = 'assets/background.jpg';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode, color: Theme.of(context).colorScheme.primary),
            onPressed: widget.onToggleTheme,
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage(backgroundImage),
            fit: BoxFit.cover,
            colorFilter: isDark ? ColorFilter.mode(Colors.black.withOpacity(0.6), BlendMode.darken) : null,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/logo.png', height: 200),
                  const SizedBox(height: 50),
                  Card(
                    color: isDark ? const Color(0xFF1C2239) : Colors.white,
                    elevation: 5,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 40.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Login.', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                          const SizedBox(height: 30),
                          _buildTextField(
                            controller: _emailController,
                            hintText: 'Email ID', 
                            prefixIcon: Icons.person_outline,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 20),
                          _buildPasswordField(context),
                          
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _isLoading ? null : _resetPassword,
                                child: Text('Forgot Password?', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary.withOpacity(0.8))),
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Log In'),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text("You don't have an account? ", style: TextStyle(color: Theme.of(context).textTheme.bodyMedium!.color)),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    PageRouteBuilder(
                                      // PASSED THEME PROPS TO RegisterPage
                                      pageBuilder: (context, animation, secondaryAnimation) => RegisterPage(
                                        onToggleTheme: widget.onToggleTheme,
                                        isDarkMode: widget.isDarkMode,
                                      ),
                                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                        const begin = Offset(1.0, 0.0);
                                        const end = Offset.zero;
                                        const curve = Curves.ease;
                                        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                                        return SlideTransition(position: animation.drive(tween), child: child);
                                      },
                                    ),
                                  );
                                },
                                child: Text('Sign Up', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: BoxDecoration(color: isDark ? const Color(0xFF2A314D) : const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(15)),
      child: TextField(
        controller: _passwordController,
        obscureText: !_isPasswordVisible,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _login(),
        decoration: InputDecoration(
          hintText: 'Password',
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
          prefixIcon: Icon(Icons.lock_outline, color: primaryColor),
          suffixIcon: IconButton(
            icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: primaryColor),
            onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
          ),
          border: InputBorder.none,
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: primaryColor)),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: BoxDecoration(color: isDark ? const Color(0xFF2A314D) : const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(15)),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hintText,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
          prefixIcon: Icon(prefixIcon, color: primaryColor),
          border: InputBorder.none,
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: primaryColor)),
        ),
      ),
    );
  }
}