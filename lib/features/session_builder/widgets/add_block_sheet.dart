import 'package:flutter/material.dart';

import '../../../models/session_block_type.dart';

Future<SessionBlockType?> showAddBlockSheet(BuildContext context) {
  return showModalBottomSheet<SessionBlockType>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final type in SessionBlockType.values)
              ListTile(
                title: Text(type.displayLabel),
                subtitle: Text(type.defaultTitle),
                onTap: () => Navigator.pop(context, type),
              ),
          ],
        ),
      );
    },
  );
}
