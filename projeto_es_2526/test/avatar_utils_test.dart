import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_es_2526/utils/avatar_utils.dart';

void main() {
  group('AvatarUtils.assetForIndex', () {
    test('returns correctly formatted path for each valid index', () {
      for (int i = 0; i < AvatarUtils.count; i++) {
        final path = AvatarUtils.assetForIndex(i);
        expect(path, startsWith('assets/avatars/avatar_'));
        expect(path, endsWith('.png'));
        expect(path, contains(i.toString().padLeft(2, '0')));
      }
    });
  });

  group('AvatarUtils.assetForNickname (hash fallback)', () {
    test('returns a valid asset path', () {
      final path = AvatarUtils.assetForNickname('CalmWolf42');
      expect(path, startsWith('assets/avatars/avatar_'));
      expect(path, endsWith('.png'));
    });

    test('index is always in range 0-19', () {
      final nicknames = [
        'CalmWolf42',
        'BraveEagle7',
        'QuietFox99',
        'WiseOwl0',
        'NimbleDeer12',
        'FierceHawk5',
        'TenderBear88',
        '',
      ];
      for (final n in nicknames) {
        final path = AvatarUtils.assetForNickname(n);
        final indexStr = path.replaceAll(RegExp(r'[^0-9]'), '');
        final index = int.parse(indexStr);
        expect(index, inInclusiveRange(0, 19), reason: 'nickname: $n -> $path');
      }
    });

    test('same nickname always produces the same asset', () {
      final a = AvatarUtils.assetForNickname('CalmWolf42');
      final b = AvatarUtils.assetForNickname('CalmWolf42');
      expect(a, equals(b));
    });

    test('different nicknames can produce different assets', () {
      final paths = {
        'CalmWolf42',
        'BraveEagle7',
        'QuietFox99',
        'WiseOwl0',
      }.map(AvatarUtils.assetForNickname).toSet();
      expect(paths.length, greaterThan(1));
    });
  });
}
