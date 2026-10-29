import 'package:flutter/material.dart';

import '../domain/like.dart';

/// A small icon for each like.
IconData iconOfLike(Like like) => switch (like) {
  Like.sun => Icons.wb_sunny_outlined,
  Like.heights => Icons.terrain_outlined,
  Like.toys => Icons.sports_baseball_outlined,
  Like.quiet => Icons.nightlight_outlined,
  Like.company => Icons.people_outline,
  Like.food => Icons.restaurant_outlined,
};
