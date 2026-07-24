import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../authentication/login_screen.dart';
import '../dashboard/main_navigation_screen.dart';
import '../../providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ── Animation controllers ──────────────────────────────────────────────────
  late AnimationController _bgController;      // rotating background rings
  late AnimationController _logoController;    // logo entrance
  late AnimationController _particleController;// floating particles
  late AnimationController _textController;    // text + tagline
  late AnimationController _pulseController;   // logo pulse

  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _logoRotate;
  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;
  late Animation<double> _ringRotate;
  late Animation<double> _pulse;

  final List<_Particle> _particles = [];

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    // Generate floating particles
    final rng = math.Random();
    for (int i = 0; i < 18; i++) {
      _particles.add(_Particle(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        size: rng.nextDouble() * 6 + 3,
        speed: rng.nextDouble() * 0.4 + 0.2,
        opacity: rng.nextDouble() * 0.5 + 0.1,
        color: i % 3 == 0
            ? const Color(0xFF8E7CFE)
            : i % 3 == 1
                ? const Color(0xFF00CEC9)
                : const Color(0xFFFDAA5A),
      ));
    }

    // Background ring rotation — continuous
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    // Particle float — continuous
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    // Logo entrance
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Text entrance (starts after logo)
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Pulse — continuous after logo
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    // Curves
    _ringRotate = Tween<double>(begin: 0, end: 2 * math.pi)
        .animate(_bgController);

    _logoScale = TweenSequence([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.15)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.15, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 40,
      ),
    ]).animate(_logoController);

    _logoFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _logoRotate = Tween<double>(begin: -0.15, end: 0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutCubic),
    );

    _textFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );

    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
    );

    _pulse = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Sequence: logo → text → navigate
    _logoController.forward().then((_) {
      _textController.forward();
      Future.delayed(const Duration(milliseconds: 1600), _navigateNext);
    });
  }

  void _navigateNext() async {
    if (!mounted) return;
    // Request SMS permission silently before entering the app
    final smsStatus = await Permission.sms.status;
    if (!smsStatus.isGranted && !smsStatus.isPermanentlyDenied) {
      await Permission.sms.request();
    }
    if (!mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 700),
        pageBuilder: (_, __, ___) => auth.isAuthenticated
            ? const MainNavigationScreen()
            : const LoginScreen(),
        transitionsBuilder: (_, anim, __, child) {
          return FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _bgController.dispose();
    _logoController.dispose();
    _particleController.dispose();
    _textController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A16),
      body: Stack(
        children: [
          // ── Animated gradient background ──────────────────────────────────
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _bgController,
              builder: (_, __) {
                return CustomPaint(
                  painter: _BackgroundPainter(
                    rotation: _ringRotate.value,
                    size: size,
                  ),
                );
              },
            ),
          ),

          // ── Floating particles ─────────────────────────────────────────────
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _particleController,
              builder: (_, __) {
                return CustomPaint(
                  painter: _ParticlePainter(
                    particles: _particles,
                    progress: _particleController.value,
                    size: size,
                  ),
                );
              },
            ),
          ),

          // ── Main content ──────────────────────────────────────────────────
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                AnimatedBuilder(
                  animation: Listenable.merge(
                      [_logoController, _pulseController]),
                  builder: (_, __) {
                    return Opacity(
                      opacity: _logoFade.value,
                      child: Transform.rotate(
                        angle: _logoRotate.value,
                        child: Transform.scale(
                          scale: _logoScale.value * _pulse.value,
                          child: _buildLogo(),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 36),

                // App name + tagline
                FadeTransition(
                  opacity: _textFade,
                  child: SlideTransition(
                    position: _textSlide,
                    child: Column(
                      children: [
                        // App name with gradient
                        ShaderMask(
                          shaderCallback: (bounds) =>
                              const LinearGradient(
                            colors: [
                              Colors.white,
                              Color(0xFFB8AAFF),
                            ],
                          ).createShader(bounds),
                          child: const Text(
                            'Pocketify',
                            style: TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -1.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Tagline
                        Text(
                          'Smart money. Simple life.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withValues(alpha: 0.55),
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Feature pills
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            _pill('💰 Track Expenses'),
                            _pill('📊 Analytics'),
                            _pill('🎯 Budget Goals'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Bottom loader ─────────────────────────────────────────────────
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _textFade,
              child: Column(
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Preparing your finances...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.4),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Logo widget ─────────────────────────────────────────────────────────────
  Widget _buildLogo() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF6C5CE7), Color(0xFF8E7CFE), Color(0xFF5A4FCF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C5CE7).withValues(alpha: 0.6),
            blurRadius: 40,
            spreadRadius: 4,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: const Color(0xFF8E7CFE).withValues(alpha: 0.3),
            blurRadius: 80,
            spreadRadius: 10,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer ring accent
          Container(
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1.5,
              ),
            ),
          ),
          // Icon
          const Icon(
            Icons.account_balance_wallet_rounded,
            color: Colors.white,
            size: 52,
          ),
        ],
      ),
    );
  }

  Widget _pill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: Colors.white.withValues(alpha: 0.7),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Background Painter — rotating rings + radial gradient
// ─────────────────────────────────────────────────────────────────────────────
class _BackgroundPainter extends CustomPainter {
  final double rotation;
  final Size size;

  _BackgroundPainter({required this.rotation, required this.size});

  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    final cy = s.height / 2;

    // Deep background gradient
    final bgPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(0, -0.3),
        radius: 0.9,
        colors: [Color(0xFF1A1040), Color(0xFF0A0A16)],
      ).createShader(Rect.fromLTWH(0, 0, s.width, s.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, s.width, s.height), bgPaint);

    // Glowing center blob
    final blobPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF6C5CE7).withValues(alpha: 0.25),
          Colors.transparent,
        ],
        radius: 0.5,
      ).createShader(Rect.fromCircle(
          center: Offset(cx, cy - 40), radius: s.width * 0.6));
    canvas.drawCircle(
        Offset(cx, cy - 40), s.width * 0.6, blobPaint);

    // Secondary top-right glow
    final blob2Paint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF00CEC9).withValues(alpha: 0.12),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
          center: Offset(s.width * 0.85, s.height * 0.15),
          radius: s.width * 0.4));
    canvas.drawCircle(
        Offset(s.width * 0.85, s.height * 0.15),
        s.width * 0.4,
        blob2Paint);

    // Rotating outer ring
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(rotation);
    _drawDashedRing(canvas, 0, 0, s.width * 0.46,
        const Color(0xFF6C5CE7).withValues(alpha: 0.18), 1.5, 24);
    canvas.restore();

    // Rotating inner ring (counter)
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(-rotation * 0.6);
    _drawDashedRing(canvas, 0, 0, s.width * 0.34,
        const Color(0xFF8E7CFE).withValues(alpha: 0.12), 1.2, 16);
    canvas.restore();

    // Slow outer decorative ring
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(rotation * 0.25);
    _drawDashedRing(canvas, 0, 0, s.width * 0.60,
        const Color(0xFF00CEC9).withValues(alpha: 0.08), 1.0, 32);
    canvas.restore();
  }

  void _drawDashedRing(Canvas canvas, double cx, double cy, double radius,
      Color color, double strokeW, int dashCount) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round;

    final step = (2 * math.pi) / dashCount;
    for (int i = 0; i < dashCount; i++) {
      final start = i * step;
      final end = start + step * 0.45;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        start,
        end,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BackgroundPainter old) => old.rotation != rotation;
}

// ─────────────────────────────────────────────────────────────────────────────
// Particle Painter — floating dots
// ─────────────────────────────────────────────────────────────────────────────
class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  final Size size;

  _ParticlePainter(
      {required this.particles,
      required this.progress,
      required this.size});

  @override
  void paint(Canvas canvas, Size s) {
    for (final p in particles) {
      final dy = (p.y - progress * p.speed) % 1.0;
      final dx = p.x +
          math.sin(progress * 2 * math.pi * 0.5 + p.x * 6) * 0.03;

      final paint = Paint()
        ..color = p.color.withValues(alpha: p.opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

      canvas.drawCircle(
        Offset(dx * s.width, dy * s.height),
        p.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.progress != progress;
}

// ─────────────────────────────────────────────────────────────────────────────
// Data classes
// ─────────────────────────────────────────────────────────────────────────────
class _Particle {
  final double x;
  final double y;
  final double size;
  final double speed;
  final double opacity;
  final Color color;

  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.color,
  });
}
