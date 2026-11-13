import 'dart:async';
import 'package:flutter/material.dart';
import '../game/data.dart';
import '../game/rules.dart';
import '../game_controller.dart';
import '../services/storage.dart';
import 'theme.dart';

const endingLines = [
  '星幕随着最后一道防线的倒下而熄灭。',
  '星图重新落回天穹，塔顶的风第一次吹进地底的矿窖。',
  '你把塔修好了，也把星空还给了它。'
];
const activeDesc = {
  'compass': '传送到任意已到过的楼层（第 44、50 层除外），落在该层入口。',
  'pickaxe': '凿开身边的一面裂墙。',
  'flask': '当前生命翻倍，只能用一次。',
  'mirrorJump': '传送到本层中心对称的格子，目标必须是没有任何东西的空地。',
  'frostCore': '清除本层全部熔岩，永久变成空地。',
  'bomb': '炸掉身边所有非 BOSS 怪物（不给金币，算作已击败）。只能用一次。',
};

class GameModals extends StatelessWidget {
  const GameModals(this.c, {super.key});
  final GameController c;
  @override
  Widget build(BuildContext context) {
    final m = c.modal;
    if (m == null) return const SizedBox.shrink();
    final type = m['type'];
    final closable = !['story', 'ending'].contains(type);
    final title = <String, String>{
          'altar': '祭坛',
          'merchant': '商人',
          'compass': '传送罗盘',
          'items': '背包',
          'saves': m['mode'] == 'save' ? '存档' : '读档',
          'settings': '设置',
          'pause': '菜单',
          'ending': '通关',
          'inspect': '战斗预判'
        }[type] ??
        '';
    return LayoutBuilder(builder: (context, box) {
      final bodyContent = type == 'story'
          ? StoryBox(
              title: m['title'] ?? '',
              lines: (m['lines'] as List).cast<String>(),
              onDone: c.closeModal)
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: body(type, m));
      return Stack(children: [
        Positioned.fill(
            child: GestureDetector(
                onTap: closable ? c.closeModal : () {},
                child: const ColoredBox(color: Color(0x99070b0e)))),
        Align(
            alignment: Alignment.bottomCenter,
            child: TweenAnimationBuilder<double>(
              key: ValueKey(m),
              tween: Tween(begin: 24, end: 0),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              builder: (_, offset, child) =>
                  Transform.translate(offset: Offset(0, offset), child: child),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxWidth: 560, maxHeight: box.maxHeight * .88),
                child: Semantics(
                  scopesRoute: true,
                  explicitChildNodes: true,
                  namesRoute: true,
                  label: type == 'story' ? m['title'] : title,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    decoration: panel(
                        radius: 16,
                        border: gold.withOpacity(.6),
                        gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xff2a3034), Color(0xff1b232a)])),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Center(
                          child: Container(
                              width: 32,
                              height: 3,
                              decoration: BoxDecoration(
                                  color: line,
                                  borderRadius: BorderRadius.circular(2)))),
                      if (type != 'story')
                        Row(children: [
                          Expanded(child: Text(title, style: display(24))),
                          if (closable)
                            IconButton(
                                tooltip: '关闭',
                                onPressed: c.closeModal,
                                icon: const Icon(Icons.close, size: 25),
                                constraints: const BoxConstraints(
                                    minWidth: 48, minHeight: 48))
                        ]),
                      const SizedBox(height: 8),
                      Flexible(
                          child: SingleChildScrollView(
                              key: ValueKey('scroll-$type'),
                              child: bodyContent)),
                    ]),
                  ),
                ),
              ),
            )),
      ]);
    });
  }

  Widget note(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(text,
          style: const TextStyle(color: muted, fontSize: 13, height: 1.6)));
  Widget row(String title, String subtitle, List<Widget> buttons,
          {bool sold = false, String? artKey}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Opacity(
            opacity: sold ? .5 : 1,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: panel(color: const Color(0x152f393c)),
              child: LayoutBuilder(builder: (context, box) {
                final text = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(subtitle,
                            style: const TextStyle(
                                fontSize: 13, color: muted, height: 1.5))
                      ],
                    ]);
                final actions =
                    Column(mainAxisSize: MainAxisSize.min, children: [
                  for (var i = 0; i < buttons.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    buttons[i]
                  ]
                ]);
                if (MediaQuery.textScalerOf(context).scale(16) > 24) {
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (artKey != null)
                          Align(
                              alignment: Alignment.centerLeft,
                              child: art(artKey, width: 52, height: 52)),
                        text,
                        const SizedBox(height: 10),
                        actions
                      ]);
                }
                return Row(children: [
                  if (artKey != null) ...[
                    art(artKey, width: 52, height: 52),
                    const SizedBox(width: 12)
                  ],
                  Expanded(child: text),
                  if (buttons.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    actions
                  ]
                ]);
              }),
            ),
          ));
  Widget buy(String label, VoidCallback? action,
          {Key? key, bool ghost = false}) =>
      IntrinsicWidth(
          child: GameButton(label,
              key: key,
              onPressed: action,
              goldFill: !ghost,
              dangerText: ghost,
              fontSize: 13,
              height: 48,
              radius: 10));
  Widget menu(String title, VoidCallback? action,
          {bool primary = false, bool danger = false}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GameButton(title,
              onPressed: action, goldFill: primary, dangerText: danger));

  List<Widget> body(String type, Obj m) {
    final g = c.game;
    switch (type) {
      case 'inspect':
        if (g == null) return [];
        final pv = c.engine.preview(g, m['x'], m['y']);
        if (pv == null) return [note('这里已经没有怪物。')];
        final monster = pv['monster'];
        final id = pv['id'];
        final defense = effectiveDef(monster,
            hasTrait(monster, 'starVeil') ? c.engine.livingPillars(g) : 0);
        return [
          Center(child: art('sprite/$id', width: 100, height: 100)),
          Text(monster['name'],
              textAlign: TextAlign.center, style: display(22)),
          const SizedBox(height: 16),
          row('生命 ${monster['hp']}',
              '攻击 ${monster['atk']} · 防御 $defense · 金币 ${monster['gold']}', []),
          note(pv['canFight'] == true
              ? '预计损失 ${pv['loss']} 点生命'
              : pv['reason'] == 'unpierceable'
                  ? '当前攻击无法破防'
                  : '当前生命不足，无法战胜'),
        ];
      case 'altar':
        if (g == null) return [];
        final t = altarTier[g['floor']] ?? 0,
            price = altarPrice(g['altarBuys'] + 1);
        return [
          note('本座祭坛档位 $t · 全塔已购买 ${g['altarBuys']} 次 · 下一次花费 $price 金币'),
          note('你的金币：${g['hero']['gold']}'),
          for (final entry in {'hp': '生命', 'atk': '攻击', 'def': '防御'}.entries)
            row(entry.value, '每次 +${altarGain(t, entry.key)![entry.key]}', [
              buy(
                  '$price 金',
                  g['hero']['gold'] >= price
                      ? () => c.buyAltar(entry.key)
                      : null)
            ]),
          note('买防御通常比攻击划算；攻击只在需要越过数值门时购买。'),
        ];
      case 'merchant':
        if (g == null) return [];
        final List items = c.data.table('MERCHANTS')['${g['floor']}'] ?? [];
        return [
          note('你的金币：${g['hero']['gold']}'),
          if (items.isEmpty) note('这一层的商人已经没有可交易的东西了。'),
          for (final item in items) merchantRow(item, g),
        ];
      case 'compass':
        return [
          note('选择一层，传送到它的入口。第 44、50 层不能作为目标。'),
          if (c.compassTargets().isEmpty) note('还没有其他可以去的楼层。'),
          for (final floor in c.compassTargets())
            menu('第 $floor 层 · ${zoneName(floor)}', () {
              c.closeModal();
              c.useItem('compass', floor);
            })
        ];
      case 'items':
        if (g == null) return [];
        final ids = c.data
            .table('ACTIVE')
            .keys
            .where((k) => (g['items'][k] ?? 0) > 0)
            .toList();
        return [
          if (ids.isEmpty) note('背包是空的。'),
          for (final id in ids)
            row(
                '${c.name(id)} ×${g['items'][id] == double.infinity ? '∞' : g['items'][id]}',
                activeDesc[id] ?? '',
                [
                  buy(id == 'compass' ? '前往' : '使用', () {
                    if (id == 'compass') {
                      c.openModal({'type': 'compass'});
                    } else {
                      c.closeModal();
                      c.useItem(id);
                    }
                  })
                ],
                artKey: 'sprite/$id')
        ];
      case 'saves':
        return [
          for (final slot in c.slots) saveRow(slot, m['mode'] == 'save'),
          note('自动存档在换层时写入，只能读取。')
        ];
      case 'settings':
        return [
          const Text('音量'),
          Slider(
              value: (c.meta['volume'] as num).toDouble().clamp(0, 1),
              divisions: 20,
              semanticFormatterCallback: (v) => '${(v * 100).round()}%',
              onChanged: c.setVolume),
          menu(c.meta['muted'] ? '取消静音' : '静音',
              () => c.setMuted(!c.meta['muted']))
        ];
      case 'pause':
        return [
          menu('继续', c.closeModal, primary: true),
          menu(
              '存档',
              g == null
                  ? null
                  : () => c.openModal({'type': 'saves', 'mode': 'save'})),
          menu('读档', () => c.openModal({'type': 'saves', 'mode': 'load'})),
          menu('设置', () => c.openModal({'type': 'settings'})),
          menu('返回首页', c.backToTitle, danger: true),
        ];
      case 'ending':
        return [
          Text('星幕已关闭',
              textAlign: TextAlign.center, style: display(18, spacing: 4)),
          const SizedBox(height: 12),
          for (final line in endingLines)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(line,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, height: 1.8))),
          if (g != null) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final e in {
                '层数': '50 / 50',
                '攻击': '${g['hero']['atk']}',
                '防御': '${g['hero']['def']}',
                '金币': '${g['hero']['gold']}',
                '祭坛购买': '${g['altarBuys']} 次'
              }.entries)
                Container(
                    width: 140,
                    padding: const EdgeInsets.all(10),
                    decoration: panel(),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.key,
                              style:
                                  const TextStyle(fontSize: 12, color: muted)),
                          Text(e.value, style: display(16, color: ink)),
                        ]))
            ]),
          ],
          const SizedBox(height: 12),
          menu('返回首页', c.backToTitle, primary: true),
        ];
      default:
        return [];
    }
  }

  Widget merchantRow(Obj item, Obj g) {
    final sold = item['unlimited'] != true &&
        (g['soldOut'] as List).contains(item['id']);
    final recycle = item['recycle'] != null;
    final can = !sold &&
        (recycle
            ? (g['hero']['keys'][item['recycle']] ?? 0) > 0
            : g['hero']['gold'] >= item['price']);
    final desc = recycle
        ? '回收${c.name(item['recycle'])}：每把 ${item['gold']} 金币（不限次）'
        : [
            for (final e in (item['items'] as Map? ?? {}).entries)
              '${c.name(e.key)} ×${e.value}',
            if (item['hp'] != null) '生命 +${item['hp']}',
          ].join('、');
    return row(
        desc,
        sold
            ? '已售完'
            : recycle
                ? '回收：每把 +${item['gold']} 金币（不限次）'
                : '价格 ${item['price']} 金币',
        [
          buy(
              sold
                  ? '售完'
                  : recycle
                      ? '回收'
                      : '${item['price']} 金',
              can ? () => c.merchantBuy(item['id']) : null)
        ],
        sold: sold);
  }

  Widget saveRow(Obj slot, bool save) {
    final String name = slot['name'];
    final entry = slot['entry'];
    final manual = manualSlots.contains(name);
    String summary = '空';
    if (entry != null) {
      try {
        final d = DateTime.fromMillisecondsSinceEpoch(entry['savedAt']);
        String two(int n) => '$n'.padLeft(2, '0');
        summary =
            '第 ${entry['floor']} 层 · ${d.year}/${d.month}/${d.day} ${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
      } catch (_) {
        summary = '第 ${entry['floor']} 层 · ';
      }
    }
    return row(
        name == autoSlot ? '自动存档' : '存档 ${int.parse(name) + 1}', summary, [
      if (save)
        buy('存入', manual && c.game != null ? () => c.saveSlot(name) : null,
            key: ValueKey('save-$name'))
      else
        buy('读取', entry == null ? null : () => c.loadSlot(name),
            key: ValueKey('load-$name')),
      if (manual && entry != null)
        buy('删除', () => c.deleteSlot(name),
            ghost: true, key: ValueKey('delete-$name')),
    ]);
  }
}

class StoryBox extends StatefulWidget {
  const StoryBox(
      {super.key,
      required this.title,
      required this.lines,
      required this.onDone});
  final String title;
  final List<String> lines;
  final VoidCallback onDone;
  @override
  State<StoryBox> createState() => _StoryBoxState();
}

class _StoryBoxState extends State<StoryBox> {
  int index = 0, shown = 0;
  Timer? timer;
  String get current => widget.lines[index];
  bool get typing => shown < current.length;
  @override
  void initState() {
    super.initState();
    start();
  }

  void start() {
    timer?.cancel();
    shown = 0;
    if (current.isEmpty) return;
    timer = Timer.periodic(const Duration(milliseconds: 34), (_) {
      if (!mounted) return;
      setState(() => shown++);
      if (!typing) timer?.cancel();
    });
  }

  void next() {
    if (typing) {
      timer?.cancel();
      setState(() => shown = current.length);
    } else if (index < widget.lines.length - 1) {
      setState(() {
        index++;
        start();
      });
    } else {
      widget.onDone();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.title, style: display(22, spacing: 3)),
            const SizedBox(height: 16),
            GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: next,
                child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 80),
                    child: Text(
                        '${current.substring(0, shown)}${typing ? '▍' : ''}',
                        style: const TextStyle(fontSize: 16, height: 1.8)))),
            const SizedBox(height: 16),
            Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Text('${index + 1} / ${widget.lines.length}',
                      style: const TextStyle(fontSize: 12, color: muted)),
                  TextButton(
                      onPressed: widget.onDone, child: const Text('跳过全部')),
                  IntrinsicWidth(
                      child: GameButton(
                          typing
                              ? '看完本句'
                              : index == widget.lines.length - 1
                                  ? '继续'
                                  : '下一句 ▸',
                          goldFill: true,
                          onPressed: next)),
                ]),
          ]);
}
