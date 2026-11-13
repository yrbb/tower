import 'dart:convert';

typedef Obj = Map<String, dynamic>;

// JSON values retain JavaScript truthiness at the original storage boundary.
bool jsTruthy(dynamic value) =>
    value != null &&
    value != false &&
    value != 0 &&
    value != '' &&
    !(value is num && value.isNaN);

class GameData {
  GameData.fromJson(String text)
      : root = jsonDecode(text, reviver: (key, value) {
          if (value is Map && value[r'$number'] == 'Infinity') {
            return double.infinity;
          }
          return value;
        });

  final Obj root;
  Obj get maps => root['maps'];
  Obj get tables => root['data'];
  Obj get art => root['art'];
  Obj table(String name) => tables[name];
  String name(String id) {
    for (final t in [
      'CONSUMABLES',
      'KEYS',
      'GEAR',
      'HOLD',
      'ACTIVE',
      'MONSTERS'
    ]) {
      if (table(t)[id] != null) return table(t)[id]['name'];
    }
    return id;
  }
}

const zones = ['苔藓地窖', '潮汐机关城', '镜廊', '熔炉深处', '星穹'];
const bossFloors = [10, 20, 30, 40, 50];
String zoneName(int floor) =>
    floor >= 1 && floor <= 50 ? zones[(floor - 1) ~/ 10] : '';
