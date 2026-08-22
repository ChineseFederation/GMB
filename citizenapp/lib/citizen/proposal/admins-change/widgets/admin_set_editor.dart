import 'package:flutter/material.dart';

import 'package:citizenapp/citizen/proposal/admins-change/codec/account_id_codec.dart';
import 'package:citizenapp/citizen/proposal/admins-change/models/admin_account.dart';
import 'package:citizenapp/citizen/shared/account_derivation.dart';
import 'package:citizenapp/my/util/amount_format.dart';
import 'package:citizenapp/ui/app_layout.dart';

class AdminSetEditor extends StatefulWidget {
  const AdminSetEditor({
    super.key,
    required this.admins,
    this.balances = const {},
    required this.onChanged,
  });

  final List<AdminPerson> admins;
  final Map<String, double> balances;
  final ValueChanged<List<AdminPerson>> onChanged;

  @override
  State<AdminSetEditor> createState() => _AdminSetEditorState();
}

class _AdminSetEditorState extends State<AdminSetEditor> {
  final _accountController = TextEditingController();
  final _familyNameController = TextEditingController(text: '管理');
  final _givenNameController = TextEditingController(text: '员');

  @override
  void dispose() {
    _accountController.dispose();
    _familyNameController.dispose();
    _givenNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(AppLayout.scaled(context, 14)),
        child: Column(
          children: [
            for (var i = 0; i < widget.admins.length; i++) ...[
              _buildAdminEditor(i),
              SizedBox(height: AppLayout.scaled(context, 8)),
            ],
            TextField(
              controller: _accountController,
              decoration: const InputDecoration(labelText: '管理员公钥 hex'),
            ),
            SizedBox(height: AppLayout.scaled(context, 8)),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _familyNameController,
                    decoration: const InputDecoration(labelText: '姓'),
                  ),
                ),
                SizedBox(width: AppLayout.scaled(context, 8)),
                Expanded(
                  child: TextField(
                    controller: _givenNameController,
                    decoration: const InputDecoration(labelText: '名'),
                  ),
                ),
                SizedBox(width: AppLayout.scaled(context, 8)),
                FilledButton(onPressed: _add, child: const Text('添加')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminEditor(int index) {
    final admin = widget.admins[index];
    return Container(
      padding: EdgeInsets.all(AppLayout.scaledValue(10)),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(AppLayout.scaledValue(8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${index + 1}'),
              SizedBox(width: AppLayout.scaledValue(8)),
              Expanded(child: Text(ss58FromAccountIdText(admin.account_id))),
              IconButton(
                padding: EdgeInsets.zero,
                tooltip: '移除',
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () => widget.onChanged([
                  for (var i = 0; i < widget.admins.length; i++)
                    if (i != index) widget.admins[i],
                ]),
              ),
            ],
          ),
          Text(
            '余额：${AmountFormat.formatThousands(widget.balances[AdminAccountIdCodec.requireAccountId(admin.account_id)])} 元',
          ),
          SizedBox(height: AppLayout.scaledValue(8)),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: ValueKey('${admin.account_id}-$index-family'),
                  initialValue: admin.family_name,
                  decoration: const InputDecoration(labelText: '姓'),
                  onChanged: (value) => _updateName(
                    index,
                    admin.copyWith(family_name: value),
                  ),
                ),
              ),
              SizedBox(width: AppLayout.scaledValue(8)),
              Expanded(
                child: TextFormField(
                  key: ValueKey('${admin.account_id}-$index-given'),
                  initialValue: admin.given_name,
                  decoration: const InputDecoration(labelText: '名'),
                  onChanged: (value) => _updateName(
                    index,
                    admin.copyWith(given_name: value),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _updateName(int index, AdminPerson next) {
    widget.onChanged([
      for (var i = 0; i < widget.admins.length; i++)
        if (i == index) next else widget.admins[i],
    ]);
  }

  void _add() {
    final clean = AdminAccountIdCodec.requireAccountId(_accountController.text);
    if (clean.length != 64 ||
        widget.admins.any((admin) => admin.account_id == clean)) {
      return;
    }
    widget.onChanged([
      ...widget.admins,
      AdminPerson(
        account_id: clean,
        family_name: _familyNameController.text.trim().isEmpty
            ? '管理'
            : _familyNameController.text.trim(),
        given_name: _givenNameController.text.trim().isEmpty
            ? '员'
            : _givenNameController.text.trim(),
      ),
    ]);
    _accountController.clear();
    _familyNameController.text = '管理';
    _givenNameController.text = '员';
  }
}
