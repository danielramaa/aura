import 'package:flutter/material.dart';

class AvatarUtils {
  static const int count = 20;

  static String assetForIndex(int index) =>
      'assets/avatars/avatar_${index.toString().padLeft(2, '0')}.png';

  static String assetForNickname(String nickname) {
    final index = nickname.codeUnits.fold(0, (acc, c) => acc + c) % count;
    return assetForIndex(index);
  }

  static Widget buildAvatarFromAsset(String assetPath, double size) {
    final radius = size / 2;
    return ClipOval(
      child: Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, _) {
          debugPrint('AvatarUtils: failed to load asset "$assetPath": $error');
          return CircleAvatar(
            radius: radius,
            backgroundColor: const Color(0xFFDCE9F7),
            child: Icon(
              Icons.person,
              size: radius,
              color: const Color(0xFF185FA5),
            ),
          );
        },
      ),
    );
  }

  static Widget buildAvatar(String nickname, double size) =>
      buildAvatarFromAsset(assetForNickname(nickname), size);
}
