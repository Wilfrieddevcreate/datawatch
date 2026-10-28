import 'package:flutter/material.dart';

import '../motion.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Le tiret lime.
class DwDash extends StatelessWidget {
  const DwDash({super.key, this.color, this.width = 18});
  final Color? color;
  final double width;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: 4,
    decoration: BoxDecoration(
      color: color ?? context.dw.accent,
      borderRadius: BorderRadius.circular(2),
    ),
  );
}

/// Titre de section : un tiret lime, un titre condensé, une action à droite.
class DwSectionTitle extends StatelessWidget {
  const DwSectionTitle(
    this.text, {
    super.key,
    this.trailing,
    this.size = 22,
    this.color,
  });

  final String text;
  final Widget? trailing;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const DwDash(),
        const SizedBox(width: 10),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              text,
              style: DwFonts.section(
                size,
              ).copyWith(color: color ?? context.dw.text),
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Surface blanche (ou sombre) aux angles de 20 px.
class DwSheet extends StatelessWidget {
  const DwSheet({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.radius = DwRadius.lg,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color ?? context.dw.surface,
      borderRadius: BorderRadius.circular(radius),
    ),
    child: child,
  );
}

/// Étiquette filaire : « Accordé », « Seuil 80 % atteint ».
class DwTag extends StatelessWidget {
  const DwTag(this.label, {super.key, this.color, this.icon});

  final String label;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? context.dw.text;
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DwRadius.xs),
        border: Border.all(color: fg),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DwFonts.style(DwFonts.body, 12, 600).copyWith(color: fg),
          ),
        ],
      ),
    );
  }
}

/// Bouton principal : encre, un point lime devant le libellé.
class DwPrimaryButton extends StatelessWidget {
  const DwPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.trailingIcon,
    this.background,
    this.foreground,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? trailingIcon;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    final fg = foreground ?? c.onStrong;
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: background ?? c.strong,
        foregroundColor: fg,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: c.accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (trailingIcon != null) ...[
            const SizedBox(width: 10),
            Icon(trailingIcon, size: 18, color: c.accent),
          ],
        ],
      ),
    );
  }
}

/// Barre partagée : la première part en aplat, le reste dans l'autre couleur.
class DwSplitBar extends StatelessWidget {
  const DwSplitBar({
    super.key,
    required this.fraction,
    this.firstColor,
    this.secondColor,
    this.height = 10,
  });

  final double fraction;
  final Color? firstColor;
  final Color? secondColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: fraction.clamp(0.04, 0.96)),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (context, f, _) => Row(
            children: [
              Expanded(
                flex: (f * 1000).round(),
                child: ColoredBox(color: firstColor ?? c.strong),
              ),
              const SizedBox(width: 2),
              Expanded(
                flex: ((1 - f) * 1000).round(),
                child: ColoredBox(color: secondColor ?? c.wifi),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Barre fine qui s'étire à l'apparition.
class DwBar extends StatelessWidget {
  const DwBar({
    super.key,
    required this.fraction,
    this.color,
    this.track,
    this.height = 3,
  });

  final double fraction;
  final Color? color;
  final Color? track;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          children: [
            ColoredBox(
              color: track ?? c.divider,
              child: const SizedBox.expand(),
            ),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: fraction.clamp(0.02, 1.0)),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, f, _) => FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: f,
                child: ColoredBox(color: color ?? c.strong),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Apparition en cascade : fondu et léger glissement, décalé de [delay].
class DwReveal extends StatefulWidget {
  const DwReveal({super.key, required this.child, this.delay = 0});

  final Widget child;

  /// Rang dans la cascade : chaque rang ajoute 90 ms.
  final int delay;

  @override
  State<DwReveal> createState() => _DwRevealState();
}

class _DwRevealState extends State<DwReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!DwMotion.on(context)) {
      _controller.value = 1;
      return;
    }
    Future<void>.delayed(Duration(milliseconds: 90 * widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.03),
          end: Offset.zero,
        ).animate(_curve),
        child: widget.child,
      ),
    );
  }
}

/// Chargement : un petit réservoir qui se remplit, à la place du spinner.
class DwLoader extends StatefulWidget {
  const DwLoader({super.key, this.size = 22});
  final double size;

  @override
  State<DwLoader> createState() => _DwLoaderState();
}

class _DwLoaderState extends State<DwLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (DwMotion.on(context)) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0.5;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    final w = widget.size * 0.7;
    final h = widget.size;
    return Semantics(
      label: 'Chargement',
      child: ExcludeSemantics(
        child: Container(
          width: w,
          height: h,
          padding: EdgeInsets.all(w * 0.16),
          alignment: Alignment.bottomCenter,
          decoration: BoxDecoration(
            color: c.strong,
            borderRadius: BorderRadius.circular(w * 0.3),
          ),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => FractionallySizedBox(
              heightFactor: 0.15 + 0.75 * Curves.easeInOut.transform(
                _controller.value < 0.5
                    ? _controller.value * 2
                    : 2 - _controller.value * 2,
              ),
              widthFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: c.accent,
                  borderRadius: BorderRadius.circular(w * 0.12),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
