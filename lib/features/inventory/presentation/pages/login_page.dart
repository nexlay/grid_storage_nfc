import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:grid_storage_nfc/features/inventory/presentation/bloc/auth/auth_bloc.dart';
import 'package:grid_storage_nfc/features/inventory/presentation/pages/all_items_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Kontrolery tylko dla trybu Office (Email/Hasło)
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Flaga trybu
  bool _isHomeMode = false;
  bool _isLoadingFlavor = true;

  @override
  void initState() {
    super.initState();
    _checkFlavor();
  }

  // Sprawdzamy wersję aplikacji (Home vs Office)
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
      // HOME: Logowanie Google (bez parametrów)
      context.read<AuthBloc>().add(const LoginRequested());
    } else {
      // OFFICE: Logowanie Email/Hasło
      if (_formKey.currentState!.validate()) {
        FocusScope.of(context).unfocus(); // Schowaj klawiaturę
        context.read<AuthBloc>().add(
              LoginRequested(
                email: _emailController.text.trim(),
                password: _passwordController.text,
              ),
            );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is Authenticated) {
            // SUKCES: Przechodzimy do głównej listy
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const AllItemsPage()),
            );
          } else if (state is AuthError) {
            // BŁĄD: Pokazujemy pasek na dole
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (context, state) {
          // 1. Ładowanie (sprawdzanie wersji lub logowanie)
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
                    // --- NAGŁÓWEK (Wspólny) ---
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
                          ? "Zaloguj się przez Google"
                          : "Zaloguj się do serwera QNAP",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 40),

                    // --- FORMULARZ (Zależny od trybu) ---
                    if (_isHomeMode) ...[
                      // WIDOK DLA HOME (Tylko przycisk Google)
                      ElevatedButton.icon(
                        onPressed: _onLoginPressed,
                        icon: const Icon(Icons.login),
                        label: const Text("Zaloguj przez Google"),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ] else ...[
                      // WIDOK DLA OFFICE (Pola tekstowe)
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => v!.isEmpty ? 'Podaj email' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Hasło',
                          prefixIcon: Icon(Icons.lock_outline),
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                        validator: (v) => v!.isEmpty ? 'Podaj hasło' : null,
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _onLoginPressed,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text("Zaloguj się"),
                      ),
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
