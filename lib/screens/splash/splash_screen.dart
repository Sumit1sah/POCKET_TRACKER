import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../authentication/login_screen.dart';
import '../dashboard/main_navigation_screen.dart';
import '../../providers/auth_provider.dart';
import '../../services/biometric_service.dart';
import '../../services/local_storage_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  // Logo: scale + fade in
  late AnimationController _logoCtrl;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _glowOpacity;

  // Text: slide up + fade
  late AnimationController _textCtrl;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;

  // Bottom loading bar
  late AnimationController _barCtrl;
  late Animation<double> _barWidth;

  // Subtle logo float after entrance
  late AnimationController _floatCtrl;
  late Animation<double> _floatY;

  bool _authFailed = false;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    // ── Logo entrance (0 → 500ms) ────────────────────────────────────────
    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _logoScale = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOutBack),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: const Interval(0.0, 0.6)),
    );
    _glowOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: const Interval(0.4, 1.0)),
    );

    // ── Text entrance (250ms → 700ms) ────────────────────────────────────
    _textCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOutCubic));

    // ── Float looping ───────────────────────────────────────────────────
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _floatY = Tween<double>(begin: 0.0, end: -8.0).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );

    // ── Loading bar (0 → 750ms) ───────────────────────────────────────────
    _barCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _barWidth = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _barCtrl, curve: Curves.easeInOut),
    );

    // ── Sequence ─────────────────────────────────────────────────────────
    _logoCtrl.forward().then((_) {
      _textCtrl.forward();
    });
    _barCtrl.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 100), _navigateNext);
    });
  }

  Future<void> _navigateNext() async {
    if (!mounted) return;
    if (!kIsWeb) {
      final smsStatus = await Permission.sms.status;
      if (!smsStatus.isGranted && !smsStatus.isPermanentlyDenied) {
        await Permission.sms.request();
      }
    }
    if (!mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);

    if (auth.isAuthenticated && LocalStorageService.getBiometricEnabled()) {
      final authenticated = await BiometricService.authenticate(
        reason: 'Authenticate to unlock Pocketify',
      );
      if (!authenticated) {
        if (mounted) {
          setState(() => _authFailed = true);
        }
        return;
      }
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (context, animation, secondaryAnimation) => auth.isAuthenticated
            ? const MainNavigationScreen()
            : const LoginScreen(),
        transitionsBuilder: (context, anim, secondaryAnim, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _textCtrl.dispose();
    _floatCtrl.dispose();
    _barCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: Stack(
        children: [

          // ── Background: two soft gradient blobs ──────────────────────────
          Positioned(
            top: -size.height * 0.12,
            left: -size.width * 0.2,
            child: _GlowBlob(
              size: size.width * 0.9,
              color: const Color(0xFF6C5CE7),
              opacity: 0.18,
            ),
          ),
          Positioned(
            bottom: size.height * 0.05,
            right: -size.width * 0.25,
            child: _GlowBlob(
              size: size.width * 0.75,
              color: const Color(0xFF00CEC9),
              opacity: 0.10,
            ),
          ),

          // ── Centre content ───────────────────────────────────────────────
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                // ── Animated logo ──────────────────────────────────────────
                AnimatedBuilder(
                  animation: Listenable.merge([_logoCtrl, _floatCtrl]),
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _floatY.value),
                      child: Opacity(
                        opacity: _logoOpacity.value,
                        child: Transform.scale(
                          scale: _logoScale.value,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Outer glow
                              Opacity(
                                opacity: _glowOpacity.value,
                                child: Container(
                                  width: 136,
                                  height: 136,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF6C5CE7)
                                            .withValues(alpha: 0.45),
                                        blurRadius: 50,
                                        spreadRadius: 8,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Logo card
                              Container(
                                width: 110,
                                height: 110,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(32),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF7B6CF6),
                                      Color(0xFF6C5CE7),
                                      Color(0xFF4D3CC9),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF6C5CE7)
                                          .withValues(alpha: 0.5),
                                      blurRadius: 24,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Subtle inner highlight
                                    Positioned(
                                      top: 10,
                                      left: 12,
                                      child: Container(
                                        width: 50,
                                        height: 18,
                                        decoration: BoxDecoration(
                                          color: Colors.white
                                              .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.account_balance_wallet_rounded,
                                      color: Colors.white,
                                      size: 50,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 32),

                // ── App name + tagline ─────────────────────────────────────
                FadeTransition(
                  opacity: _textOpacity,
                  child: SlideTransition(
                    position: _textSlide,
                    child: Column(
                      children: [
                        // App name with gradient
                        ShaderMask(
                          shaderCallback: (bounds) =>
                              const LinearGradient(
                            colors: [Colors.white, Color(0xFFB8AAFF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(bounds),
                          child: const Text(
                            'Pocketify',
                            style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -1.5,
                              height: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Tagline
                        Text(
                          'Smart money. Simple life.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.45),
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Bottom: thin animated progress bar ───────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedBuilder(
              animation: _barCtrl,
              builder: (context, child) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 40),
                      child: _authFailed
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () {
                                    setState(() => _authFailed = false);
                                    _navigateNext();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF6C5CE7),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  icon: const Icon(Icons.fingerprint_rounded,
                                      size: 20),
                                  label: const Text(
                                    'Unlock Pocketify',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Biometric / PIN authentication required',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withValues(alpha: 0.4),
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              'Loading your finances...',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.25),
                                letterSpacing: 0.8,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                    ),
                    // Full-width gradient bar
                    Container(
                      height: 3,
                      width: double.infinity,
                      color: Colors.white.withValues(alpha: 0.06),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: _barWidth.value,
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFF6C5CE7),
                                Color(0xFF00CEC9),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

        ],
      ),
    );
  }
}

/// Simple blurred colour blob for the background atmosphere.
class _GlowBlob extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const _GlowBlob({
    required this.size,
    required this.color,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}
