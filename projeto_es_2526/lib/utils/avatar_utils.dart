import 'package:flutter/material.dart';

class AvatarUtils {
  static const int count = 20;

  static String assetForIndex(int index) =>
      'assets/avatars/avatar_${index.toString().padLeft(2, '0')}.png';

  // Used as a fallback when all avatar slots in a room are taken (>20 members).
  static String assetForNickname(String nickname) {
    final index = nickname.codeUnits.fold(0, (acc, c) => acc + c) % count;
    return assetForIndex(index);
  }

  static Widget buildAvatarFromAsset(String assetPath, double size) {
    return ClipOval(
      child: Image.asset(assetPath, width: size, height: size, fit: BoxFit.cover),
    );
  }

  // Convenience fallback when no stored avatarUrl is available.
  static Widget buildAvatar(String nickname, double size) =>
      buildAvatarFromAsset(assetForNickname(nickname), size);
}
