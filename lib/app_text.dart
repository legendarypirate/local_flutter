import 'package:flutter/material.dart';

/// App text styles without [google_fonts] — avoids AssetManifest.json errors at runtime.
TextStyle appText({
  double? fontSize,
  FontWeight? fontWeight,
  Color? color,
  double? height,
  FontStyle? fontStyle,
  TextDecoration? decoration,
}) =>
    TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      fontStyle: fontStyle,
      decoration: decoration,
    );
