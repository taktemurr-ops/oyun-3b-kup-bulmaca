/// 3B Küp Bulmaca: parçaları döndürüp küpün içine eksiksiz yerleştir.
/// Blok Oyunları merkez uygulamasının oyunu.
library;

import 'package:flutter/material.dart';
import 'package:studio_core/app/game_api.dart';

import 'src/cube_rules.dart';
import 'src/cube_view.dart';

export 'src/cube_engine.dart';
export 'src/cube_rules.dart';

final kupBulmacaConfig = GameConfig(
  gameId: kupBulmacaId,
  title: const ['Küp Ustası', 'Cube Master 3D', 'Würfelmeister', 'Maestro del Cubo', 'Maître du Cube'],
  tagline: const [
    'Parçaları döndür, küpü tamamla!',
    'Turn the pieces, complete the cube!',
    'Drehe die Teile, vollende den Würfel!',
    '¡Gira las piezas y completa el cubo!',
    'Tournez les pièces, complétez le cube !',
  ],
  seedColor: const Color(0xFF0288D1),
  icon: Icons.view_in_ar_rounded,
  rules: CubeRules(),
  buildPlay: (ctx) => CubeView(ctx: ctx),
  tutorial: const [
    TutorialStep(Icons.view_in_ar, [
      'Küp katlara ayrılmış görünür: soldaki en alt kat. Bir parça seç, X/Y/Z ile döndür.',
      'The cube is shown as layers, bottom one on the left. Pick a piece, turn it with X/Y/Z.',
      'Der Würfel wird in Ebenen gezeigt. Wähle ein Teil und drehe es mit X/Y/Z.',
      'El cubo se muestra por capas. Elige una pieza y gírala con X/Y/Z.',
      'Le cube est montré par couches. Choisissez une pièce, tournez-la avec X/Y/Z.',
    ]),
    TutorialStep(Icons.touch_app, [
      'Bir kat karesine dokun: parça o kareyi kaplayacak şekilde yerleşir. Dolu kareye dokunursan geri alırsın.',
      'Tap a layer cell to place the piece over it. Tap a filled cell to take it back.',
      'Tippe ein Feld an, um das Teil dort zu setzen. Volles Feld antippen nimmt es zurück.',
      'Toca una casilla para colocar la pieza. Toca una llena para quitarla.',
      'Touchez une case pour poser la pièce. Touchez une case pleine pour la retirer.',
    ]),
  ],
);
