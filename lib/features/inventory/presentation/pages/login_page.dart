import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:grid_storage_nfc/features/inventory/presentation/bloc/auth/auth_bloc.dart';
import 'package:grid_storage_nfc/features/inventory/presentation/pages/main_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isHomeMode = false;
  bool _isLoadingFlavor = true;

  // --- DODANE: Zmienna sterująca widocznością hasła ---
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _checkFlavor();
  }

  Future<void> _checkFlavor() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final packageName = packageInfo.packageName;

    if (mounted) {
      setState(() {
        _isHomeMode = packageName.endsWith('.home') ||
            packageName == 'com.pryhodskyimykola.gridstorage';
        _isLoadingFlavor = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onLoginPressed() {
    if (_isHomeMode) {
      context.read<AuthBloc>().add(const LoginRequested());
    } else {
      if (_formKey.currentState!.validate()) {
        FocusScope.of(context).unfocus();
        context.read<AuthBloc>().add(
              LoginRequested(
                email: _emailController.text.trim(),
                password: _passwordController.text,
              ),
            );
      }
    }
  }

  void _onPasswordResetPressed() {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text("Enter a valid email address to request a password reset."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    context.read<AuthBloc>().add(PasswordChangeRequested(email));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is Authenticated) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const MainPage()),
            );
          } else if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(state.message), backgroundColor: Colors.red),
            );
          } else if (state is PasswordChangeSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(state.message), backgroundColor: Colors.green),
            );
          }
        },
        builder: (context, state) {
          if (_isLoadingFlavor || state is AuthLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(_isHomeMode ? Icons.home_filled : Icons.business,
                        size: 80,
                        color: _isHomeMode ? Colors.orange : Colors.blue),
                    const SizedBox(height: 20),
                    Text(
                      _isHomeMode ? "Grid Storage HOME" : "Grid Storage OFFICE",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isHomeMode
                          ? "Sign in with your Google account"
                          : "Sign in to corporate QNAP server",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 40),
                    if (_isHomeMode) ...[
                      ElevatedButton.icon(
                        onPressed: _onLoginPressed,
                        icon: const Icon(Icons.login),
                        label: const Text("Sign in with Google"),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ] else ...[
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) =>
                            v!.isEmpty ? 'Please enter email' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          // --- DODANE: Przycisk z oczkiem ---
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        // --- ZMIENIONE: Zamiast sztywnego "true", używamy naszej zmiennej ---
                        obscureText: _obscurePassword,
                        validator: (v) =>
                            v!.isEmpty ? 'Please enter password' : null,
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _onLoginPressed,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text("Sign In"),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _onPasswordResetPressed,
                        child: const Text(
                            "Forgot password? Request reset from admin"),
                      )
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
