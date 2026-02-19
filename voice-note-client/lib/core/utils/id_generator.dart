import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Generates a UUID v4 string.
String generateId() => _uuid.v4();
