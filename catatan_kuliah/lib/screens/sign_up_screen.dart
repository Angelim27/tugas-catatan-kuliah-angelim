import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  void _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    setState(() => _isLoading = true);

    try {
      // 1. Buat User di Firebase Auth
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 2. Simpan Data Tambahan di Firestore
      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'fullName': _fullNameController.text.trim(),
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: Colors.green, content: Text('Akun berhasil dibuat!')),
        );
        // Kembali ke halaman Sign In setelah pendaftaran sukses
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (error) {
      _showErrorMessage(_getAuthErrorMessage(error.code));
    } catch (error) {
      _showErrorMessage('Gagal membuat akun: ${error.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use': return 'Email sudah digunakan oleh akun lain.';
      case 'invalid-email': return 'Format email tidak valid.';
      case 'weak-password': return 'Kata sandi terlalu lemah. Gunakan minimal 6 karakter.';
      default: return 'Terjadi kesalahan. Silakan coba lagi.';
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Akun Baru'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_add, size: 80, color: Colors.deepPurple.shade400),
                const SizedBox(height: 24),
                
                // Input Nama Lengkap
                TextFormField(
                  controller: _fullNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nama Lengkap',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) => (value == null || value.isEmpty) ? 'Silakan masukkan nama Anda' : null,
                ),
                const SizedBox(height: 16.0),
                
                // Input Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Alamat Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty || !value.contains('@')) {
                      return 'Silakan masukkan email yang valid';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16.0),
                
                // Input Password
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'Kata Sandi (Password)',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                    ),
                  ),
                  validator: (value) => (value != null && value.length < 6) ? 'Kata sandi minimal 6 karakter' : null,
                ),
                const SizedBox(height: 16.0),
                
                // Input Konfirmasi Password
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: !_isConfirmPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'Konfirmasi Kata Sandi',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_clock),
                    suffixIcon: IconButton(
                      icon: Icon(_isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                    ),
                  ),
                  validator: (value) => (value != _passwordController.text) ? 'Kata sandi tidak cocok' : null,
                ),
                const SizedBox(height: 24.0),
                
                // Tombol Submit - Loading Indicator
                _isLoading
                    ? const CircularProgressIndicator()
                    : SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _signUp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'DAFTAR',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}