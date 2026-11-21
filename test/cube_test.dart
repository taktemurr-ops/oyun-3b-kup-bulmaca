import 'package:flutter_test/flutter_test.dart';
import 'package:oyun_3b_kup_bulmaca/oyun_3b_kup_bulmaca.dart';
import 'package:studio_core/core/level_plan.dart';

void main() {
  final rules = CubeRules();
  final planner = LevelPlanner(gameId: rules.gameId, optionalMechanics: rules.optionalMechanics);

  test('dönüşler: L dörtlüsünün 24 yönü var, kare ikilinin 3', () {
    expect(allRotations([[0, 0, 0], [1, 0, 0], [2, 0, 0], [0, 1, 0]]).length, 24);
    expect(allRotations([[0, 0, 0], [1, 0, 0]]).length, 3);
  });

  test('bölümler küpü eksiksiz böler; ipuçlarıyla çözülür', () {
    for (final lv in [1, 12, 50, 99, 230, 777, 2500, 9999, 33333, 49999]) {
      final gl = rules.build(planner.spec(lv));
      expect(gl.validation.ok, isTrue, reason: 'bölüm $lv');
      expect(gl.attempts, lessThan(40));
      final g = CubeGame(gl.puzzle);
      var guard = 0;
      while (!g.won && guard++ < 40) {
        g.hint();
      }
      expect(g.won, isTrue, reason: 'bölüm $lv');
    }
  });

  test('dokunulan kareyi kaplayarak yerleştirme ve geri alma', () {
    final l = rules.build(planner.spec(500)).puzzle;
    final g = CubeGame(l);
    g.pieces[0] = l.solutionPieces[0];
    final at = l.solutionAt[0];
    final c = l.solutionPieces[0].cells.last;
    final cell = [at[0] + c[0], at[1] + c[1], at[2] + c[2]];
    final a = g.anchorCovering(0, cell);
    expect(a, isNotNull);
    expect(g.place(0, a!), isTrue);
    expect(g.pickUp(cell), 0);
    expect(g.placed[0], isNull);
  });

  test('kayıt geri yüklenir', () {
    final l = rules.build(planner.spec(42)).puzzle;
    final g = CubeGame(l);
    g.hint();
    g.turn(1, rotZ);
    final r = CubeGame.restore(l, g.serialize());
    expect(r.serialize(), g.serialize());
  });
}
