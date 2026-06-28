import 'dart:async';
import 'package:flutter/material.dart';

class FadeInStaggerText extends StatefulWidget {
  final List<String> texts;
  final Duration changeInterval;
  final TextStyle? style;

  const FadeInStaggerText({
    super.key,
    required this.texts,
    this.changeInterval = const Duration(milliseconds: 2000),
    this.style,
  });

  @override
  State<FadeInStaggerText> createState() => _FadeInStaggerTextState();
}

class _FadeInStaggerTextState extends State<FadeInStaggerText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _slideAnimation = Tween<double>(begin: 8.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(widget.changeInterval, (timer) async {
      if (!mounted) return;
      
      // Fade out current text
      await _controller.reverse();
      
      if (!mounted) return;
      setState(() {
        _currentIndex = (_currentIndex + 1) % widget.texts.length;
      });
      
      // Fade in next text
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.translate(
            offset: Offset(0, _slideAnimation.value),
            child: Text(
              widget.texts[_currentIndex],
              style: widget.style ??
                  TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.blueGrey.shade600,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );
  }
}
