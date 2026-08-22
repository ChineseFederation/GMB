import 'package:flutter/material.dart';
import 'package:citizenapp/ui/app_layout.dart';

class AdminsChangeConfirmPage extends StatelessWidget {
  const AdminsChangeConfirmPage({super.key, required this.txHash});

  final String txHash;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('管理员更换')),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(AppLayout.scaled(context, 24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline,
                  size: AppLayout.scaled(context, 56), color: Colors.green),
              SizedBox(height: AppLayout.scaled(context, 12)),
              const Text('管理员更换提案已提交'),
              SizedBox(height: AppLayout.scaled(context, 8)),
              SelectableText(txHash, textAlign: TextAlign.center),
              SizedBox(height: AppLayout.scaled(context, 16)),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('完成'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
