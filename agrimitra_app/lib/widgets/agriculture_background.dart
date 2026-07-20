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
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  Offset _mouseOffset = Offset.zero;

  // Leaves
  late List<AnimationController> _leafControllers;
  final int _leafCount = 6;
  late List<_LeafData> _leafData;

  // Particles
  late AnimationController _particleController;
  late List<_ParticleData> _particleData;
  final int _particleCount = 10;

  // Clouds
  late AnimationController _cloudController;
  late Animation<double> _cloudAnimation;

  // Sunlight
  late AnimationController _sunlightController;
  late Animation<double> _sunlightAnim;

  final Random _random = Random();

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.fadeDuration.toInt()),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _fadeController.forward();

    _generateLeafData();
    _generateParticleData();
    _initLeafControllers();
    _initParticleController();
    _initCloudController();
    _initSunlightController();
  }

  void _generateLeafData() {
    _leafData = List.generate(_leafCount, (i) {
      return _LeafData(
        startX: _random.nextDouble(),
        startY: -0.1 - _random.nextDouble() * 0.15,
        speed: 0.06 + _random.nextDouble() * 0.06,
        driftX: (_random.nextDouble() - 0.5) * 0.12,
        size: 16 + _random.nextDouble() * 14,
        rotation: _random.nextDouble() * pi * 2,
        rotationSpeed: (_random.nextDouble() - 0.5) * 0.8,
        swayAmplitude: 15 + _random.nextDouble() * 20,
        swayFrequency: 0.4 + _random.nextDouble() * 0.6,
        opacity: 0.2 + _random.nextDouble() * 0.2,
        fadePhase: _random.nextDouble() * pi * 2,
      );
    });
  }

  void _generateParticleData() {
    _particleData = List.generate(_particleCount, (i) {
      return _ParticleData(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: 1.5 + _random.nextDouble() * 2.5,
        baseOpacity: 0.12 + _random.nextDouble() * 0.18,
        driftX: (_random.nextDouble() - 0.5) * 0.003,
        driftY: -0.001 - _random.nextDouble() * 0.002,
        pulsePhase: _random.nextDouble() * pi * 2,
      );
    });
  }

  void _initLeafControllers() {
    _leafControllers = List.generate(_leafCount, (i) {
      final duration = (8000 + _random.nextDouble() * 6000).toInt();
      return AnimationController(
        vsync: this,
        duration: Duration(milliseconds: duration),
      )..repeat();
    });
  }

  void _initParticleController() {
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat(reverse: true);
  }

  void _initCloudController() {
    _cloudController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 18000),
    )..repeat(reverse: true);

    _cloudAnimation = Tween<double>(begin: -20, end: 20).animate(
      CurvedAnimation(parent: _cloudController, curve: Curves.easeInOut),
    );
  }

  void _initSunlightController() {
    _sunlightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 10000),
    )..repeat(reverse: true);

    _sunlightAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _sunlightController, curve: Curves.easeInOut),
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
    _sunlightController.dispose();
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
                _buildBaseGradient(),
                _buildParallaxImage(),
                _buildOverlay(),
                _buildSunlightLayer(),
                _buildCloudLayer(),
                _buildLeavesLayer(),
                _buildParticlesLayer(),
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
            const Color(0xFF1B5E20).withValues(alpha: 0.40),
            const Color(0xFF2E7D32).withValues(alpha: 0.45),
            const Color(0xFF388E3C).withValues(alpha: 0.50),
          ],
        ),
      ),
    );
  }

  Widget _buildSunlightLayer() {
    return AnimatedBuilder(
      animation: _sunlightAnim,
      builder: (context, _) {
        final t = _sunlightAnim.value;
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        final offsetX = screenWidth * 0.65 + sin(t * pi) * 30;
        final offsetY = screenHeight * 0.05 + cos(t * pi * 0.7) * 15;
        final opacity = 0.08 + t * 0.04;

        return Positioned(
          left: offsetX - 150,
          top: offsetY - 100,
          child: Container(
            width: 300,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFFFF9C4).withValues(alpha: opacity),
                  const Color(0xFFFFF176).withValues(alpha: opacity * 0.5),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCloudLayer() {
    return AnimatedBuilder(
      animation: _cloudAnimation,
      builder: (context, _) {
        final offset = _cloudAnimation.value;
        final screenH = MediaQuery.of(context).size.height;

        return Stack(
          children: [
            Positioned(
              top: screenH * 0.06,
              left: offset - 40,
              child: _buildCloud(130, 0.06),
            ),
            Positioned(
              top: screenH * 0.14,
              right: offset - 30,
              child: _buildCloud(100, 0.05),
            ),
            Positioned(
              top: screenH * 0.22,
              left: offset + 80,
              child: _buildCloud(80, 0.04),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCloud(double width, double opacity) {
    return Container(
      width: width,
      height: width * 0.35,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(width * 0.25),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: opacity * 0.4),
            blurRadius: width * 0.12,
            spreadRadius: width * 0.03,
          ),
        ],
      ),
    );
  }

  Widget _buildLeavesLayer() {
    return Stack(
      children: List.generate(_leafCount, (i) {
        return AnimatedBuilder(
          animation: _leafControllers[i],
          builder: (context, _) => _buildLeaf(i),
        );
      }),
    );
  }

  Widget _buildLeaf(int index) {
    final data = _leafData[index];
    final t = _leafControllers[index].value;
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;

    // Diagonal movement
    final x = data.startX * screenW + t * data.driftX * screenW;
    final y = (data.startY + t * data.speed) * screenH;

    // Natural sway
    final sway = sin(t * pi * 2 * data.swayFrequency) * data.swayAmplitude;

    // Fade in at top, fade out at bottom
    double leafOpacity;
    if (t < 0.15) {
      leafOpacity = t / 0.15;
    } else if (t > 0.85) {
      leafOpacity = (1.0 - t) / 0.15;
    } else {
      leafOpacity = 1.0;
    }
    leafOpacity *= data.opacity;

    // Pulsing opacity
    leafOpacity *= 0.7 + 0.3 * sin(t * pi * 4 + data.fadePhase);

    final rotation = data.rotation + t * data.rotationSpeed * pi * 2;

    // Card avoidance: push leaves away from center
    final centerX = screenW * 0.5;
    final cardHalfW = 180.0;
    final distFromCenter = (x + sway - centerX).abs();
    final verticalCenter = screenH * 0.45;
    final distFromVertCenter = (y - verticalCenter).abs();
    final inCardZone = distFromCenter < cardHalfW && distFromVertCenter < 150;

    final pushX = inCardZone
        ? (x + sway - centerX).sign * (cardHalfW - distFromCenter + 20)
        : 0.0;

    final colors = [
      const Color(0xFF81C784),
      const Color(0xFF66BB6A),
      const Color(0xFF4CAF50),
      const Color(0xFFA5D6A7),
    ];
    final leafColor = colors[index % colors.length];

    return Positioned(
      left: x + sway + pushX,
      top: y,
      child: Transform.rotate(
        angle: rotation,
        child: Opacity(
          opacity: leafOpacity.clamp(0.0, 1.0),
          child: Icon(
            Icons.eco,
            size: data.size,
            color: leafColor,
          ),
        ),
      ),
    );
  }

  Widget _buildParticlesLayer() {
    return Stack(
      children: List.generate(_particleCount, (i) {
        return AnimatedBuilder(
          animation: _particleController,
          builder: (context, _) => _buildParticle(i),
        );
      }),
    );
  }

  Widget _buildParticle(int index) {
    final data = _particleData[index];
    final t = _particleController.value;
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;

    final x = data.x * screenW + sin(t * pi * 2 + data.pulsePhase) * 8;
    final y = data.y * screenH + cos(t * pi * 1.5 + data.pulsePhase) * 6;

    final pulse = 0.6 + 0.4 * sin(t * pi * 2 + data.pulsePhase);
    final opacity = data.baseOpacity * pulse;
    final size = data.size * (0.8 + 0.2 * pulse);

    return Positioned(
      left: x,
      top: y,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: opacity),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFC8E6C9).withValues(alpha: opacity * 0.6),
              blurRadius: size * 3,
              spreadRadius: size * 0.5,
            ),
          ],
        ),
      ),
    );
  }
}

class _LeafData {
  final double startX;
  final double startY;
  final double speed;
  final double driftX;
  final double size;
  final double rotation;
  final double rotationSpeed;
  final double swayAmplitude;
  final double swayFrequency;
  final double opacity;
  final double fadePhase;

  _LeafData({
    required this.startX,
    required this.startY,
    required this.speed,
    required this.driftX,
    required this.size,
    required this.rotation,
    required this.rotationSpeed,
    required this.swayAmplitude,
    required this.swayFrequency,
    required this.opacity,
    required this.fadePhase,
  });
}

class _ParticleData {
  final double x;
  final double y;
  final double size;
  final double baseOpacity;
  final double driftX;
  final double driftY;
  final double pulsePhase;

  _ParticleData({
    required this.x,
    required this.y,
    required this.size,
    required this.baseOpacity,
    required this.driftX,
    required this.driftY,
    required this.pulsePhase,
  });
}
