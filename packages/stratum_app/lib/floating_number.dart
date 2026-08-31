/// A number that flew off a cycle, for the scene to animate and forget.
class FloatingNumber {
  FloatingNumber({
    required this.id,
    required this.text,
    required this.color,
    required this.left,
    required this.top,
    required this.size,
  });

  final int id;
  final String text;
  final int color;
  final double left;
  final double top;
  final double size;
}
