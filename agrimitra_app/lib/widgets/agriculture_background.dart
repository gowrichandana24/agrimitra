import 'dart:math';
import 'package:flutter/material.dart';

class AgricultureBackground extends StatefulWidget {
  final Widget child;
  final double fadeDuration;

  const AgricultureBackground({
    super.key,
    required this.child,
    this.fadeDuration = 800,
  });

  @override
  State<AgricultureBackground> createState() => _AgricultureBackgroundState();
}

class _AgricultureBackgroundState extends State<AgricultureBackground>
    with TickerProviderStateMixin {
  // Fade-in animation
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Parallax offset
  Offset _mouseOffset = Offset.zero;

  // Leaf animation controllers
  late List<AnimationController> _leafControllers;
  late List<Animation<double>> _leafAnimations;
  final int _leafCount = 6;

  // Particle animation controllers
  late AnimationController _particleController;
  late List<Animation<double>> _particleAnimations;
  final int _particleCount = 12;

  // Cloud animation
  late AnimationController _cloudController;
  late Animation<double> _cloudAnimation;

  final Random _random = Random();

  // Pre-generated leaf positions and properties
  late List<_LeafData> _leafData;
  late List<_ParticleData> _particleData;

  @override
  void initState() {
    super.initState();

    // Fade-in controller
    _fadeController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.fadeDuration.toInt()),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _fadeController.forward();

    // Pre-generate leaf data
    _leafData = List.generate(_leafCount, (i) {
      return _LeafData(
        startX: _random.nextDouble(),
        speed: 0.3 + _random.nextDouble() * 0.4,
        amplitude: 20 + _random.nextDouble() * 30,
        size: 14 + _random.nextDouble() * 10,
        delay: _random.nextDouble() * 0.6,
        rotation: _random.nextDouble() * pi * 2,
      );
    });

    // Pre-generate particle data
    _particleData = List.generate(_particleCount, (i) {
      return _ParticleData(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: 2 + _random.nextDouble() * 3,
        opacity: 0.2 + _random.nextDouble() * 0.4,
        pulseSpeed: 0.8 + _random.nextDouble() * 1.2,
      );
    });

    // Leaf animations
    _leafControllers = List.generate(_leafCount, (i) {
      return AnimationController(
        vsync: this,
        duration: Duration(
          milliseconds: (4000 + _random.nextDouble() * 3000).toInt(),
        ),
      )..repeat(reverse: true);
    });

    _leafAnimations = List.generate(_leafCount, (i) {
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _leafControllers[i],
          curve: Curves.easeInOut,
        ),
      );
    });

    // Particle pulse animation
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    _particleAnimations = List.generate(_particleCount, (i) {
      return Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(
          parent: _particleController,
          curve: Curves.easeInOut,
        ),
      );
    });

    // Cloud drift animation
    _cloudController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 12000),
    )..repeat(reverse: true);

    _cloudAnimation = Tween<double>(begin: -30, end: 30).animate(
      CurvedAnimation(parent: _cloudController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    for (final c in _leafControllers) {
      c.dispose();
    }
    _particleController.dispose();
    _cloudController.dispose();
    super.dispose();
  }

  void _onMouseMove(PointerEvent event) {
    if (!mounted) return;
    final size = MediaQuery.of(context).size;
    setState(() {
      _mouseOffset = Offset(
        (event.position.dx / size.width - 0.5) * 2,
        (event.position.dy / size.height - 0.5) * 2,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: _onMouseMove,
      child: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, _) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Base gradient background
                _buildBaseGradient(),

                // Parallax background image
                _buildParallaxImage(),

                // Overlay for readability
                _buildOverlay(),

                // Animated clouds
                AnimatedBuilder(
                  animation: _cloudAnimation,
                  builder: (context, _) => _buildClouds(),
                ),

                // Floating leaves
                ...List.generate(_leafCount, (i) {
                  return AnimatedBuilder(
                    animation: Listenable.merge([
                      _leafControllers[i],
                      _particleController,
                    ]),
                    builder: (context, _) => _buildLeaf(i),
                  );
                }),

                // Glowing particles
                ...List.generate(_particleCount, (i) {
                  return AnimatedBuilder(
                    animation: _particleAnimations[i],
                    builder: (context, _) => _buildParticle(i),
                  );
                }),

                // Content (login card)
                widget.child,
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBaseGradient() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1B5E20),
            Color(0xFF2E7D32),
            Color(0xFF388E3C),
            Color(0xFF43A047),
          ],
        ),
      ),
    );
  }

  Widget _buildParallaxImage() {
    return Transform.translate(
      offset: Offset(
        _mouseOffset.dx * -8,
        _mouseOffset.dy * -8,
      ),
      child: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const NetworkImage(
              'https://images.unsplash.com/photo-1625246333195-78d9c38ad449?w=1920&q=80',
            ),
            fit: BoxFit.cover,
            alignment: Alignment.center,
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.15),
              BlendMode.darken,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1B5E20).withValues(alpha: 0.65),
            const Color(0xFF2E7D32).withValues(alpha: 0.75),
            const Color(0xFF388E3C).withValues(alpha: 0.85),
          ],
        ),
      ),
    );
  }

  Widget _buildClouds() {
    final cloudOffset = _cloudAnimation.value;
    return Stack(
      children: [
        Positioned(
          top: MediaQuery.of(context).size.height * 0.08,
          left: cloudOffset - 40,
          child: _cloudShape(120, 0.08),
        ),
        Positioned(
          top: MediaQuery.of(context).size.height * 0.15,
          right: cloudOffset - 20,
          child: _cloudShape(100, 0.06),
        ),
        Positioned(
          top: MediaQuery.of(context).size.height * 0.25,
          left: cloudOffset + 60,
          child: _cloudShape(80, 0.05),
        ),
      ],
    );
  }

  Widget _cloudShape(double width, double opacity) {
    return Container(
      width: width,
      height: width * 0.4,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(width * 0.2),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: opacity * 0.5),
            blurRadius: width * 0.15,
            spreadRadius: width * 0.05,
          ),
        ],
      ),
    );
  }

  Widget _buildLeaf(int index) {
    final data = _leafData[index];
    final animValue = _leafAnimations[index].value;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final x = data.startX * screenWidth;
    final y = animValue * (screenHeight + 100) - 50;
    final sway = sin(animValue * pi * 2) * data.amplitude;

    return Positioned(
      left: x + sway,
      top: y,
      child: Transform.rotate(
        angle: data.rotation + animValue * pi * 0.5,
        child: Icon(
          Icons.eco,
          size: data.size,
          color: Color.lerp(
            const Color(0xFF8BC34A),
            const Color(0xFF4CAF50),
            animValue,
          )!.withValues(alpha: 0.35),
        ),
      ),
    );
  }

  Widget _buildParticle(int index) {
    final data = _particleData[index];
    final animValue = _particleAnimations[index].value;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final x = data.x * screenWidth;
    final y = data.y * screenHeight;
    final pulse = animValue * data.size;

    return Positioned(
      left: x,
      top: y,
      child: Container(
        width: pulse,
        height: pulse,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF8BC34A).withValues(alpha: data.opacity * animValue),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8BC34A).withValues(alpha: data.opacity * 0.5 * animValue),
              blurRadius: pulse * 2,
              spreadRadius: pulse * 0.5,
            ),
          ],
        ),
      ),
    );
  }
}

class _LeafData {
  final double startX;
  final double speed;
  final double amplitude;
  final double size;
  final double delay;
  final double rotation;

  _LeafData({
    required this.startX,
    required this.speed,
    required this.amplitude,
    required this.size,
    required this.delay,
    required this.rotation,
  });
}

class _ParticleData {
  final double x;
  final double y;
  final double size;
  final double opacity;
  final double pulseSpeed;

  _ParticleData({
    required this.x,
    required this.y,
    required this.size,
    required this.opacity,
    required this.pulseSpeed,
  });
}
