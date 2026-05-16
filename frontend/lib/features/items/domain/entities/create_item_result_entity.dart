class CreateItemResultEntity {
  const CreateItemResultEntity({
    required this.success,
    required this.message,
    this.itemId,
  });

  final bool success;
  final String message;
  final int? itemId;
}
