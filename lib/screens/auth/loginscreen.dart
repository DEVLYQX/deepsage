import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../chat_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  String? _twoFactorToken;
  String? _email;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter both email and password'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Basic email validation
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a valid email address'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _authService.signIn(email, password);

      if (result['requiresTwoFactor'] == true) {
        setState(() {
          _twoFactorToken = result['twoFactorToken'];
          _email = _emailController.text;
        });
        // Show 2FA input dialog
        _show2FADialog();
      } else {
        // Navigate to chat screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(threadId: 'default-thread-id'),
          ),
        );
      }
    } catch (e) {
      String errorMessage = 'Login failed';

      // Parse error message for better user experience
      if (e.toString().contains('Invalid email')) {
        errorMessage = 'Please enter a valid email address';
      } else if (e.toString().contains('email should not be empty')) {
        errorMessage = 'Email field cannot be empty';
      } else if (e.toString().contains('password')) {
        errorMessage = 'Invalid password';
      } else if (e.toString().contains('Validation failed')) {
        errorMessage = 'Please check your email and password';
      } else {
        errorMessage = e.toString().replaceAll('Exception: ', '');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _show2FADialog() {
    final _codeController = TextEditingController();
    String _selectedMethod = 'authenticator';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Two-Factor Authentication'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Please enter your verification code'),
                  SizedBox(height: 16),
                  TextField(
                    controller: _codeController,
                    decoration: InputDecoration(
                      labelText: 'Verification Code',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: 16),
                  DropdownButton<String>(
                    value: _selectedMethod,
                    isExpanded: true,
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setDialogState(() {
                          _selectedMethod = newValue;
                        });
                      }
                    },
                    items: <String>['authenticator', 'email', 'backup']
                        .map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value.capitalize()),
                          );
                        })
                        .toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    if (_codeController.text.isEmpty) {
                      return;
                    }

                    Navigator.pop(context);
                    setState(() {
                      _isLoading = true;
                    });

                    try {
                      await _authService.verifyTwoFactor(
                        _twoFactorToken!,
                        _codeController.text,
                        _selectedMethod,
                      );

                      // Navigate to chat screen
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ChatScreen(threadId: 'default-thread-id'),
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('2FA verification failed: $e')),
                      );
                      setState(() {
                        _isLoading = false;
                      });
                    }
                  },
                  child: Text('Verify'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Deepsage Chat Demo')),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                  ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _login,
                    child: Text('Login'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 50),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// Extension to capitalize strings
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}
