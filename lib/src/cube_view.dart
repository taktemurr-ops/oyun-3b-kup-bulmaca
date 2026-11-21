import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:studio_core/app/game_api.dart';
import 'package:studio_core/app/services/audio.dart';
import 'package:studio_core/core/game_rules.dart';

import 'cube_engine.dart';
import 'cube_rules.dart';

class CubeView extends StatefulWidget {
  final PlayContext ctx;
  const CubeView({super.key, required this.ctx});

  @override
  State<CubeView> createState() => _CubeViewState();
}

class _CubeViewState extends State<CubeView> {
  late CubeLevel level;
  late CubeGame game;
  int? _selected;
  int _seconds = 0, _hints = 0;
  Timer? _timer;
  bool _ended = false;

  PlayContext get ctx => widget.ctx;
  bool get _tr => ctx.lang == 'tr';

  @override
  void initState() {
    super.initState();
    level = (ctx.generated as GeneratedLevel<CubeLevel>).puzzle;
    final snap = ctx.resume['snap'];
    game = snap is String ? CubeGame.restore(level, snap) : CubeGame(level);
    _seconds = (ctx.resume['secs'] as num?)?.toInt() ?? 0;
    _hints = (ctx.resume['hints'] as num?)?.toInt() ?? 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_ended && mounted) setState(() => _seconds++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _persist() => ctx.saveResume({'snap': game.serialize(), 'secs': _seconds, 'hints': _hints});

  void _tapCell(int x, int y, int z) {
    if (_ended) return;
    final s = _selected;
    if (s != null && game.placed[s] == null) {
      final at = game.anchorCovering(s, [x, y, z]);
      if (at == null || !game.place(s, at)) {
        ctx.sfx(Sfx.error);
        return;
      }
      ctx.sfx(Sfx.place);
      setState(() => _selected = null);
      _persist();
      if (game.won) _win();
      return;
    }
    if (game.pickUp([x, y, z]) >= 0) {
      ctx.sfx(Sfx.tap);
      setState(() {});
      _persist();
    }
  }

  void _win() {
    if (_ended) return;
    _ended = true;
    _timer?.cancel();
    ctx.sfx(Sfx.win);
    ctx.finish(RoundResult(
      won: true,
      score: (level.n * level.n * level.n * 15 - _hints * 30).clamp(10, 1 << 20),
      stars: CubeRules.stars(hints: _hints),
      seconds: _seconds,
      moves: game.moves,
      hintsUsed: _hints,
      undosUsed: 0,
      gameStats: {'cubes_solved': 1, 'pieces_placed': game.pieces.length},
    ));
  }

  Future<void> _useHint() async {
    if (!await ctx.requestHint()) return;
    _hints++;
    setState(() {
      game.hint();
      _selected = null;
    });
    _persist();
    if (game.won) _win();
  }

  Color colorOf(int c) => ctx.pieceColors[(c - 1) % ctx.pieceColors.length];

  @override
  Widget build(BuildContext context) {
    final n = level.n;
    return LayoutBuilder(builder: (context, cons) {
      final layerCell = math.max(16.0, math.min((cons.maxWidth - 24 - (n - 1) * 14) / (n * n), 44.0));
      final isoS = math.min(cons.maxWidth / (n * 2.6), cons.maxHeight * 0.26 / (n * 1.6));
      return Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(children: [
            Expanded(
              child: Text(
                  _tr ? 'Doldurulan: ${game.filled} / ${n * n * n}' : 'Filled: ${game.filled} / ${n * n * n}',
                  style: Theme.of(context).textTheme.titleSmall),
            ),
            const Icon(Icons.timer_outlined, size: 18),
            Text(' ${_seconds ~/ 60}:${(_seconds % 60).toString().padLeft(2, '0')}'),
          ]),
        ),
        SizedBox(
          height: isoS * n * 1.9 + 8,
          child: CustomPaint(
            size: Size(cons.maxWidth, isoS * n * 1.9 + 8),
            painter: _IsoPainter(
              n: n,
              s: isoS,
              cubes: [
                for (var i = 0; i < game.pieces.length; i++)
                  if (game.placed[i] != null)
                    for (final c in game.pieces[i].cells)
                      ([game.placed[i]![0] + c[0], game.placed[i]![1] + c[1], game.placed[i]![2] + c[2]], colorOf(game.pieces[i].color))
              ],
              frame: true,
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Katlar: soldan sağa alt kattan üst kata.
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var z = 0; z < n; z++) ...[
            if (z > 0) const SizedBox(width: 14),
            Column(children: [
              Text(_tr ? 'Kat ${z + 1}' : 'Layer ${z + 1}', style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 2),
              _layer(z, layerCell),
            ]),
          ],
        ]),
        const SizedBox(height: 8),
        Expanded(
          child: SingleChildScrollView(
            child: Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: [
              for (var i = 0; i < game.pieces.length; i++)
                if (game.placed[i] == null) _trayPiece(i),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 4),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _turnButton('X', rotX),
            _turnButton('Y', rotY),
            _turnButton('Z', rotZ),
            IconButton.filledTonal(onPressed: _ended ? null : _useHint, icon: const Icon(Icons.lightbulb), tooltip: ctx.t('hint')),
          ]),
        ),
      ]);
    });
  }

  Widget _turnButton(String axis, List<V3> Function(List<V3>) f) => FilledButton.tonalIcon(
        onPressed: _selected == null || _ended
            ? null
            : () => setState(() {
                  game.turn(_selected!, f);
                  _persist();
                }),
        icon: const Icon(Icons.rotate_right, size: 18),
        label: Text(axis),
      );

  Widget _layer(int z, double c) {
    final n = level.n;
    final occ = game.occupancy();
    return Container(
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.all(3),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        for (var y = 0; y < n; y++)
          Row(mainAxisSize: MainAxisSize.min, children: [
            for (var x = 0; x < n; x++)
              Semantics(
                button: true,
                label: 'cell $x $y $z',
                child: GestureDetector(
                  onTap: () => _tapCell(x, y, z),
                  child: Container(
                    width: c,
                    height: c,
                    margin: const EdgeInsets.all(1.5),
                    decoration: BoxDecoration(
                      color: occ[game.idx(x, y, z)] >= 0
                          ? colorOf(game.pieces[occ[game.idx(x, y, z)]].color)
                          : Colors.white.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    alignment: Alignment.center,
                    child: ctx.colorBlind && occ[game.idx(x, y, z)] >= 0
                        ? Text(ctx.symbol(game.pieces[occ[game.idx(x, y, z)]].color - 1), style: const TextStyle(fontSize: 10))
                        : null,
                  ),
                ),
              ),
          ]),
      ]),
    );
  }

  Widget _trayPiece(int i) {
    final p = game.pieces[i];
    const s = 13.0;
    final sel = _selected == i;
    return Semantics(
      button: true,
      label: 'piece ${p.size}',
      child: GestureDetector(
        onTap: () => setState(() => _selected = sel ? null : i),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: sel ? Theme.of(context).colorScheme.primary : Colors.transparent, width: 3),
          ),
          child: CustomPaint(
            size: const Size(s * 7, s * 7),
            painter: _IsoPainter(n: 3, s: s, cubes: [for (final c in p.cells) (c, colorOf(p.color))], frame: false),
          ),
        ),
      ),
    );
  }
}

class _IsoPainter extends CustomPainter {
  final int n;
  final double s;
  final List<(V3, Color)> cubes;
  final bool frame;
  _IsoPainter({required this.n, required this.s, required this.cubes, required this.frame});

  static const _c = 0.866, _h = 0.5;

  @override
  void paint(Canvas canvas, Size size) {
    final o = Offset(size.width / 2, size.height / 2 - n * s * 0.1 + n * s * 0.5);
    Offset p(num x, num y, num z) => o + Offset((x - y) * _c * s, (x + y) * _h * s - z * s) - Offset(0, n * s * 0.5);
    if (frame) {
      final fp = Paint()
        ..color = Colors.white.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      final bottom = Path()
        ..moveTo(p(0, 0, 0).dx, p(0, 0, 0).dy)
        ..lineTo(p(n, 0, 0).dx, p(n, 0, 0).dy)
        ..lineTo(p(n, n, 0).dx, p(n, n, 0).dy)
        ..lineTo(p(0, n, 0).dx, p(0, n, 0).dy)
        ..close();
      canvas.drawPath(bottom, fp);
      for (final c in [[0, 0], [n, 0], [0, n]]) {
        canvas.drawLine(p(c[0], c[1], 0), p(c[0], c[1], n), fp);
      }
    }
    final sorted = [...cubes]..sort((a, b) {
        final da = a.$1[0] + a.$1[1], db = b.$1[0] + b.$1[1];
        return da != db ? da - db : a.$1[2] - b.$1[2];
      });
    for (final (v, col) in sorted) {
      final x = v[0], y = v[1], z = v[2];
      Path face(List<Offset> pts) => Path()..addPolygon(pts, true);
      canvas.drawPath(face([p(x, y, z + 1), p(x + 1, y, z + 1), p(x + 1, y + 1, z + 1), p(x, y + 1, z + 1)]),
          Paint()..color = Color.lerp(col, Colors.white, 0.25)!);
      canvas.drawPath(face([p(x + 1, y, z), p(x + 1, y + 1, z), p(x + 1, y + 1, z + 1), p(x + 1, y, z + 1)]),
          Paint()..color = col);
      canvas.drawPath(face([p(x, y + 1, z), p(x + 1, y + 1, z), p(x + 1, y + 1, z + 1), p(x, y + 1, z + 1)]),
          Paint()..color = Color.lerp(col, Colors.black, 0.25)!);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
