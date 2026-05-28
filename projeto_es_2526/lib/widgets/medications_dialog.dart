import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/medication.dart';
import '../models/user_role.dart';
import '../services/medication_service.dart';

class MedicationsDialog extends StatefulWidget {
  final String groupId;
  final UserRole userRole;

  const MedicationsDialog({
    super.key,
    required this.groupId,
    required this.userRole,
  });

  @override
  State<MedicationsDialog> createState() => _MedicationsDialogState();
}

class _MedicationsDialogState extends State<MedicationsDialog> {
  final MedicationService _medicationService = MedicationService();

  void _showSubmitDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _SubmitMedicationForm(groupId: widget.groupId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Medicações',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            SizedBox(
              height: 300,
              child: StreamBuilder<List<Medication>>(
                stream: _medicationService.streamApprovedMedications(
                  widget.groupId,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final meds = snapshot.data ?? [];
                  if (meds.isEmpty) {
                    return const Center(
                      child: Text(
                        'Ainda não existem medicamentos aprovados.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: meds.length,
                    itemBuilder: (context, index) {
                      final med = meds[index];
                      return ListTile(
                        leading: const Icon(
                          Icons.medical_services_outlined,
                          color: Color(0xFF185FA5),
                        ),
                        title: Text(
                          med.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(med.description),
                      );
                    },
                  );
                },
              ),
            ),
            if (widget.userRole == UserRole.medic) ...[
              const Divider(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _showSubmitDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar medicação'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF185FA5),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SubmitMedicationForm extends StatefulWidget {
  final String groupId;
  const _SubmitMedicationForm({required this.groupId});

  @override
  State<_SubmitMedicationForm> createState() => _SubmitMedicationFormState();
}

class _SubmitMedicationFormState extends State<_SubmitMedicationForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  bool _isSubmitting = false;
  final MedicationService _medicationService = MedicationService();

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Adicionar medicação'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nome da medicação',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'O nome é obrigatório' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descController,
              keyboardType: TextInputType.multiline,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Descrição / Uso',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'A descrição é obrigatória'
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting
              ? null
              : () async {
                  if (!_formKey.currentState!.validate()) return;
                  setState(() => _isSubmitting = true);
                  final err = await _medicationService.submitMedication(
                    groupId: widget.groupId,
                    name: _nameController.text.trim(),
                    description: _descController.text.trim(),
                    userId: FirebaseAuth.instance.currentUser?.uid ?? '',
                  );
                  setState(() => _isSubmitting = false);
                  if (context.mounted) {
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(context);
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(err ?? 'Medicação adicionada com sucesso!'),
                      ),
                    );
                  }
                },
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Submeter'),
        ),
      ],
    );
  }
}
