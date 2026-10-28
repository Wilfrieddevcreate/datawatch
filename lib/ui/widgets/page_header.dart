import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Page d'onglet avec l'en-tête DataWatch :
/// - une barre fixe (marque ou retour, actions) qui se pose sur le contenu
///   dès qu'il défile et affiche alors un titre compact ;
/// - un grand titre condensé, sa ligne de contexte et son sous-titre.
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
    this.largeTitle = true,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 32),
  });

  final String title;
  final List<Widget> children;

  /// Contexte au-dessus du titre (période, date…), en minuscules.
  final String? overline;
  final Widget? subtitle;

  /// Titre affiché dans la barre une fois le grand titre défilé (par défaut : [title]).
  final String? compactTitle;

  /// À gauche de la barre : la marque par défaut, un bouton retour sur une
  /// page secondaire ([DwBackButton]).
  final Widget? leading;

  /// Visuel placé devant le grand titre (icône d'application…).
  final Widget? titleLeading;
  final List<Widget> actions;
  final Future<void> Function()? onRefresh;

  /// Faux : pas de grand titre, le contenu commence sous la barre.
  final bool largeTitle;
  final EdgeInsetsGeometry padding;

  static const double barHeight = 56;

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
        if (widget.largeTitle)
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
            color: context.dw.text,
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
              showTitleFrom: widget.largeTitle ? 44 : 120,
              leading: widget.leading ?? const DwWordmark(),
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
    required this.showTitleFrom,
    required this.leading,
    required this.actions,
  });

  final double topInset;
  final double offset;
  final String title;
  final double showTitleFrom;
  final Widget leading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    // Le fond et le filet apparaissent dès le premier défilement, le titre
    // compact quand le grand titre passe sous la barre.
    final surface = (offset / 16).clamp(0.0, 1.0);
    final titleIn = ((offset - showTitleFrom) / 24).clamp(0.0, 1.0);

    return Container(
      height: topInset + DwPage.barHeight,
      padding: EdgeInsets.only(top: topInset, left: 16, right: 6),
      decoration: BoxDecoration(
        color: c.background.withValues(alpha: surface),
        border: Border(
          bottom: BorderSide(color: c.divider.withValues(alpha: surface)),
        ),
      ),
      child: NavigationToolbar(
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
            offset: Offset(0, 6 * (1 - titleIn)),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DwFonts.style(
                DwFonts.display,
                18,
                700,
                letterSpacing: -0.4,
              ),
            ),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, a) in actions.indexed) ...[
              if (i > 0) const SizedBox(width: 2),
              a,
            ],
          ],
        ),
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
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (overline != null) ...[
            Text(overline!, style: DwFonts.label(c.textSecondary)),
            const SizedBox(height: 6),
          ],
          Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 14)],
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: DwFonts.title(36).copyWith(color: c.text),
                  ),
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            DefaultTextStyle.merge(
              style: t.bodyMedium!.copyWith(color: c.textSecondary),
              child: subtitle!,
            ),
          ],
        ],
      ),
    );
    // Le grand titre s'efface en passant sous la barre.
    return ValueListenableBuilder<double>(
      valueListenable: offset,
      builder: (context, o, child) =>
          Opacity(opacity: (1 - o / 90).clamp(0.0, 1.0), child: child),
      child: content,
    );
  }
}

/// Le logo DataWatch : un petit réservoir, encre et lime.
class DwMark extends StatelessWidget {
  const DwMark({super.key, this.height = 26, this.ink, this.water});

  final double height;
  final Color? ink;
  final Color? water;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    final w = height * 18 / 26;
    return Semantics(
      label: 'DataWatch',
      image: true,
      child: Container(
        width: w,
        height: height,
        padding: EdgeInsets.all(w / 6),
        alignment: Alignment.bottomCenter,
        decoration: BoxDecoration(
          color: ink ?? c.strong,
          borderRadius: BorderRadius.circular(height * 0.23),
        ),
        child: Container(
          height: height * 0.35,
          decoration: BoxDecoration(
            color: water ?? c.accent,
            borderRadius: BorderRadius.circular(height * 0.11),
          ),
        ),
      ),
    );
  }
}

/// La marque : le logo et le nom.
class DwWordmark extends StatelessWidget {
  const DwWordmark({super.key, this.color});

  /// Couleur du nom et du logo (texte par défaut) ; sur fond sombre, le texte clair.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DwMark(ink: color ?? c.strong),
        const SizedBox(width: 10),
        ExcludeSemantics(
          child: Text(
            'DataWatch',
            style: DwFonts.style(
              DwFonts.display,
              21,
              700,
              letterSpacing: -0.4,
            ).copyWith(color: color ?? c.text),
          ),
        ),
      ],
    );
  }
}

/// Bouton de la barre d'en-tête : l'icône seule, avec pastille optionnelle.
class DwHeaderButton extends StatelessWidget {
  const DwHeaderButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.badgeColor,
    this.color,
    this.badgeBorder,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  /// Pastille en haut à droite (alerte en cours), absente si null.
  final Color? badgeColor;
  final Color? color;
  final Color? badgeBorder;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: onPressed,
          tooltip: tooltip,
          style: IconButton.styleFrom(fixedSize: const Size(44, 44)),
          icon: Icon(icon, color: color ?? c.text, size: 22),
        ),
        if (badgeColor != null)
          Positioned(
            top: 8,
            right: 9,
            child: IgnorePointer(
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: badgeBorder ?? c.background,
                    width: 2,
                  ),
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
    return Transform.translate(
      offset: const Offset(-10, 0),
      child: DwHeaderButton(
        icon: Icons.arrow_back,
        tooltip: 'Retour',
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    );
  }
}
