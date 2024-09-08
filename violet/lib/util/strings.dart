extension StringExtension on String {
  String titlecase() {
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }
}
