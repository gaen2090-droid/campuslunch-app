class Account {
  final String id;
  final String password;
  final String nickname;
  final String role; // 'user' | 'admin' (사장님은 restaurants.owner_id 로 판별)
  final List<String> restaurantIds;

  const Account({
    required this.id,
    required this.password,
    required this.nickname,
    this.role = 'user',
    this.restaurantIds = const [],
  });

  Account copyWith({
    String? nickname,
    String? role,
    List<String>? restaurantIds,
  }) =>
      Account(
        id: id,
        password: password,
        nickname: nickname ?? this.nickname,
        role: role ?? this.role,
        restaurantIds: restaurantIds ?? this.restaurantIds,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'password': password,
        'nickname': nickname,
        'role': role,
        'restaurantIds': restaurantIds,
      };

  factory Account.fromMap(Map<String, dynamic> m) => Account(
        id: m['id'] as String,
        password: m['password'] as String,
        nickname: m['nickname'] as String,
        role: m['role'] as String? ?? 'user',
        restaurantIds: List<String>.from(m['restaurantIds'] as List? ?? []),
      );
}
