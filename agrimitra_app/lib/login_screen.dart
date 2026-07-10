import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';
import 'theme.dart';
import 'widgets/agriculture_background.dart';
import 'widgets/plant_growth_loader.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();
  final farmNameController = TextEditingController();

  bool isRegisterMode = false;
  bool isLoading = false;
  String? errorMessage;

  final String baseUrl = "http://localhost:5000/api/auth";

  // Focus nodes
  final phoneFocus = FocusNode();
  final passwordFocus = FocusNode();
  final nameFocus = FocusNode();
  final farmNameFocus = FocusNode();
  bool _obscurePassword = true;

  // Animations
  late AnimationController _phoneGlowController;
  late AnimationController _passwordGlowController;
  late AnimationController _buttonScaleController;
  late Animation<double> _phoneGlowAnimation;
  late Animation<double> _passwordGlowAnimation;
  late Animation<double> _buttonScaleAnimation;
  late Animation<double> _buttonShadowAnimation;

  // Animated icon controllers
  late AnimationController _phoneIconController;
  late AnimationController _passwordIconController;
  late Animation<double> _phoneIconBounce;
  late Animation<double> _passwordIconBounce;
  late Animation<double> _lockRotateAnimation;

  @override
  void initState() {
    super.initState();

    // Focus listeners
    phoneFocus.addListener(() {
      if (phoneFocus.hasFocus) {
        _phoneGlowController.forward();
        _phoneIconController.forward();
      } else {
        _phoneGlowController.reverse();
        _phoneIconController.reverse();
      }
    });

    passwordFocus.addListener(() {
      if (passwordFocus.hasFocus) {
        _passwordGlowController.forward();
        _passwordIconController.forward();
      } else {
        _passwordGlowController.reverse();
        _passwordIconController.reverse();
      }
    });

    // Phone field glow
    _phoneGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _phoneGlowAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _phoneGlowController, curve: Curves.easeInOut),
    );

    // Password field glow
    _passwordGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _passwordGlowAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _passwordGlowController, curve: Curves.easeInOut),
    );

    // Button animations
    _buttonScaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _buttonScaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _buttonScaleController, curve: Curves.easeInOut),
    );
    _buttonShadowAnimation = Tween<double>(begin: 8, end: 2).animate(
      CurvedAnimation(parent: _buttonScaleController, curve: Curves.easeInOut),
    );

    // Phone icon bounce
    _phoneIconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _phoneIconBounce = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _phoneIconController, curve: Curves.elasticOut),
    );

    // Password icon bounce
    _passwordIconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _passwordIconBounce = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _passwordIconController, curve: Curves.elasticOut),
    );

    // Lock rotation
    _lockRotateAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _passwordIconController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    phoneController.dispose();
    passwordController.dispose();
    nameController.dispose();
    farmNameController.dispose();
    phoneFocus.dispose();
    passwordFocus.dispose();
    nameFocus.dispose();
    farmNameFocus.dispose();
    _phoneGlowController.dispose();
    _passwordGlowController.dispose();
    _buttonScaleController.dispose();
    _phoneIconController.dispose();
    _passwordIconController.dispose();
    super.dispose();
  }

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

  InputDecoration _phoneFieldDecoration() {
    return InputDecoration(
      labelText: 'Phone number',
      prefixIcon: AnimatedBuilder(
        animation: _phoneIconBounce,
        builder: (context, child) {
          return Transform.scale(
            scale: 0.8 + 0.2 * _phoneIconBounce.value,
            child: Icon(
              Icons.phone_android_rounded,
              color: phoneFocus.hasFocus
                  ? AgriMitraColors.primary
                  : AgriMitraColors.inkMuted,
            ),
          );
        },
      ),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE7E2D3), width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE7E2D3), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AgriMitraColors.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  InputDecoration _passwordFieldDecoration() {
    return InputDecoration(
      labelText: 'Password',
      prefixIcon: AnimatedBuilder(
        animation: _passwordIconBounce,
        builder: (context, child) {
          final rotation = _lockRotateAnimation.value;
          return Transform.scale(
            scale: 0.8 + 0.2 * _passwordIconBounce.value,
            child: Transform.rotate(
              angle: rotation * 0.1,
              child: Icon(
                _obscurePassword
                    ? Icons.lock_outline_rounded
                    : Icons.lock_open_rounded,
                color: passwordFocus.hasFocus
                    ? AgriMitraColors.primary
                    : AgriMitraColors.inkMuted,
              ),
            ),
          );
        },
      ),
      suffixIcon: GestureDetector(
        onTap: () => setState(() => _obscurePassword = !_obscurePassword),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, anim) => ScaleTransition(
            scale: anim,
            child: child,
          ),
          child: Icon(
            _obscurePassword
                ? Icons.visibility_off_rounded
                : Icons.visibility_rounded,
            key: ValueKey(_obscurePassword),
            color: AgriMitraColors.inkMuted,
            size: 22,
          ),
        ),
      ),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE7E2D3), width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE7E2D3), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AgriMitraColors.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildAnimatedField({
    required Widget child,
    required Animation<double> glowAnim,
    required FocusNode focusNode,
  }) {
    return AnimatedBuilder(
      animation: glowAnim,
      builder: (context, _) {
        final glow = glowAnim.value;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AgriMitraColors.primary.withValues(alpha: 0.12 * glow),
                blurRadius: 12 * glow,
                spreadRadius: 2 * glow,
                offset: Offset(0, 2 * glow),
              ),
            ],
          ),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          isRegisterMode ? 'Register' : 'Login',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: AgricultureBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo / Brand
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AgriMitraColors.primary.withValues(alpha: 0.25),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.eco_rounded,
                    size: 36,
                    color: AgriMitraColors.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'AgriMitra',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.5,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isRegisterMode
                      ? 'Create your farmer account'
                      : 'Welcome back, farmer',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 32),

                // Card container
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 400),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: AgriMitraColors.primary.withValues(alpha: 0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (isRegisterMode) ...[
                        _buildAnimatedField(
                          glowAnim: _phoneGlowAnimation,
                          focusNode: nameFocus,
                          child: TextField(
                            controller: nameController,
                            focusNode: nameFocus,
                            decoration: InputDecoration(
                              labelText: 'Full name',
                              prefixIcon: Icon(
                                Icons.person_outline_rounded,
                                color: nameFocus.hasFocus
                                    ? AgriMitraColors.primary
                                    : AgriMitraColors.inkMuted,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE7E2D3),
                                  width: 1.5,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE7E2D3),
                                  width: 1.5,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: AgriMitraColors.primary,
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildAnimatedField(
                          glowAnim: _phoneGlowAnimation,
                          focusNode: farmNameFocus,
                          child: TextField(
                            controller: farmNameController,
                            focusNode: farmNameFocus,
                            decoration: InputDecoration(
                              labelText: 'Farm name (optional)',
                              prefixIcon: Icon(
                                Icons.agriculture_rounded,
                                color: farmNameFocus.hasFocus
                                    ? AgriMitraColors.primary
                                    : AgriMitraColors.inkMuted,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE7E2D3),
                                  width: 1.5,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE7E2D3),
                                  width: 1.5,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: AgriMitraColors.primary,
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Phone field
                      _buildAnimatedField(
                        glowAnim: _phoneGlowAnimation,
                        focusNode: phoneFocus,
                        child: TextField(
                          controller: phoneController,
                          focusNode: phoneFocus,
                          keyboardType: TextInputType.phone,
                          decoration: _phoneFieldDecoration(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Password field
                      _buildAnimatedField(
                        glowAnim: _passwordGlowAnimation,
                        focusNode: passwordFocus,
                        child: TextField(
                          controller: passwordController,
                          focusNode: passwordFocus,
                          obscureText: _obscurePassword,
                          decoration: _passwordFieldDecoration(),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Error message
                      if (errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: AgriMitraColors.critical.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AgriMitraColors.critical.withValues(alpha: 0.2),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  size: 18,
                                  color: AgriMitraColors.critical,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    errorMessage!,
                                    style: TextStyle(
                                      color: AgriMitraColors.critical,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Login / Register button
                      isLoading
                          ? PlantGrowthLoader(
                              isActive: isLoading,
                            )
                          : GestureDetector(
                              onTapDown: (_) => _buttonScaleController.forward(),
                              onTapUp: (_) => _buttonScaleController.reverse(),
                              onTapCancel: () =>
                                  _buttonScaleController.reverse(),
                              onTap: submit,
                              child: AnimatedBuilder(
                                animation: _buttonScaleController,
                                builder: (context, child) {
                                  return Transform.scale(
                                    scale: _buttonScaleAnimation.value,
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 150),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            AgriMitraColors.primary,
                                            AgriMitraColors.primary
                                                .withValues(alpha: 0.85),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AgriMitraColors.primary
                                                .withValues(alpha: 0.25),
                                            blurRadius:
                                                _buttonShadowAnimation.value,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Text(
                                          isRegisterMode ? 'Register' : 'Login',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Toggle register/login
                TextButton(
                  onPressed: () => setState(() {
                    isRegisterMode = !isRegisterMode;
                    errorMessage = null;
                  }),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    isRegisterMode
                        ? 'Already have an account? Login'
                        : 'New farmer? Register here',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
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


