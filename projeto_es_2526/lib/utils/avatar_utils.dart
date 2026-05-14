import 'package:flutter/material.dart';

class AvatarUtils {
  static const int _count = 20;

  static String assetForNickname(String nickname) {
    final index = nickname.codeUnits.fold(0, (sum, c) => sum + c) % _count;
    return 'assets/avatars/avatar_${index.toString().padLeft(2, '0')}.png';
  }

  static Widget buildAvatar(String nickname, double size) {
    return ClipOval(
      child: Image.asset(
        assetForNickname(nickname),
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}
