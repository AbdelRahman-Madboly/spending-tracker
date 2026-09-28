import 'package:flutter/material.dart';

import '../design/tokens.dart';

/// A placeholder block in surfaceAlt, shown while a section loads. Lists
/// use these rather than a spinner (spec §7.3), so the layout keeps its
/// shape and nothing jumps when the data arrives.
class Skeleton extends StatelessWidget {
  final double height;
  final double? width;

  const Skeleton({super.key, this.height = 48, this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: context.palette.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
    );
  }
}

/// [count] skeleton rows with the list row height between them.
class SkeletonRows extends StatelessWidget {
  final int count;

  const SkeletonRows({super.key, this.count = 3});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < count; i++)
          const Padding(
            padding: EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
            child: Skeleton(height: 56),
          ),
      ],
    );
  }
}
