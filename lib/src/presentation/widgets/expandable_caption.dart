import 'package:flutter/material.dart';

class ExpandableCaption extends StatefulWidget {
  final String description;

  const ExpandableCaption({
    super.key,
    required this.description,
  });

  @override
  State<ExpandableCaption> createState() => _ExpandableCaptionState();
}

class _ExpandableCaptionState extends State<ExpandableCaption> {
  bool _isFullyExpanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.description.isEmpty) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _isFullyExpanded = !_isFullyExpanded;
        });
      },
      child: Text(
        widget.description,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          height: 1.3,
          shadows: [
            Shadow(
              blurRadius: 8.0,
              color: Colors.black87,
              offset: Offset(1, 1),
            ),
          ],
        ),
        maxLines: _isFullyExpanded ? null : 2,
        overflow: _isFullyExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
      ),
    );
  }
}
