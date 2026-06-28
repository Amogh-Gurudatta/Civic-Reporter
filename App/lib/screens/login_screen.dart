import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart' show AppColors;
import '../widgets/scale_interactive_widget.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isSignUp = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      if (_isSignUp) {
        final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        
        final user = userCredential.user;
        if (user != null) {
          try {
            await user.updateDisplayName(_nameController.text.trim());
          } catch (_) {}
          try {
            await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
              'name': _nameController.text.trim(),
              'email': email,
              'karma': 0,
            }, SetOptions(merge: true));
          } catch (_) {}
        }
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'An error occurred during authentication.';
      
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found for this email address.';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password provided.';
          break;
        case 'invalid-email':
          errorMessage = 'The email address is invalid.';
          break;
        case 'user-disabled':
          errorMessage = 'This user account has been disabled.';
          break;
        case 'email-already-in-use':
          errorMessage = 'An account already exists for this email.';
          break;
        case 'weak-password':
          errorMessage = 'The password provided is too weak.';
          break;
        case 'invalid-credential':
          errorMessage = 'Invalid login credentials details.';
          break;
        default:
          if (e.message != null) {
            errorMessage = e.message!;
          }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(errorMessage)),
              ],
            ),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController(text: _emailController.text.trim());
    final dialogFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Reset Password',
            style: TextStyle(color: AppColors.navyBlue, fontWeight: FontWeight.bold),
          ),
          content: Form(
            key: dialogFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Enter your registered email address below, and we will send you a password reset link.',
                  style: TextStyle(color: AppColors.textMid, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: resetEmailController,
                  keyboardType: TextInputType.emailAddress,
                  autofocus: true,
                  style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w500),
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.email, color: AppColors.navyBlue),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value.trim())) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textMid)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!dialogFormKey.currentState!.validate()) return;
                final email = resetEmailController.text.trim();
                try {
                  await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                            SizedBox(width: 12),
                            Expanded(child: Text('Password reset email sent!')),
                          ],
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } on FirebaseAuthException catch (e) {
                  String errorMessage = 'Error: ${e.message ?? e.code}';
                  if (e.code == 'user-not-found') {
                    errorMessage = 'No user found for this email address.';
                  } else if (e.code == 'invalid-email') {
                    errorMessage = 'The email address is invalid.';
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.white, size: 20),
                            SizedBox(width: 12),
                            Expanded(child: Text(errorMessage)),
                          ],
                        ),
                        backgroundColor: AppColors.danger,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: AppColors.danger,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navyBlue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Send Reset Link'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 600;

    return Scaffold(
      backgroundColor: AppColors.bgGray,
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: isDesktop ? 450 : double.infinity,
            padding: const EdgeInsets.all(32.0),
            margin: isDesktop ? const EdgeInsets.all(24.0) : EdgeInsets.zero,
            decoration: isDesktop
                ? BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      )
                    ],
                  )
                : null,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // App Emblem
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.navyBlue.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shield_rounded,
                        size: 56,
                        color: AppColors.navyBlue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Welcome Header
                  const Center(
                    child: Text(
                      "Welcome to Civic Reporter",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: AppColors.navyBlue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Center(
                    child: Text(
                      'Official Citizen Incident & Hazard Portal',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMid,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Name Input Field (only visible when signing up)
                  if (_isSignUp) ...[
                    TextFormField(
                      controller: _nameController,
                      keyboardType: TextInputType.name,
                      style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: const Icon(Icons.person, color: AppColors.navyBlue),
                        filled: true,
                        fillColor: isDesktop ? AppColors.bgGray.withValues(alpha: 0.5) : Colors.white,
                      ),
                      validator: (value) {
                        if (_isSignUp && (value == null || value.trim().isEmpty)) {
                          return 'Please enter your full name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),
                  ],

                  // Email Input Field
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: const Icon(Icons.email, color: AppColors.navyBlue),
                      filled: true,
                      fillColor: isDesktop ? AppColors.bgGray.withValues(alpha: 0.5) : Colors.white,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value.trim())) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),

                  // Password Input Field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock, color: AppColors.navyBlue),
                      filled: true,
                      fillColor: isDesktop ? AppColors.bgGray.withValues(alpha: 0.5) : Colors.white,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your password';
                      }
                      if (value.trim().length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  if (!_isSignUp) ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _showForgotPasswordDialog,
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: AppColors.navyLight,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),

                  // Submit Button
                  ScaleInteractiveWidget(
                    onTap: _isLoading ? null : _submit,
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.navyBlue,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.navyBlue.withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      alignment: Alignment.center,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              _isSignUp ? 'Create Official Account' : 'Sign In',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Toggle Switch
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isSignUp = !_isSignUp;
                      });
                    },
                    child: Text(
                      _isSignUp ? 'Already have an account? Sign In' : 'Need an official account? Sign Up',
                      style: const TextStyle(
                        color: AppColors.navyLight,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
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
}
