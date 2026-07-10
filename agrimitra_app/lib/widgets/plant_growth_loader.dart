import 'dart:math';
import 'package:flutter/material.dart';
import '../theme.dart';

class PlantGrowthLoader extends StatefulWidget {
  final bool isActive;
  final VoidCallback? onComplete;

  const PlantGrowthLoader({
    super.key,
    required this.isActive,
    this.onComplete,
  });

  @override
  State<PlantGrowthLoader> createState() => _PlantGrowthLoaderState();
}

class _PlantGrowthLoaderState extends State<PlantGrowthLoader>
    with TickerProviderStateMixin {
  // Main plant growth controller
  late AnimationController _plantController;
  late Animation<double> _plantGrowth;

  // Stage progression controller
  late AnimationController _stageController;

  // Water drops controller
  late AnimationController _waterController;
  late List<Animation<double>> _waterDropAnimations;
  late List<Animation<double>> _waterDropFade;

  // Floating leaves controller
  late AnimationController _leavesController;
  late List<Animation<double>> _leafFloat;
  late List<Animation<double>> _leafFade;

  // Text fade controller
  late AnimationController _textController;
  late Animation<double> _textFade;

  int _currentStageIndex = 0;

  final Random _random = Random();
  final int _waterDropCount = 4;
  final int _leafCount = 5;

  // Pre-generated positions
  late List<double> _waterDropX;
  late List<double> _waterDropDelay;
  late List<double> _leafStartX;
  late List<double> _leafDelay;

  static const List<String> _stageMessages = [
    '🌱 Preparing your farm...',
    '🌿 Connecting to AI...',
    '🌾 Loading your dashboard...',
    '🌳 Welcome to AgriMitra!',
  ];

  @override
  void initState() {
    super.initState();

    // Pre-generate random positions
    _waterDropX = List.generate(_waterDropCount, (_) => _random.nextDouble());
    _waterDropDelay = List.generate(
      _waterDropCount,
      (_) => _random.nextDouble() * 0.5,
    );
    _leafStartX = List.generate(_leafCount, (_) => _random.nextDouble());
    _leafDelay = List.generate(_leafCount, (_) => _random.nextDouble() * 0.4);

    _initAnimations();
  }

  void _initAnimations() {
    // Plant growth controller (continuous smooth growth)
    _plantController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    _plantGrowth = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _plantController,
        curve: const Interval(0, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    // Stage progression controller
    _stageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _stageController.addListener(_onStageChanged);

    // Water drops controller
    _waterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _waterDropAnimations = List.generate(_waterDropCount, (i) {
      final start = _waterDropDelay[i];
      final end = (start + 0.6).clamp(0.0, 1.0);
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _waterController,
          curve: Interval(start, end, curve: Curves.easeIn),
        ),
      );
    });

    _waterDropFade = List.generate(_waterDropCount, (i) {
      final start = _waterDropDelay[i];
      final fadeOutEnd = (start + 0.6).clamp(0.0, 1.0);
      return TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween<double>(begin: 0, end: 1),
          weight: 50,
        ),
        TweenSequenceItem(
          tween: Tween<double>(begin: 1, end: 0),
          weight: 50,
        ),
      ]).animate(
        CurvedAnimation(
          parent: _waterController,
          curve: Interval(start, fadeOutEnd, curve: Curves.easeInOut),
        ),
      );
    });

    // Floating leaves controller
    _leavesController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _leafFloat = List.generate(_leafCount, (i) {
      final delay = _leafDelay[i];
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _leavesController,
          curve: Interval(delay, 1.0, curve: Curves.easeOut),
        ),
      );
    });

    _leafFade = List.generate(_leafCount, (i) {
      final delay = _leafDelay[i];
      return TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween<double>(begin: 0, end: 1),
          weight: 40,
        ),
        TweenSequenceItem(
          tween: Tween<double>(begin: 1, end: 0),
          weight: 60,
        ),
      ]).animate(
        CurvedAnimation(
          parent: _leavesController,
          curve: Interval(delay, 1.0, curve: Curves.easeInOut),
        ),
      );
    });

    // Text fade controller
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _textFade = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(PlantGrowthLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _startAnimation();
    } else if (!widget.isActive && oldWidget.isActive) {
      _stopAnimation();
    }
  }

  void _startAnimation() {
    setState(() {
      _currentStageIndex = 0;
    });
    _plantController.forward(from: 0);
    _stageController.forward(from: 0);
    _leavesController.forward(from: 0);
  }

  void _stopAnimation() {
    _plantController.stop();
    _stageController.stop();
    _waterController.stop();
    _leavesController.stop();
    _textController.stop();
  }

  void _onStageChanged() {
    final progress = _stageController.value;
    int newStageIndex;

    if (progress < 0.25) {
      newStageIndex = 0;
    } else if (progress < 0.5) {
      newStageIndex = 1;
    } else if (progress < 0.75) {
      newStageIndex = 2;
    } else {
      newStageIndex = 3;
    }

    if (newStageIndex != _currentStageIndex) {
      _animateTextTransition(() {
        setState(() {
          _currentStageIndex = newStageIndex;
        });
      });
    }

    if (progress >= 1.0 && widget.onComplete != null) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted && widget.isActive) {
          widget.onComplete!();
        }
      });
    }
  }

  void _animateTextTransition(VoidCallback onComplete) {
    _textController.forward(from: 0).then((_) {
      onComplete();
      _textController.reverse();
    });
  }

  @override
  void dispose() {
    _plantController.dispose();
    _stageController.dispose();
    _waterController.dispose();
    _leavesController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) return const SizedBox.shrink();

    return SizedBox(
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Water drops
          ..._buildWaterDrops(),

          // Plant growth
          AnimatedBuilder(
            animation: _plantGrowth,
            builder: (context, _) => _buildPlant(),
          ),

          // Floating leaves (only in later stages)
          if (_currentStageIndex >= 2) ..._buildFloatingLeaves(),

          // Loading text
          Positioned(
            bottom: 0,
            child: AnimatedBuilder(
              animation: _textFade,
              builder: (context, child) {
                return Opacity(
                  opacity: _textFade.value,
                  child: Text(
                    _stageMessages[_currentStageIndex],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AgriMitraColors.primary,
                      letterSpacing: 0.2,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlant() {
    final growth = _plantGrowth.value;

    // Calculate plant dimensions based on growth
    final stemHeight = growth * 70;
    final trunkWidth = (growth - 0.5).clamp(0.0, 1.0) * 8;

    return SizedBox(
      width: 100,
      height: 120,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Ground/soil
          Positioned(
            bottom: 18,
            child: Container(
              width: 60,
              height: 6,
              decoration: BoxDecoration(
                color: const Color(0xFF8D6E63),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          // Stem/trunk
          if (stemHeight > 0)
            Positioned(
              bottom: 22,
              child: Container(
                width: 3 + trunkWidth,
                height: stemHeight,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      const Color(0xFF6D4C41),
                      Color.lerp(
                        const Color(0xFF6D4C41),
                        const Color(0xFF4CAF50),
                        (growth - 0.3).clamp(0.0, 1.0),
                      )!,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

          // Seed (visible at start)
          if (growth < 0.2)
            Positioned(
              bottom: 20,
              child: Transform.scale(
                scale: 1 - (growth / 0.2),
                child: Container(
                  width: 12,
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFF795548),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),

          // Sprout leaves
          if (growth > 0.2 && growth < 0.6)
            Positioned(
              bottom: 22 + stemHeight * 0.4,
              child: Transform.scale(
                scale: ((growth - 0.2) / 0.4).clamp(0.0, 1.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.rotate(
                      angle: -0.5,
                      child: _buildLeaf(14, const Color(0xFF66BB6A)),
                    ),
                    const SizedBox(width: 2),
                    Transform.rotate(
                      angle: 0.5,
                      child: _buildLeaf(14, const Color(0xFF81C784)),
                    ),
                  ],
                ),
              ),
            ),

          // Growing canopy
          if (growth > 0.4)
            Positioned(
              bottom: 22 + stemHeight * 0.6,
              child: Transform.scale(
                scale: ((growth - 0.4) / 0.6).clamp(0.0, 1.0),
                child: _buildCanopy(growth),
              ),
            ),

          // Tree crown (final stage)
          if (growth > 0.7)
            Positioned(
              bottom: 22 + stemHeight * 0.7,
              child: Transform.scale(
                scale: ((growth - 0.7) / 0.3).clamp(0.0, 1.0),
                child: _buildTreeCrown(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLeaf(double size, Color color) {
    return Container(
      width: size,
      height: size * 0.6,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(size * 0.5),
          topRight: Radius.circular(size * 0.1),
          bottomLeft: Radius.circular(size * 0.1),
          bottomRight: Radius.circular(size * 0.5),
        ),
      ),
    );
  }

  Widget _buildCanopy(double growth) {
    final size = 30 + (growth - 0.4) * 30;
    return Container(
      width: size,
      height: size * 0.7,
      decoration: BoxDecoration(
        color: Color.lerp(
          const Color(0xFF81C784),
          const Color(0xFF4CAF50),
          growth,
        ),
        borderRadius: BorderRadius.circular(size * 0.4),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }

  Widget _buildTreeCrown() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Main crown
        Container(
          width: 56,
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF43A047),
                Color(0xFF388E3C),
                Color(0xFF2E7D32),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2E7D32).withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
        ),
        // Highlight
        Positioned(
          top: 6,
          child: Container(
            width: 24,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildWaterDrops() {
    return List.generate(_waterDropCount, (i) {
      return AnimatedBuilder(
        animation: Listenable.merge([
          _waterDropAnimations[i],
          _waterDropFade[i],
        ]),
        builder: (context, _) {
          final dropProgress = _waterDropAnimations[i].value;
          final fadeProgress = _waterDropFade[i].value;

          if (fadeProgress <= 0) return const SizedBox.shrink();

          final x = (_waterDropX[i] - 0.5) * 80;
          final y = -20 + dropProgress * 50;

          return Positioned(
            left: 50 + x,
            top: 40 + y,
            child: Opacity(
              opacity: fadeProgress,
              child: Container(
                width: 4,
                height: 6,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF4FC3F7),
                      Color(0xFF29B6F6),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF29B6F6).withValues(alpha: 0.4),
                      blurRadius: 3,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    });
  }

  List<Widget> _buildFloatingLeaves() {
    return List.generate(_leafCount, (i) {
      return AnimatedBuilder(
        animation: Listenable.merge([
          _leafFloat[i],
          _leafFade[i],
        ]),
        builder: (context, _) {
          final floatProgress = _leafFloat[i].value;
          final fadeProgress = _leafFade[i].value;

          if (fadeProgress <= 0 || floatProgress <= 0) {
            return const SizedBox.shrink();
          }

          final startX = (_leafStartX[i] - 0.5) * 100;
          final x = startX + sin(floatProgress * pi * 2) * 15;
          final y = -floatProgress * 60;
          final rotation = floatProgress * pi * 0.5;

          return Positioned(
            left: 50 + x,
            top: 50 + y,
            child: Transform.rotate(
              angle: rotation,
              child: Opacity(
                opacity: fadeProgress,
                child: Icon(
                  Icons.eco,
                  size: 10 + i * 2,
                  color: Color.lerp(
                    const Color(0xFF81C784),
                    const Color(0xFF4CAF50),
                    floatProgress,
                  ),
                ),
              ),
            ),
          );
        },
      );
    });
  }
}
