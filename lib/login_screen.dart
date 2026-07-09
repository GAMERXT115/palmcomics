import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:local_auth/local_auth.dart';
import 'main.dart';
import 'downloads.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _canCheckBiometrics = false;
  bool _hasPreviousLogin = false;
  bool _isSignUp = true;
  bool _isAuthenticating = false;
  String _loadingType = "";

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final bool canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
    final bool canAuthenticate = canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();
    
    setState(() {
      _hasPreviousLogin = prefs.getBool('has_logged_in') ?? false;
      _isSignUp = !_hasPreviousLogin;
      _canCheckBiometrics = canAuthenticate;
    });

    if (_hasPreviousLogin && _canCheckBiometrics) {
      _authenticateWithBiometrics();
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isAuthenticating = true;
      _loadingType = "biometric";
    });

    try {
      bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to login',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (didAuthenticate && mounted) {
        final provider = Provider.of<ComicProvider>(context, listen: false);
        await provider.fetchServerIp();
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
          _loadingType = "";
        });
      }
    }
  }

  Future<void> _saveLoginFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_logged_in', true);
  }

  Future<void> _handleAuth() async {
    HapticFeedback.mediumImpact();
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isAuthenticating = true;
        _loadingType = "email";
      });

      try {
        if (_isSignUp) {
          if (_passwordController.text != _confirmPasswordController.text) {
            _showError("Passwords do not match");
            setState(() {
              _isAuthenticating = false;
              _loadingType = "";
            });
            return;
          }
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );
        } else {
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );
        }
        
        await _saveLoginFlag();
        if (mounted) {
          final provider = Provider.of<ComicProvider>(context, listen: false);
          await provider.fetchServerIp();
          Navigator.of(context).pushReplacementNamed('/home');
        }
      } catch (e) {
        _showError(e.toString());
      } finally {
        if (mounted) {
          setState(() {
            _isAuthenticating = false;
            _loadingType = "";
          });
        }
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isAuthenticating = true;
      _loadingType = "google";
    });

    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      final GoogleSignInAuthentication? googleAuth = await googleUser?.authentication;

      if (googleAuth != null) {
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await FirebaseAuth.instance.signInWithCredential(credential);
        await _saveLoginFlag();
        if (mounted) {
          final provider = Provider.of<ComicProvider>(context, listen: false);
          await provider.fetchServerIp();
          Navigator.of(context).pushReplacementNamed('/home');
        }
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
          _loadingType = "";
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFEB3B),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.black, width: 4),
                      boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(8, 8))],
                    ),
                    child: Text(
                      _isSignUp ? "SIGN UP" : "LOGIN",
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.black, width: 3),
                    ),
                    child: TextFormField(
                      controller: _emailController,
                      enabled: !_isAuthenticating,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        hintText: "EMAIL",
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: InputBorder.none,
                      ),
                      validator: (value) => value!.isEmpty ? 'Enter email' : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.black, width: 3),
                    ),
                    child: TextFormField(
                      controller: _passwordController,
                      enabled: !_isAuthenticating,
                      obscureText: true,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        hintText: "PASSWORD",
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: InputBorder.none,
                      ),
                      validator: (value) => value!.isEmpty ? 'Enter password' : null,
                    ),
                  ),
                  if (_isSignUp) ...[
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.black, width: 3),
                      ),
                      child: TextFormField(
                        controller: _confirmPasswordController,
                        enabled: !_isAuthenticating,
                        obscureText: true,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          hintText: "CONFIRM PASSWORD",
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: InputBorder.none,
                        ),
                        validator: (value) => value!.isEmpty ? 'Confirm password' : null,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Opacity(
                    opacity: _isAuthenticating ? 0.6 : 1.0,
                    child: GestureDetector(
                      onTap: _isAuthenticating ? null : _handleAuth,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF5252),
                          border: Border.all(color: Colors.black, width: 3),
                          boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(4, 4))],
                        ),
                        child: Center(
                          child: _isAuthenticating && _loadingType == "email"
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                                )
                              : Text(
                                  _isSignUp ? "SIGN UP" : "LOGIN",
                                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Opacity(
                    opacity: _isAuthenticating ? 0.6 : 1.0,
                    child: GestureDetector(
                      onTap: _isAuthenticating ? null : _signInWithGoogle,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.black, width: 3),
                          boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(4, 4))],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _isAuthenticating && _loadingType == "google"
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(color: Colors.black, strokeWidth: 3),
                                  )
                                : Image.network(
                                    'https://www.gstatic.com/images/branding/product/2x/googleg_48dp.png',
                                    height: 24,
                                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.g_mobiledata, color: Colors.black),
                                  ),
                            if (!(_isAuthenticating && _loadingType == "google")) ...[
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                  _isSignUp ? "SIGN UP WITH GOOGLE" : "LOGIN WITH GOOGLE",
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w900),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _isAuthenticating ? null : () {
                      HapticFeedback.lightImpact();
                      setState(() => _isSignUp = !_isSignUp);
                    },
                    child: Text(
                      _isSignUp ? "ALREADY HAVE AN ACCOUNT? LOGIN" : "NEED AN ACCOUNT? SIGN UP",
                      style: TextStyle(
                        color: _isAuthenticating ? Colors.black38 : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (!_isSignUp && _hasPreviousLogin && _canCheckBiometrics) ...[
                    const SizedBox(height: 24),
                    Opacity(
                      opacity: _isAuthenticating ? 0.6 : 1.0,
                      child: Column(
                        children: [
                          _isAuthenticating && _loadingType == "biometric"
                              ? const CircularProgressIndicator(color: Colors.black)
                              : IconButton(
                                  icon: const Icon(Icons.fingerprint, size: 60, color: Colors.black),
                                  onPressed: _isAuthenticating ? null : _authenticateWithBiometrics,
                                ),
                          const Text("QUICK SIGN IN", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                  if (_hasPreviousLogin) ...[
                    const SizedBox(height: 40),
                    Opacity(
                      opacity: _isAuthenticating ? 0.4 : 1.0,
                      child: GestureDetector(
                        onTap: _isAuthenticating ? null : () {
                          HapticFeedback.mediumImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const DownloadsScreen()),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: const [BoxShadow(color: Colors.black45, offset: Offset(4, 4))],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.download_done_rounded, color: Colors.white, size: 20),
                              SizedBox(width: 10),
                              Text(
                                "VIEW OFFLINE COMICS",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
