import 'package:studio_core/core/game_rules.dart';
import 'package:studio_core/core/level_plan.dart';
import 'package:studio_core/core/missions.dart';
import 'package:studio_core/core/stats.dart';

import 'cube_engine.dart';

const kupBulmacaId = 'oyun-3b-kup-bulmaca';

class CubeRules extends GameRules<CubeLevel> {
  @override
  String get gameId => kupBulmacaId;

  @override
  List<String> get optionalMechanics => const [];

  @override
  List<GameModeId> get modes => const [GameModeId.campaign, GameModeId.daily, GameModeId.weekly, GameModeId.challenge];

  @override
  List<GameStat> get gameStats => const [
        GameStat('cubes_solved', 'Tamamlanan küp', 'Cubes solved', scale: 5),
        GameStat('pieces_placed', 'Yerleşen parça', 'Pieces placed', scale: 40),
      ];

  @override
  List<MissionTemplate> get missionTemplates => const [
        MissionTemplate('cubes', 'cubes_solved', [2, 5, 10]),
      ];

  @override
  CubeLevel generate(LevelSpec spec) => generateCubeLevel(spec);

  @override
  Validation validate(CubeLevel level, LevelSpec spec) {
    final n = level.n;
    if (level.solutionPieces.length < 2) return const Validation.fail('too few pieces');
    final cover = List<int>.filled(n * n * n, 0);
    for (var i = 0; i < level.solutionPieces.length; i++) {
      final at = level.solutionAt[i];
      final cells = level.solutionPieces[i].cells;
      if (cells.length < 2) return const Validation.fail('single cube piece');
      for (final c in cells) {
        final x = at[0] + c[0], y = at[1] + c[1], z = at[2] + c[2];
        if (x >= n || y >= n || z >= n) return const Validation.fail('out of cube');
        cover[(z * n + y) * n + x]++;
      }
    }
    if (cover.any((c) => c != 1)) return const Validation.fail('not a tiling');
    // Çözüm oyunda oynanabilir mi?
    final g = CubeGame(level);
    for (var i = 0; i < g.pieces.length; i++) {
      g.pieces[i] = level.solutionPieces[i];
      if (!g.place(i, level.solutionAt[i])) return const Validation.fail('solution not placeable');
    }
    if (!g.won) return const Validation.fail('not won');
    return Validation.ok(level.solutionPieces.length);
  }

  static int stars({required int hints}) => hints == 0 ? 3 : (hints <= 1 ? 2 : 1);
}
