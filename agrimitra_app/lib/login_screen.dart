import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  final phoneFocus = FocusNode();
  final passwordFocus = FocusNode();
  final nameFocus = FocusNode();
  final farmNameFocus = FocusNode();
  bool _obscurePassword = true;

  // Glow animations
  late AnimationController _phoneGlowController;
  late AnimationController _passwordGlowController;
  late Animation<double> _phoneGlowAnimation;
  late Animation<double> _passwordGlowAnimation;

  // Button animations
  late AnimationController _buttonScaleController;
  late Animation<double> _buttonScaleAnimation;
  late Animation<double> _buttonShadowAnimation;

  // Icon bounce animations
  late AnimationController _phoneIconController;
  late AnimationController _passwordIconController;
  late Animation<double> _phoneIconBounce;
  late Animation<double> _passwordIconBounce;
  late Animation<double> _lockRotateAnimation;

  // === ENTRANCE ANIMATIONS ===
  late AnimationController _entranceController;
  late Animation<double> _bgFadeAnim;
  late Animation<double> _logoScaleAnim;
  late Animation<double> _logoFadeAnim;
  late Animation<double> _welcomeFadeAnim;
  late Animation<Offset> _cardSlideAnim;
  late Animation<double> _cardFadeAnim;
  late Animation<double> _field1FadeAnim;
  late Animation<double> _field2FadeAnim;
  late Animation<double> _field3FadeAnim;
  late Animation<double> _field4FadeAnim;
  late Animation<double> _buttonEntranceAnim;
  late Animation<double> _toggleFadeAnim;

  // Logo pulse
  late AnimationController _logoPulseController;
  late Animation<double> _logoPulseAnimation;

  // Register text interactions
  bool _registerHovered = false;
  late AnimationController _registerTapController;
  late Animation<double> _registerTapScale;

  @override
  void initState() {
    super.initState();
    _initEntranceAnimations();
    _initGlowAnimations();
    _initButtonAnimations();
    _initIconAnimations();
    _initLogoPulse();
    _initRegisterTap();
    _initFocusListeners();
    _entranceController.forward();
  }

  void _initEntranceAnimations() {
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    final curve = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );

    _bgFadeAnim = Tween<double>(begin: 0, end: 1).animate(
      Tween<double>(begin: 0, end: 0.3).animate(curve),
    );

    _logoScaleAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
      ),
    );

    _logoFadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    _welcomeFadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.15, 0.55, curve: Curves.easeOut),
      ),
    );

    _cardSlideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.2, 0.65, curve: Curves.easeOutCubic),
      ),
    );

    _cardFadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.2, 0.6, curve: Curves.easeOut),
      ),
    );

    _field1FadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.3, 0.65, curve: Curves.easeOut),
      ),
    );

    _field2FadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.38, 0.72, curve: Curves.easeOut),
      ),
    );

    _field3FadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.46, 0.78, curve: Curves.easeOut),
      ),
    );

    _field4FadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.54, 0.84, curve: Curves.easeOut),
      ),
    );

    _buttonEntranceAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.6, 0.9, curve: Curves.easeOut),
      ),
    );

    _toggleFadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
      ),
    );
  }

  void _initGlowAnimations() {
    _phoneGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _phoneGlowAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _phoneGlowController, curve: Curves.easeInOut),
    );

    _passwordGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _passwordGlowAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _passwordGlowController, curve: Curves.easeInOut),
    );
  }

  void _initButtonAnimations() {
    _buttonScaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _buttonScaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(
        parent: _buttonScaleController,
        curve: Curves.easeOutCubic,
      ),
    );
    _buttonShadowAnimation = Tween<double>(begin: 12, end: 3).animate(
      CurvedAnimation(
        parent: _buttonScaleController,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  void _initRegisterTap() {
    _registerTapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _registerTapScale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _registerTapController,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  void _initIconAnimations() {
    _phoneIconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _phoneIconBounce = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _phoneIconController, curve: Curves.elasticOut),
    );

    _passwordIconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _passwordIconBounce = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _passwordIconController, curve: Curves.elasticOut),
    );

    _lockRotateAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _passwordIconController, curve: Curves.easeInOut),
    );
  }

  void _initLogoPulse() {
    _logoPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _logoPulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _logoPulseController, curve: Curves.easeInOut),
    );
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) _logoPulseController.repeat(reverse: true);
    });
  }

  void _initFocusListeners() {
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
    _entranceController.dispose();
    _logoPulseController.dispose();
    _registerTapController.dispose();
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
                color: AgriMitraColors.primary.withValues(alpha: 0.15 * glow),
                blurRadius: 14 * glow,
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

  InputDecoration _nameFieldDecoration() {
    return InputDecoration(
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

  InputDecoration _farmNameFieldDecoration() {
    return InputDecoration(
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

  Widget _buildRegisterFields() {
    return Column(
      children: [
        FadeTransition(
          opacity: _field1FadeAnim,
          child: _buildAnimatedField(
            glowAnim: _phoneGlowAnimation,
            focusNode: nameFocus,
            child: TextField(
              controller: nameController,
              focusNode: nameFocus,
              decoration: _nameFieldDecoration(),
            ),
          ),
        ),
        const SizedBox(height: 16),
        FadeTransition(
          opacity: _field2FadeAnim,
          child: _buildAnimatedField(
            glowAnim: _phoneGlowAnimation,
            focusNode: farmNameFocus,
            child: TextField(
              controller: farmNameController,
              focusNode: farmNameFocus,
              decoration: _farmNameFieldDecoration(),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 480;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: const Color(0xFF1B5E20),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AgricultureBackground(
          child: AnimatedBuilder(
            animation: _entranceController,
            builder: (context, _) {
              return Opacity(
                opacity: _bgFadeAnim.value,
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 20 : 28,
                      vertical: 24,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildLogo(),
                        const SizedBox(height: 16),
                        _buildWelcomeText(),
                        const SizedBox(height: 32),
                        _buildLoginCard(),
                        const SizedBox(height: 20),
                        _buildToggleLink(),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return FadeTransition(
      opacity: _logoFadeAnim,
      child: ScaleTransition(
        scale: _logoScaleAnim,
        child: AnimatedBuilder(
          animation: _logoPulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _logoPulseAnimation.value,
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AgriMitraColors.primary.withValues(alpha: 0.3),
                      blurRadius: 24,
                      spreadRadius: 3,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: AgriMitraColors.primary.withValues(alpha: 0.1),
                      blurRadius: 40,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.eco_rounded,
                  size: 38,
                  color: AgriMitraColors.primary,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildWelcomeText() {
    return FadeTransition(
      opacity: _welcomeFadeAnim,
      child: Column(
        children: [
          Text(
            'AgriMitra',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.5,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 10,
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
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w400,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginCard() {
    return SlideTransition(
      position: _cardSlideAnim,
      child: FadeTransition(
        opacity: _cardFadeAnim,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: AgriMitraColors.primary.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isRegisterMode) _buildRegisterFields(),

              // Phone field
              FadeTransition(
                opacity: _field3FadeAnim,
                child: _buildAnimatedField(
                  glowAnim: _phoneGlowAnimation,
                  focusNode: phoneFocus,
                  child: TextField(
                    controller: phoneController,
                    focusNode: phoneFocus,
                    keyboardType: TextInputType.phone,
                    decoration: _phoneFieldDecoration(),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Password field
              FadeTransition(
                opacity: _field4FadeAnim,
                child: _buildAnimatedField(
                  glowAnim: _passwordGlowAnimation,
                  focusNode: passwordFocus,
                  child: TextField(
                    controller: passwordController,
                    focusNode: passwordFocus,
                    obscureText: _obscurePassword,
                    decoration: _passwordFieldDecoration(),
                  ),
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
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: AgriMitraColors.critical,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            errorMessage!,
                            style: const TextStyle(
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
              FadeTransition(
                opacity: _buttonEntranceAnim,
                child: isLoading
                    ? const PlantGrowthLoader(isActive: true)
                    : _buildSubmitButton(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => _buttonScaleController.forward(),
        onTapUp: (_) => _buttonScaleController.reverse(),
        onTapCancel: () => _buttonScaleController.reverse(),
        onTap: submit,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _buttonScaleController,
            _buttonShadowAnimation,
          ]),
          builder: (context, child) {
            return Transform.scale(
              scale: _buttonScaleAnimation.value,
              child: Material(
                color: Colors.transparent,
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AgriMitraColors.primary,
                        AgriMitraColors.primary.withValues(alpha: 0.88),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AgriMitraColors.primary.withValues(alpha: 0.35),
                        blurRadius: _buttonShadowAnimation.value,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: InkWell(
                    onTap: submit,
                    borderRadius: BorderRadius.circular(14),
                    splashColor: Colors.white.withValues(alpha: 0.15),
                    highlightColor: Colors.white.withValues(alpha: 0.08),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
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
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildToggleLink() {
    return FadeTransition(
      opacity: _toggleFadeAnim,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _registerHovered = true),
        onExit: (_) => setState(() => _registerHovered = false),
        child: GestureDetector(
          onTapDown: (_) => _registerTapController.forward(),
          onTapUp: (_) {
            _registerTapController.reverse();
            setState(() {
              isRegisterMode = !isRegisterMode;
              errorMessage = null;
            });
          },
          onTapCancel: () => _registerTapController.reverse(),
          child: AnimatedBuilder(
            animation: _registerTapScale,
            builder: (context, child) {
              return Transform.scale(
                scale: _registerTapScale.value,
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _registerHovered
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.85),
                    decoration: _registerHovered
                        ? TextDecoration.underline
                        : TextDecoration.none,
                    decorationColor: Colors.white,
                    decorationThickness: 1.5,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    child: Text(
                      isRegisterMode
                          ? 'Already have an account? Login'
                          : 'New farmer? Register here',
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
