import 'package:flutter/material.dart';
import 'package:flutter_app/util/own_theme_fields.dart';

class CustomBanner extends StatelessWidget {
  final CustomBannerKind kind;
  final String text;

  const CustomBanner({super.key, required this.kind, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: kind.getBackgroundColor(context),
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: kind.getColor(context),
            ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

enum CustomBannerKind { warning, error }

extension CustomBannerKindExtensions on CustomBannerKind {
  Color getBackgroundColor(BuildContext context) {
    switch (this) {
      case CustomBannerKind.warning:
        return Theme.of(context).own().warning;
      case CustomBannerKind.error:
        return Theme.of(context).colorScheme.error;
    }
  }

  Color getColor(BuildContext context) {
    switch (this) {
      case CustomBannerKind.warning:
        return Theme.of(context).own().onWarning;
      case CustomBannerKind.error:
        return Theme.of(context).colorScheme.onError;
    }
  }
}
