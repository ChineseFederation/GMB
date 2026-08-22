import 'package:flutter/material.dart';
import 'package:citizenapp/ui/app_layout.dart';

class AdminsChangeActionBar extends StatelessWidget {
  const AdminsChangeActionBar({
    super.key,
    required this.busy,
    required this.enabled,
    required this.onSubmit,
  });

  final bool busy;
  final bool enabled;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.all(AppLayout.scaled(context, 16)),
        child: FilledButton(
          onPressed: busy || !enabled ? null : onSubmit,
          child: Text(busy ? '提交中…' : '发起管理员更换'),
        ),
      ),
    );
  }
}
