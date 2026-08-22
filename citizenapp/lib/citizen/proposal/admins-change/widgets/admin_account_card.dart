import 'package:flutter/material.dart';

import 'package:citizenapp/citizen/proposal/admins-change/models/admin_account.dart';
import 'package:citizenapp/ui/app_theme.dart';
import 'package:citizenapp/ui/app_layout.dart';

class AdminAccountCard extends StatelessWidget {
  const AdminAccountCard({super.key, required this.account});

  final AdminAccountState account;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(AppLayout.scaled(context, 14)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(account.kindLabel,
                      style: TextStyle(
                          fontSize: AppLayout.scaled(context, 16),
                          fontWeight: FontWeight.w700)),
                  SizedBox(height: AppLayout.scaled(context, 4)),
                  Text('管理员 ${account.admins.length} 人，阈值 ${account.threshold}',
                      style: const TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            ),
            Chip(label: Text(account.statusLabel)),
          ],
        ),
      ),
    );
  }
}
