import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'art_assets.dart';

const bg = Color(0xff161b22),
    ink = Color(0xffeee5d6),
    muted = Color(0xffb4b6b4);
const gold = Color(0xffcaa65e),
    goldSoft = Color(0xffead6a3),
    line = Color(0xff53534c);
const good = Color(0xff9ec887), danger = Color(0xffee8e7d);
const goldGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xff5a7040), Color(0xff35472c)]);
const _legacyArt = <String, String>{
  'hero/hero': 'hero',
  'ui/icon_hp': 'hp',
  'ui/icon_gold': 'gold',
  'ui/icon_atk': 'atk',
  'ui/icon_def': 'def',
  'ui/icon_crown': 'tower',
  'items/key_y': 'yellowKey',
  'items/key_b': 'blueKey',
  'items/key_r': 'redKey',
  'items/gem_a': 'redCrystal',
  'items/gem_p': 'blueCrystal',
  'items/potion_s': 'redPotion',
  'items/potion_h': 'bluePotion',
  'items/sword': 'oldIronSword',
  'items/shield': 'woodShield',
  'tiles/shop': 'merchant',
  'tiles/stair_up': 'stair_up',
  'tiles/stair_down': 'stair_down',
  'tiles/door_y': 'door_y',
  'tiles/door_b': 'door_b',
  'tiles/door_r': 'door_r',
};
Widget art(String? key,
    {double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
    String? label}) {
  if (key == null || key.isEmpty) return const SizedBox.shrink();
  final id = key.startsWith('sprite/') ? key.substring(7) : _legacyArt[key];
  if (id != null && spriteIndex.containsKey(id)) {
    return SpriteArt(id, width: width, height: height, label: label);
  }
  return SvgPicture.asset('assets/images/$key.svg',
      width: width,
      height: height,
      fit: fit,
      semanticsLabel: label,
      excludeFromSemantics: label == null);
}

TextStyle display(double size, {Color color = goldSoft, double spacing = 0}) =>
    TextStyle(
        fontSize: size,
        color: color,
        fontWeight: FontWeight.w700,
        letterSpacing: spacing);
BoxDecoration panel(
        {double radius = 8,
        Color border = line,
        Gradient? gradient,
        Color? color}) =>
    BoxDecoration(
        color: gradient == null ? color ?? const Color(0xff20272c) : null,
        gradient: gradient,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(radius));

class GameButton extends StatelessWidget {
  const GameButton(this.label,
      {super.key,
      this.onPressed,
      this.goldFill = false,
      this.dangerText = false,
      this.icon,
      this.height = 52,
      this.fontSize = 16,
      this.radius = 8});
  final String label;
  final VoidCallback? onPressed;
  final bool goldFill, dangerText;
  final String? icon;
  final double height, fontSize, radius;
  @override
  Widget build(BuildContext context) {
    final primary = goldFill;
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (icon != null) ...[
          art(icon, width: 32, height: 32),
          const SizedBox(width: 8)
        ],
        Flexible(
            child: Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: fontSize,
                    color: dangerText ? danger : ink,
                    fontWeight: FontWeight.w600))),
      ]),
    );
    return Semantics(
      button: true,
      enabled: onPressed != null,
      child: Opacity(
        opacity: onPressed == null ? .42 : 1,
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: panel(
                radius: radius,
                border: primary ? gold : line,
                gradient: primary
                    ? goldGradient
                    : const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xff343c3d), Color(0xff242b2d)])),
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(radius),
              child: ConstrainedBox(
                  constraints: BoxConstraints(
                      minHeight: height < 48 ? 48 : height, minWidth: 48),
                  child: content),
            ),
          ),
        ),
      ),
    );
  }
}
