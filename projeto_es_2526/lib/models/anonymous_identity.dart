import '../utils/avatar_utils.dart';

class AnonymousIdentity {
  final String anonymousId;
  final String nickname;
  final int avatarIndex;

  String get avatarAssetPath => AvatarUtils.assetForIndex(avatarIndex);

  AnonymousIdentity({
    required this.anonymousId,
    required this.nickname,
    required this.avatarIndex,
  });

  factory AnonymousIdentity.fromMap(Map<String, dynamic> map) {
    return AnonymousIdentity(
      anonymousId: map['anonymousId'] as String? ?? '',
      nickname: map['nickname'] as String? ?? 'Anonymous',
      avatarIndex: map['avatarIndex'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'anonymousId': anonymousId,
      'nickname': nickname,
      'avatarIndex': avatarIndex,
    };
  }
}
