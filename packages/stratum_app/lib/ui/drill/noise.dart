/// A tiny deterministic sequence, so texture is a function of depth.
class Noise {
  Noise(this._state);

  int _state;

  double next() {
    _state = (_state * 1103515245 + 12345) & 0x7FFFFFFF;
    return _state / 0x7FFFFFFF;
  }
}

/// Where cracks sit on a layer and how they lie.
///
/// Everything is a fraction: position of the layer, length of its width. The
/// prototype stated these in pixels against a 96px layer, which stopped working
/// the moment layers got thinner -- a rotated 70px line simply left the tile.
