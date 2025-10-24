import 'package:hive/hive.dart';

class VkAuthSession {
  VkAuthSession({
    required this.accessToken,
    required this.userId,
    required this.expiresIn,
    required this.createdAt,
  });

  final String accessToken;
  final String userId;
  final int expiresIn;
  final DateTime createdAt;

  bool get isExpired {
    if (expiresIn <= 0) {
      return false;
    }
    final expiresAt = createdAt.add(Duration(seconds: expiresIn));
    return DateTime.now().isAfter(expiresAt);
  }

  VkAuthSession copyWith({
    String? accessToken,
    String? userId,
    int? expiresIn,
    DateTime? createdAt,
  }) {
    return VkAuthSession(
      accessToken: accessToken ?? this.accessToken,
      userId: userId ?? this.userId,
      expiresIn: expiresIn ?? this.expiresIn,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class VkAuthSessionAdapter extends TypeAdapter<VkAuthSession> {
  @override
  final int typeId = 0;

  @override
  VkAuthSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return VkAuthSession(
      accessToken: fields[0] as String,
      userId: fields[1] as String,
      expiresIn: fields[2] as int,
      createdAt: fields[3] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, VkAuthSession obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.accessToken)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.expiresIn)
      ..writeByte(3)
      ..write(obj.createdAt);
  }
}
