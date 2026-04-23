class AnonymousIdentity {
  final String anonymousId;
  final String nickname;
  final String avatarUrl;

  AnonymousIdentity({
    required this.anonymousId,
    required this.nickname,
    required this.avatarUrl,
  });

  factory AnonymousIdentity.fromMap(Map<String, dynamic> map) {
    return AnonymousIdentity(
      anonymousId: map['anonymousId'] ?? '',
      nickname: map['nickname'] ?? 'Anonymous',
      avatarUrl: map['avatarUrl'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'anonymousId': anonymousId,
      'nickname': nickname,
      'avatarUrl': avatarUrl,
    };
  }
}
