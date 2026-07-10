import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();
  final farmNameController = TextEditingController();

  bool isRegisterMode = false;
  bool isLoading = false;
  String? errorMessage;

  final String baseUrl = "http://localhost:5000/api/auth";

  Future<void> submit() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      if (isRegisterMode) {
        final response = await http.post(
          Uri.parse('$baseUrl/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'name': nameController.text.trim(),
            'phone': phoneController.text.trim(),
            'password': passwordController.text,
            'farmName': farmNameController.text.trim(),
          }),
        );

        if (response.statusCode == 201) {
          setState(() {
            isRegisterMode = false;
            errorMessage = "Registered! Now log in below.";
          });
        } else {
          final data = jsonDecode(response.body);
          setState(() => errorMessage = data['message'] ?? 'Registration failed');
        }
      } else {
        final response = await http.post(
          Uri.parse('$baseUrl/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'phone': phoneController.text.trim(),
            'password': passwordController.text,
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', data['token']);
          await prefs.setString('farmerName', data['farmer']['name']);

          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
          );
        } else {
          final data = jsonDecode(response.body);
          setState(() => errorMessage = data['message'] ?? 'Login failed');
        }
      }
    } catch (e) {
      setState(() => errorMessage = "Error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isRegisterMode ? 'Register' : 'Login')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('AgriMitra', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green)),
              const SizedBox(height: 24),
              if (isRegisterMode) ...[
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: farmNameController,
                  decoration: const InputDecoration(labelText: 'Farm name (optional)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone number', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(errorMessage!, style: const TextStyle(color: Colors.red)),
                ),
              isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: submit,
                      child: Text(isRegisterMode ? 'Register' : 'Login'),
                    ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => setState(() {
                  isRegisterMode = !isRegisterMode;
                  errorMessage = null;
                }),
                child: Text(isRegisterMode
                    ? 'Already have an account? Login'
                    : 'New farmer? Register here'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}