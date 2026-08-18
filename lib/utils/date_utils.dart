DateTime? tryParseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is! String) return null;
  try {
    return DateTime.parse(value);
  } catch (_) {
    return null;
  }
}

String formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
