import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Page d'onglet avec l'en-tête DataWatch :
/// - une barre fixe (logo, actions) qui se floute et affiche un titre compact
///   dès que le contenu passe dessous ;
/// - un grand titre propre à la page, avec sa ligne de contexte et son sous-titre.
class DwPage extends StatefulWidget {
  const DwPage({
    super.key,
    required this.title,
    required this.children,
    this.overline,
    this.subtitle,
    this.compactTitle,
    this.leading,
    this.titleLeading,
    this.actions = const [],
    this.onRefresh,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 32),
  });

  final String title;
  final List<Widget> children;

  /// Contexte en petites capitales au-dessus du titre (date, période…).
  final String? overline;
  final Widget? subtitle;

  /// Titre affiché dans la barre une fois le grand titre défilé (par défaut : [title]).
  final String? compactTitle;

  /// À gauche de la barre : le logo par défaut, un bouton retour sur une
  /// page secondaire ([DwBackButton]).
  final Widget? leading;

  /// Visuel placé devant le grand titre (icône d'application…).
  final Widget? titleLeading;
  final List<Widget> actions;
  final Future<void> Function()? onRefresh;
  final EdgeInsetsGeometry padding;

  static const double barHeight = 60;

  @override
  State<DwPage> createState() => _DwPageState();
}

class _DwPageState extends State<DwPage> {
  final _scroll = ScrollController();
  final _offset = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() => _offset.value = _scroll.offset);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _offset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final scrollView = CustomScrollView(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: SizedBox(height: top + DwPage.barHeight)),
        SliverToBoxAdapter(
          child: _LargeTitle(
            title: widget.title,
            overline: widget.overline,
            subtitle: widget.subtitle,
            leading: widget.titleLeading,
            offset: _offset,
          ),
        ),
        SliverPadding(
          padding: widget.padding,
          sliver: SliverList.list(children: widget.children),
        ),
      ],
    );

    return Stack(
      children: [
        if (widget.onRefresh == null)
          scrollView
        else
          RefreshIndicator(
            onRefresh: widget.onRefresh!,
            edgeOffset: top + DwPage.barHeight,
            child: scrollView,
          ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: ValueListenableBuilder<double>(
            valueListenable: _offset,
            builder: (context, offset, _) => _TopBar(
              topInset: top,
              offset: offset,
              title: widget.compactTitle ?? widget.title,
              leading: widget.leading ?? const DwMark(),
              actions: widget.actions,
            ),
          ),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.topInset,
    required this.offset,
    required this.title,
    required this.leading,
    required this.actions,
  });

  final double topInset;
  final double offset;
  final String title;
  final Widget leading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    // Le fond apparaît dès le premier défilement, le titre compact quand le
    // grand titre passe sous la barre.
    final surface = (offset / 16).clamp(0.0, 1.0);
    final titleIn = ((offset - 44) / 24).clamp(0.0, 1.0);

    final bar = Container(
      height: topInset + DwPage.barHeight,
      padding: EdgeInsets.only(top: topInset, left: 16, right: 12),
      decoration: BoxDecoration(
        color: c.background.withValues(alpha: 0.82 * surface),
        border: Border(
          bottom: BorderSide(color: c.divider.withValues(alpha: surface)),
        ),
      ),
      child: NavigationToolbar(
        // La barre impose sa hauteur : on recentre le logo à sa taille propre.
        leading: Align(
          alignment: Alignment.centerLeft,
          widthFactor: 1,
          child: leading,
        ),
        centerMiddle: true,
        middleSpacing: 12,
        middle: Opacity(
          opacity: titleIn,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - titleIn)),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleMedium!.copyWith(fontSize: 16),
            ),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, a) in actions.indexed) ...[
              if (i > 0) const SizedBox(width: 8),
              a,
            ],
          ],
        ),
      ),
    );

    if (surface == 0) return bar;
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20 * surface, sigmaY: 20 * surface),
        child: bar,
      ),
    );
  }
}

class _LargeTitle extends StatelessWidget {
  const _LargeTitle({
    required this.title,
    required this.overline,
    required this.subtitle,
    required this.leading,
    required this.offset,
  });

  final String title;
  final String? overline;
  final Widget? subtitle;
  final Widget? leading;
  final ValueNotifier<double> offset;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    final t = Theme.of(context).textTheme;
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (overline != null) ...[
            Text(
              overline!.toUpperCase(),
              style: DwFonts.overline(c.textSecondary),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 14)],
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: DwFonts.style(
                      DwFonts.display,
                      36,
                      700,
                      height: 1.02,
                      letterSpacing: -1.4,
                    ).copyWith(color: c.text),
                  ),
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            DefaultTextStyle.merge(
              style: t.bodyLarge!.copyWith(color: c.textSecondary, height: 1.4),
              child: subtitle!,
            ),
          ],
        ],
      ),
    );
    // Le grand titre s'efface en douceur en passant sous la barre.
    return ValueListenableBuilder<double>(
      valueListenable: offset,
      builder: (context, o, child) =>
          Opacity(opacity: (1 - o / 90).clamp(0.0, 1.0), child: child),
      child: content,
    );
  }
}

/// Le logo DataWatch : un petit réservoir rempli de lime.
class DwMark extends StatelessWidget {
  const DwMark({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Semantics(
      label: 'DataWatch',
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isLight ? c.strong : c.surface,
          borderRadius: BorderRadius.circular(size * 0.3),
          border: isLight ? null : Border.all(color: c.divider),
        ),
        alignment: Alignment.center,
        child: Container(
          width: size * 0.36,
          height: size * 0.58,
          padding: EdgeInsets.all(size * 0.05),
          alignment: Alignment.bottomCenter,
          decoration: BoxDecoration(
            color: const Color(0xFF2A303C),
            borderRadius: BorderRadius.circular(size * 0.1),
          ),
          child: Container(
            height: size * 0.26,
            decoration: BoxDecoration(
              color: c.accent,
              borderRadius: BorderRadius.circular(size * 0.06),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bouton rond de la barre d'en-tête, avec pastille optionnelle.
class DwHeaderButton extends StatelessWidget {
  const DwHeaderButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.badgeColor,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  /// Pastille en haut à droite (alerte en cours), absente si null.
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: onPressed,
          tooltip: tooltip,
          style: IconButton.styleFrom(
            backgroundColor: c.surface,
            fixedSize: const Size(44, 44),
            side: Theme.of(context).brightness == Brightness.dark
                ? BorderSide(color: c.divider)
                : null,
          ),
          icon: Icon(icon, color: c.text, size: 21),
        ),
        if (badgeColor != null)
          Positioned(
            top: 9,
            right: 10,
            child: IgnorePointer(
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.surface, width: 2),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Retour à l'écran précédent, au style des boutons de l'en-tête.
class DwBackButton extends StatelessWidget {
  const DwBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return DwHeaderButton(
      icon: Icons.arrow_back_rounded,
      tooltip: 'Retour',
      onPressed: () => Navigator.of(context).maybePop(),
    );
  }
}
