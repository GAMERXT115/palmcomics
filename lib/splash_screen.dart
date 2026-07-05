import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _bgController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _scaleAnimation = CurvedAnimation(
      parent: _mainController,
      curve: Curves.elasticOut,
    );

    _mainController.forward();

    Timer(const Duration(seconds: 4), () {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFEB3B),
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _bgController,
            builder: (context, child) {
              return Positioned.fill(
                child: CustomPaint(
                  painter: ComicBackgroundPainter(_bgController.value),
                ),
              );
            },
          ),
          Center(
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(320, 320),
                    painter: ComicBurstPainter(),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 5),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black,
                              offset: Offset(8, 8),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 25),
                      Transform.rotate(
                        angle: -0.08,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.black, width: 4),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black,
                                offset: Offset(6, 6),
                              ),
                            ],
                          ),
                          child: const Text(
                            "PALM",
                            style: TextStyle(
                              fontSize: 46,
                              fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.italic,
                              color: Colors.black,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Transform.rotate(
                        angle: 0.08,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF5252),
                            border: Border.all(color: Colors.black, width: 4),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black,
                                offset: Offset(6, 6),
                              ),
                            ],
                          ),
                          child: const Text(
                            "COMICS",
                            style: TextStyle(
                              fontSize: 46,
                              fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.italic,
                              color: Colors.white,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Text(
                  "POW! LOADING...",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    letterSpacing: 4,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ComicBackgroundPainter extends CustomPainter {
  final double animationValue;
  ComicBackgroundPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.05)
      ..style = PaintingStyle.fill;

    const double spacing = 30.0;
    final double offset = animationValue * spacing;

    for (double x = -spacing; x < size.width + spacing; x += spacing) {
      for (double y = -spacing; y < size.height + spacing; y += spacing) {
        canvas.drawCircle(
          Offset(x + offset, y + offset),
          2.5,
          paint,
        );
      }
    }

    final linePaint = Paint()
      ..color = Colors.black.withOpacity(0.03)
      ..strokeWidth = 2;

    final center = Offset(size.width / 2, size.height / 2);
    const int lineCount = 24;
    for (int i = 0; i < lineCount; i++) {
      double angle = (i * 2 * math.pi / lineCount) + (animationValue * 0.2);
      canvas.drawLine(
        center,
        center + Offset(math.cos(angle) * size.width, math.sin(angle) * size.height),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(ComicBackgroundPainter oldDelegate) => true;
}

class ComicBurstPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFC107)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final path = Path();
    const int points = 18;

    for (int i = 0; i < points * 2; i++) {
      double radius = i.isEven ? 170 : 120;
      double angle = (i * math.pi) / points;
      double x = centerX + radius * math.cos(angle);
      double y = centerY + radius * math.sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
