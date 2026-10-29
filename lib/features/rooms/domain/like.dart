/// What a cat enjoys. Each cat has two of these.
enum Like {
  sun('Sun'),
  heights('Heights'),
  toys('Toys'),
  quiet('Quiet'),
  company('Company'),
  food('Food');

  const Like(this.label);

  /// The word shown to the player.
  final String label;

  /// The like called [name], or null.
  static Like? byNameOrNull(String? name) {
    for (final like in values) {
      if (like.name == name) return like;
    }
    return null;
  }
}
