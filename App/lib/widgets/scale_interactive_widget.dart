import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ScaleInteractiveWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleFactor;
  final Duration duration;

  const ScaleInteractiveWidget({
    super.key,
    required this.child,
    this.onTap,
    this.scaleFactor = 0.95,
    this.duration = const Duration(milliseconds: 100),
  });

  @override
  State<ScaleInteractiveWidget> createState() => _ScaleInteractiveWidgetState();
}

class _ScaleInteractiveWidgetState extends State<ScaleInteractiveWidget> {
  bool _isTapped = false;

  void _handleTapDown(TapDownDetails details) {
    if (widget.onTap != null) {
      setState(() {
        _isTapped = true;
      });
      // Fire haptic feedback on touch start
      HapticFeedback.lightImpact();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (_isTapped) {
      setState(() {
        _isTapped = false;
      });
    }
  }

  void _handleTapCancel() {
    if (_isTapped) {
      setState(() {
        _isTapped = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _isTapped ? widget.scaleFactor : 1.0,
        duration: widget.duration,
        curve: Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}
