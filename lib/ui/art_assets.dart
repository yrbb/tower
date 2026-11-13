import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Atlas indexes are row-major: four equal cells per row.
const spriteSheets = <String, List<String>>{
  'creatures_a': [
    'mossBlob',
    'caveBat',
    'boneSoldier',
    'sporeMage',
    'stoneBeetle',
    'boneGuard',
    'jailer',
    'wardenBoss',
    'tideCrab',
    'cogPuppet',
    'tideWitch',
    'sharkGuard',
    'deepWarrior',
    'ironClam',
    'twinBlade',
    'clawFiend'
  ],
  'creatures_b': [
    'tideBoss',
    'mirrorShade',
    'echoMage',
    'twinShade',
    'glassGolem',
    'mirrorBoss',
    'slagSoldier',
    'magmaHound',
    'forgeMage',
    'ironKnight',
    'hammerLord',
    'coreGolem',
    'lavaDrake',
    'forgeBoss',
    'stardustWraith',
    'auraPriest'
  ],
  'creatures_c': [
    'voidBlade',
    'highAuraPriest',
    'astralMage',
    'domeGuard',
    'pillarGuard',
    'endLord',
    'hero',
    'guide',
    'merchant',
    'altar',
    'hp',
    'gold',
    'atk',
    'def',
    'bag',
    'tower'
  ],
  'items_a': [
    'redCrystal',
    'blueCrystal',
    'redPotion',
    'bluePotion',
    'yellowKey',
    'blueKey',
    'redKey',
    'oldIronSword',
    'woodShield',
    'tideShield',
    'tideSword',
    'mirrorShield',
    'mirrorSword',
    'furnaceShield',
    'meltSword',
    'starShield'
  ],
  'items_b': [
    'starSword',
    'tideSpear',
    'charm',
    'dragonFang',
    'compass',
    'pickaxe',
    'flask',
    'mirrorJump',
    'frostCore',
    'bomb',
    'stair_up',
    'stair_down',
    'door_y',
    'door_b',
    'door_r',
    'gate'
  ],
};
final spriteIndex = <String, (String, int)>{
  for (final sheet in spriteSheets.entries)
    for (var i = 0; i < sheet.value.length; i++) sheet.value[i]: (sheet.key, i),
};
final _images = <String, Future<ui.Image>>{};
final _decoded = <String, ui.Image>{};
Future<ui.Image> loadAtlas(String name) => _images.putIfAbsent(name, () async {
      final bytes = await rootBundle.load('assets/art/$name.png');
      final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
      final frame = await codec.getNextFrame();
      codec.dispose();
      return _decoded[name] = frame.image;
    });

class SpriteArt extends StatelessWidget {
  const SpriteArt(this.id, {super.key, this.width, this.height, this.label});
  final String id;
  final double? width, height;
  final String? label;
  @override
  Widget build(BuildContext context) {
    final source = spriteIndex[id]!;
    return Semantics(
        label: label,
        image: label != null,
        excludeSemantics: label == null,
        child: SizedBox(
            width: width,
            height: height,
            child: FutureBuilder<ui.Image>(
                future: loadAtlas(source.$1),
                initialData: _decoded[source.$1],
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Icon(Icons.broken_image_outlined, size: 16);
                  }
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  return CustomPaint(
                      size: Size(width ?? 32, height ?? 32),
                      painter: _SpritePainter(snapshot.data!, source.$2));
                })));
  }
}

class _SpritePainter extends CustomPainter {
  _SpritePainter(this.image, this.index);
  final ui.Image image;
  final int index;
  @override
  void paint(Canvas canvas, Size size) {
    final w = image.width / 4, h = image.height / 4;
    final source = Rect.fromLTWH((index % 4) * w, (index ~/ 4) * h, w, h);
    final side = size.shortestSide;
    final target = Rect.fromCenter(
        center: size.center(Offset.zero), width: side, height: side);
    canvas.drawImageRect(
        image, source, target, Paint()..filterQuality = FilterQuality.none);
  }

  @override
  bool shouldRepaint(_SpritePainter old) =>
      old.image != image || old.index != index;
}
