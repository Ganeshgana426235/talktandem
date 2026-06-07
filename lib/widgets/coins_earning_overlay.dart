import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_theme.dart';

class CoinsEarningOverlay extends StatefulWidget {
  final int coinsEarned;
  final int initialCoins;
  final VoidCallback onDismiss;

  const CoinsEarningOverlay({
    super.key,
    required this.coinsEarned,
    required this.initialCoins,
    required this.onDismiss,
  });

  @override
  State<CoinsEarningOverlay> createState() => _CoinsEarningOverlayState();
}

class _CoinsEarningOverlayState extends State<CoinsEarningOverlay> with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _counterBounceController;
  
  final List<Map<String, dynamic>> _coins = [];
  final int _numCoins = 8;
  
  int _displayedCoins = 0;
  bool _showButton = false;

  final GlobalKey _counterKey = GlobalKey();
  Offset _counterOffset = const Offset(0, 80); // Default fallback position for the counter

  @override
  void initState() {
    super.initState();
    _displayedCoins = widget.initialCoins;

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _counterBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 1.0,
      upperBound: 1.3,
    );

    // Setup coins
    final random = Random();
    for (int i = 0; i < _numCoins; i++) {
      // Staggered delays: each coin starts flying slightly later
      double delay = 0.15 + (i * 0.08); // Starts flying after 15% of controller progress
      
      // Spawn offset: slight random offset around the center (0,0)
      double angle = random.nextDouble() * 2 * pi;
      double distance = 10.0 + random.nextDouble() * 30.0;
      Offset spawnOffset = Offset(cos(angle) * distance, sin(angle) * distance);

      _coins.add({
        'delay': delay,
        'spawnOffset': spawnOffset,
        'playedSound': false,
        'curve': CurvedAnimation(
          parent: _mainController,
          curve: Interval(delay, min(delay + 0.35, 1.0), curve: Curves.easeInBack),
        ),
      });
    }

    // Capture the target counter position after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _captureTargetPosition();
      _startAnimation();
    });
  }

  void _captureTargetPosition() {
    if (!mounted) return;
    try {
      final RenderBox? renderBox = _counterKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final position = renderBox.localToGlobal(Offset.zero);
        setState(() {
          // Adjust to be relative to the overlay Stack
          _counterOffset = Offset(
            position.dx + (renderBox.size.width / 2) - 15, // centered on coin icon
            position.dy + (renderBox.size.height / 2) - 15,
          );
        });
      }
    } catch (e) {
      debugPrint("Could not resolve target position for coin animation: $e");
    }
  }

  void _startAnimation() {
    _mainController.forward();
    
    _mainController.addListener(() {
      if (!mounted) return;
      
      double progress = _mainController.value;
      
      // Check which coins have arrived
      int arrivedCount = 0;
      for (int i = 0; i < _numCoins; i++) {
        double delay = _coins[i]['delay'];
        double arrivalTime = delay + 0.35;
        
        if (progress >= arrivalTime) {
          arrivedCount++;
          if (!_coins[i]['playedSound']) {
            _coins[i]['playedSound'] = true;
            // Play arrival sound
            SystemSound.play(SystemSoundType.click);
            
            // Trigger counter bounce
            _counterBounceController.forward(from: 1.0).then((_) {
              _counterBounceController.reverse();
            });

            // Increment the coin display dynamically
            double stepPercent = arrivedCount / _numCoins;
            setState(() {
              _displayedCoins = widget.initialCoins + (widget.coinsEarned * stepPercent).round();
            });
          }
        }
      }
    });

    _mainController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _displayedCoins = widget.initialCoins + widget.coinsEarned;
          _showButton = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _counterBounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final center = Offset(size.width / 2, size.height / 2);
    final textPrimary = AppTheme.getTextColor(context);
    final textSecondary = AppTheme.getSecondaryTextColor(context);
    final surfaceColor = AppTheme.getSurfaceColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        // Semi-transparent darkened background
        Positioned.fill(
          child: Container(
            color: Colors.black.withOpacity(0.85),
          ),
        ),

        // Glowing backdrop behind center card
        Positioned(
          left: center.dx - 150,
          top: center.dy - 150,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.amber.withOpacity(0.12),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.25),
                  blurRadius: 80,
                  spreadRadius: 20,
                ),
              ],
            ),
          ),
        ),

        // Coin counter at the top (targets destination)
        Positioned(
          top: 60,
          left: 0,
          right: 0,
          child: Center(
            child: ScaleTransition(
              scale: _counterBounceController,
              child: Container(
                key: _counterKey,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.amber.withOpacity(0.8), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.coins, color: Colors.amber, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      '$_displayedCoins',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Central Card & Contents
        Positioned(
          left: 24,
          right: 24,
          top: center.dy - 180,
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.amber.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                // Gold crown/star icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.amber.withOpacity(0.4), width: 1.5),
                  ),
                  child: const Icon(
                    LucideIcons.award,
                    color: Colors.amber,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Practice Complete!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                    decoration: TextDecoration.none,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'You earned coins for your speaking practice session.',
                  style: TextStyle(
                    fontSize: 13,
                    color: textSecondary,
                    height: 1.4,
                    fontWeight: FontWeight.normal,
                    decoration: TextDecoration.none,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                
                // Highlight Coins Count
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.amber.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.plus, color: Colors.amber, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.coinsEarned}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.amber,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'COINS',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),

        // Flying Coins rendering
        ...List.generate(_numCoins, (index) {
          final coin = _coins[index];
          final double delay = coin['delay'];
          final double arrivalTime = delay + 0.35;
          final double val = _mainController.value;

          // Don't show coin if animation hasn't started for it or has already arrived
          if (val < delay || val >= arrivalTime) {
            return const SizedBox.shrink();
          }

          final CurvedAnimation animation = coin['curve'];
          
          // Bezier curves/arched path for fly path
          final Offset spawn = center + (coin['spawnOffset'] as Offset);
          final double t = animation.value;

          // Parabolic arch formula:
          // X: linear interpolation
          // Y: interpolation with a hump/curve upwards
          final double dx = spawn.dx + (_counterOffset.dx - spawn.dx) * t;
          final double dy = spawn.dy + (_counterOffset.dy - spawn.dy) * t - (sin(t * pi) * 120.0);

          return Positioned(
            left: dx,
            top: dy,
            child: const Icon(
              LucideIcons.coins,
              color: Colors.amber,
              size: 30,
            ),
          );
        }),

        // Claim button (fades in when complete)
        if (_showButton)
          Positioned(
            bottom: 60,
            left: 32,
            right: 32,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 300),
              builder: (context, opacityVal, child) {
                return Opacity(
                  opacity: opacityVal,
                  child: child,
                );
              },
              child: SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: widget.onDismiss,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 8,
                    shadowColor: Colors.amber.withOpacity(0.4),
                  ),
                  child: const Text(
                    'Great, Let\'s Review!',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
