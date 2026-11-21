import 'dart:convert';

import 'package:studio_core/core/level_plan.dart';
import 'package:studio_core/core/rng.dart';

/// 3B Küp Bulmaca: küp parçalara bölünür; parçaları döndürüp yerine koyarak
/// kutuyu eksiksiz doldur. Koordinat: x (sağ), y (derinlik), z (yukarı kat).

typedef V3 = List<int>;

List<V3> normalize3(List<V3> cells) {
  var mx = 99, my = 99, mz = 99;
  for (final c in cells) {
    if (c[0] < mx) mx = c[0];
    if (c[1] < my) my = c[1];
    if (c[2] < mz) mz = c[2];
  }
  final out = [for (final c in cells) [c[0] - mx, c[1] - my, c[2] - mz]];
  out.sort((a, b) => a[2] != b[2] ? a[2] - b[2] : (a[1] != b[1] ? a[1] - b[1] : a[0] - b[0]));
  return out;
}

String key3(List<V3> cells) => cells.map((c) => '${c[0]},${c[1]},${c[2]}').join(';');

/// Eksenler etrafında 90° döndürmeler.
List<V3> rotX(List<V3> c) => [for (final v in c) [v[0], -v[2], v[1]]];
List<V3> rotY(List<V3> c) => [for (final v in c) [v[2], v[1], -v[0]]];
List<V3> rotZ(List<V3> c) => [for (final v in c) [-v[1], v[0], v[2]]];

/// Bütün dönüşler (en çok 24, tekil): üç eksen döndürmesinin kapanışı.
List<List<V3>> allRotations(List<V3> cells) {
  final start = normalize3(cells);
  final seen = <String>{key3(start)};
  final out = <List<V3>>[start];
  for (var qi = 0; qi < out.length; qi++) {
    for (final f in [rotX, rotY, rotZ]) {
      final n = normalize3(f(out[qi]));
      if (seen.add(key3(n))) out.add(n);
    }
  }
  return out;
}

class CubePiece {
  final List<V3> cells; // gösterilen yönde, normalize
  final int color;
  const CubePiece(this.cells, this.color);
  int get size => cells.length;
  CubePiece turned(List<V3> Function(List<V3>) f) => CubePiece(normalize3(f(cells)), color);
}

class CubeLevel {
  final int n; // kenar
  final List<CubePiece> solutionPieces; // çözüm yönünde
  final List<V3> solutionAt; // her parçanın çözümdeki en küçük köşesi
  final List<int> shownTurn; // her parça hangi dönüşle gösterilir
  final int seed, difficulty;
  const CubeLevel({
    required this.n,
    required this.solutionPieces,
    required this.solutionAt,
    required this.shownTurn,
    required this.seed,
    required this.difficulty,
  });
}

CubeLevel generateCubeLevel(LevelSpec spec) {
  final r = SeededRandom(mixSeed([spec.seed, 3333]));
  final d = spec.difficulty.clamp(1, 10);
  final n = d <= 3 ? 2 : 3;
  final total = n * n * n;
  final owner = List<int>.filled(total, -1);
  int idx(int x, int y, int z) => (z * n + y) * n + x;
  final maxSize = n == 2 ? 3 : (d >= 7 ? 5 : 4);
  var pieceId = 0;
  final order = List<int>.generate(total, (i) => i);
  r.shuffle(order);
  for (final s in order) {
    if (owner[s] >= 0) continue;
    final want = 2 + r.nextInt(maxSize - 1);
    final cells = [s];
    owner[s] = pieceId;
    while (cells.length < want) {
      final frontier = <int>[];
      for (final c in cells) {
        final x = c % n, y = (c ~/ n) % n, z = c ~/ (n * n);
        for (final dlt in const [[1, 0, 0], [-1, 0, 0], [0, 1, 0], [0, -1, 0], [0, 0, 1], [0, 0, -1]]) {
          final nx = x + dlt[0], ny = y + dlt[1], nz = z + dlt[2];
          if (nx < 0 || ny < 0 || nz < 0 || nx >= n || ny >= n || nz >= n) continue;
          final k = idx(nx, ny, nz);
          if (owner[k] < 0) frontier.add(k);
        }
      }
      if (frontier.isEmpty) break;
      final k = frontier[r.nextInt(frontier.length)];
      owner[k] = pieceId;
      cells.add(k);
    }
    pieceId++;
  }
  // Tek kareli parçaları komşusuna kat.
  for (var k = 0; k < total; k++) {
    final id = owner[k];
    if (owner.where((o) => o == id).length > 1) continue;
    final x = k % n, y = (k ~/ n) % n, z = k ~/ (n * n);
    for (final dlt in const [[1, 0, 0], [-1, 0, 0], [0, 1, 0], [0, -1, 0], [0, 0, 1], [0, 0, -1]]) {
      final nx = x + dlt[0], ny = y + dlt[1], nz = z + dlt[2];
      if (nx < 0 || ny < 0 || nz < 0 || nx >= n || ny >= n || nz >= n) continue;
      owner[k] = owner[idx(nx, ny, nz)];
      break;
    }
  }
  final ids = owner.toSet().toList()..sort();
  final pieces = <CubePiece>[];
  final at = <V3>[];
  final turns = <int>[];
  for (var i = 0; i < ids.length; i++) {
    final cells = <V3>[
      for (var k = 0; k < total; k++)
        if (owner[k] == ids[i]) [k % n, (k ~/ n) % n, k ~/ (n * n)]
    ];
    var mx = 99, my = 99, mz = 99;
    for (final c in cells) {
      if (c[0] < mx) mx = c[0];
      if (c[1] < my) my = c[1];
      if (c[2] < mz) mz = c[2];
    }
    final p = CubePiece(normalize3(cells), 1 + i % 8);
    pieces.add(p);
    at.add([mx, my, mz]);
    turns.add(d >= 2 ? r.nextInt(allRotations(p.cells).length) : 0);
  }
  return CubeLevel(n: n, solutionPieces: pieces, solutionAt: at, shownTurn: turns, seed: spec.seed, difficulty: d);
}

class CubeGame {
  final CubeLevel level;
  late List<CubePiece> pieces; // oyuncunun gördüğü yön
  late List<V3?> placed;
  int moves = 0;

  CubeGame(this.level) {
    pieces = [
      for (var i = 0; i < level.solutionPieces.length; i++)
        CubePiece(allRotations(level.solutionPieces[i].cells)[level.shownTurn[i]], level.solutionPieces[i].color)
    ];
    placed = List<V3?>.filled(pieces.length, null);
  }

  int get n => level.n;
  int idx(int x, int y, int z) => (z * n + y) * n + x;

  List<int> occupancy({int except = -1}) {
    final occ = List<int>.filled(n * n * n, -1);
    for (var i = 0; i < pieces.length; i++) {
      final at = placed[i];
      if (at == null || i == except) continue;
      for (final c in pieces[i].cells) {
        occ[idx(at[0] + c[0], at[1] + c[1], at[2] + c[2])] = i;
      }
    }
    return occ;
  }

  bool canPlace(int i, V3 at, {List<int>? occ}) {
    final o = occ ?? occupancy(except: i);
    for (final c in pieces[i].cells) {
      final x = at[0] + c[0], y = at[1] + c[1], z = at[2] + c[2];
      if (x < 0 || y < 0 || z < 0 || x >= n || y >= n || z >= n) return false;
      if (o[idx(x, y, z)] >= 0) return false;
    }
    return true;
  }

  /// Dokunulan hücreyi kaplayacak bir konum bulur.
  V3? anchorCovering(int i, V3 cell) {
    final occ = occupancy(except: i);
    for (final c in pieces[i].cells) {
      final at = [cell[0] - c[0], cell[1] - c[1], cell[2] - c[2]];
      if (canPlace(i, at, occ: occ)) return at;
    }
    return null;
  }

  bool place(int i, V3 at) {
    if (placed[i] != null || !canPlace(i, at)) return false;
    placed[i] = at;
    moves++;
    return true;
  }

  /// Hücredeki parçayı geri alır; parça numarası ya da -1.
  int pickUp(V3 cell) {
    final o = occupancy();
    final i = o[idx(cell[0], cell[1], cell[2])];
    if (i >= 0) {
      placed[i] = null;
      moves++;
    }
    return i;
  }

  void turn(int i, List<V3> Function(List<V3>) f) {
    if (placed[i] != null) return;
    pieces[i] = pieces[i].turned(f);
  }

  bool get won => placed.every((p) => p != null);

  int get filled => occupancy().where((o) => o >= 0).length;

  /// İpucu: yerleşmemiş bir parçayı çözüm yönüne çevirip çözüm yerine koyar
  /// (o yerdeki parçaları geri alarak).
  int? hint() {
    for (var i = 0; i < pieces.length; i++) {
      final sol = level.solutionPieces[i];
      final at = level.solutionAt[i];
      if (placed[i] != null && key3(pieces[i].cells) == key3(sol.cells) && _same(placed[i]!, at)) continue;
      placed[i] = null;
      pieces[i] = sol;
      final occ = occupancy();
      for (final c in sol.cells) {
        final o = occ[idx(at[0] + c[0], at[1] + c[1], at[2] + c[2])];
        if (o >= 0) placed[o] = null;
      }
      placed[i] = at;
      moves++;
      return i;
    }
    return null;
  }

  static bool _same(V3 a, V3 b) => a[0] == b[0] && a[1] == b[1] && a[2] == b[2];

  String serialize() => jsonEncode({
        'p': [for (final p in pieces) p.cells.expand((e) => e).toList()],
        'a': placed,
        'm': moves,
      });

  static CubeGame restore(CubeLevel l, String snap) {
    final g = CubeGame(l);
    final j = jsonDecode(snap) as Map<String, dynamic>;
    final ps = j['p'] as List;
    for (var i = 0; i < g.pieces.length && i < ps.length; i++) {
      final flat = [for (final v in ps[i] as List) (v as num).toInt()];
      g.pieces[i] = CubePiece([for (var k = 0; k + 2 < flat.length; k += 3) [flat[k], flat[k + 1], flat[k + 2]]], g.pieces[i].color);
    }
    final a = j['a'] as List;
    for (var i = 0; i < g.placed.length && i < a.length; i++) {
      final e = a[i] as List?;
      g.placed[i] = e == null ? null : [for (final v in e) (v as num).toInt()];
    }
    g.moves = (j['m'] as num).toInt();
    return g;
  }
}
