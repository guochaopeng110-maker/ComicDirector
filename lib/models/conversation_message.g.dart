// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversation_message.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ConversationMessageAdapter extends TypeAdapter<ConversationMessage> {
  @override
  final int typeId = 2;

  @override
  ConversationMessage read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ConversationMessage(
      id: fields[0] as String,
      conversationId: fields[1] as String,
      type: fields[2] as ConversationMessageType,
      content: fields[3] as String,
      isUser: fields[4] as bool,
      createdAt: fields[5] as DateTime,
      metadata: (fields[6] as Map?)?.cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, ConversationMessage obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.conversationId)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.content)
      ..writeByte(4)
      ..write(obj.isUser)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.metadata);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConversationMessageAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ConversationMessageTypeAdapter
    extends TypeAdapter<ConversationMessageType> {
  @override
  final int typeId = 1;

  @override
  ConversationMessageType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ConversationMessageType.text;
      case 1:
        return ConversationMessageType.thinking;
      case 2:
        return ConversationMessageType.error;
      case 3:
        return ConversationMessageType.draft;
      case 4:
        return ConversationMessageType.screenplay;
      default:
        return ConversationMessageType.text;
    }
  }

  @override
  void write(BinaryWriter writer, ConversationMessageType obj) {
    switch (obj) {
      case ConversationMessageType.text:
        writer.writeByte(0);
        break;
      case ConversationMessageType.thinking:
        writer.writeByte(1);
        break;
      case ConversationMessageType.error:
        writer.writeByte(2);
        break;
      case ConversationMessageType.draft:
        writer.writeByte(3);
        break;
      case ConversationMessageType.screenplay:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConversationMessageTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
