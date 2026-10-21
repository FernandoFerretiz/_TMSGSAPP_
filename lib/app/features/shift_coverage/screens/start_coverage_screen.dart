import '../../../core/design/sx_design.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/config/app_config.dart';
import '../controllers/shift_coverage_controller.dart';

class StartCoverageScreen extends StatefulWidget {
  const StartCoverageScreen({super.key});

  @override
  State<StartCoverageScreen> createState() => _StartCoverageScreenState();
}

class _StartCoverageScreenState extends State<StartCoverageScreen> {
  final _reasonCtrl = TextEditingController();

  late final ShiftCoverageController _sc;

  @override
  void initState() {
    super.initState();
    _sc = Get.find<ShiftCoverageController>();
    _sc.resetForm();
    _sc.loadUsers();
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickEndsAt() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _sc.endsAt.value ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_sc.endsAt.value ?? now),
    );
    if (time == null) return;

    _sc.endsAt.value = DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _submit() async {
    final success = await _sc.startCoverage(reason: _reasonCtrl.text.trim());

    if (success && mounted) {
      Get.back(result: true);
      Get.snackbar(
        'Cobertura iniciada',
        'Se registró correctamente.',
        backgroundColor: AppColors.royalBlue,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FC),
      appBar: SxAppBar(title: const Text(
          'Cubrir turno',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        )),
      body: Obx(() {
        if (_sc.isLoadingUsers.value) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.royalBlue),
          );
        }

        if (_sc.users.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                _sc.formErrorMessage.value.isNotEmpty
                    ? _sc.formErrorMessage.value
                    : 'No hay usuarios disponibles para cubrir.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMedium),
              ),
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Label('Usuario(s) a cubrir'),
              const SizedBox(height: 8),
              _UsersList(controller: _sc),
              const SizedBox(height: 22),
              const _Label('Comentarios (opcional)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _reasonCtrl,
                maxLines: 2,
                style: const TextStyle(color: AppColors.textDark, fontSize: 14),
                decoration: _fieldDecoration('Ej. cubriendo por vacaciones...'),
              ),
              const SizedBox(height: 22),
              const _Label('Termina (opcional)'),
              const SizedBox(height: 8),
              _EndsAtPicker(controller: _sc, onTap: _pickEndsAt),
              const Text(
                'Si no seleccionas fecha, la cobertura queda en curso hasta que la finalices.',
                style: TextStyle(color: AppColors.textLight, fontSize: 12),
              ),
              const SizedBox(height: 26),
              Obx(() {
                final err = _sc.formErrorMessage.value;
                if (err.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _ErrorRow(err),
                );
              }),
              Obx(() {
                final canSubmit = _sc.isFormValid;
                return _SubmitButton(
                  isLoading: _sc.isSubmitting.value,
                  enabled: canSubmit && !_sc.isSubmitting.value,
                  onPressed: _submit,
                );
              }),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Get.back(),
                  child: const Text('Cancelar', style: TextStyle(color: AppColors.textMedium)),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 13),
        filled: true,
        fillColor: AppColors.fieldFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.fieldBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.fieldBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.royalBlue, width: 2),
        ),
      );
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.navyBlue,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _UsersList extends StatelessWidget {
  final ShiftCoverageController controller;
  const _UsersList({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Obx(() => Column(
            children: controller.users.map((user) {
              final selected = controller.selectedUserIds.contains(user.id);
              return InkWell(
                onTap: () => controller.toggleUser(user.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Icon(
                        selected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                        color: selected ? AppColors.royalBlue : AppColors.textLight,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          user.name,
                          style: const TextStyle(
                            color: AppColors.textDark,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          )),
    );
  }
}

class _EndsAtPicker extends StatelessWidget {
  final ShiftCoverageController controller;
  final VoidCallback onTap;
  const _EndsAtPicker({required this.controller, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final value = controller.endsAt.value;
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.fieldFill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.fieldBorder),
          ),
          child: Row(
            children: [
              const Icon(Icons.event_rounded, color: AppColors.royalBlue, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  value != null ? _formatDateTime(value) : 'Sin fecha de fin (en curso)',
                  style: TextStyle(
                    color: value != null ? AppColors.textDark : AppColors.textLight,
                    fontSize: 13.5,
                  ),
                ),
              ),
              if (value != null)
                GestureDetector(
                  onTap: () => controller.endsAt.value = null,
                  child: const Icon(Icons.close_rounded, color: AppColors.textLight, size: 18),
                ),
            ],
          ),
        ),
      );
    });
  }

  String _formatDateTime(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final hour = d.hour.toString().padLeft(2, '0');
    final minute = d.minute.toString().padLeft(2, '0');
    return '$day/$month/${d.year} $hour:$minute';
  }
}

class _SubmitButton extends StatelessWidget {
  final bool isLoading;
  final bool enabled;
  final VoidCallback onPressed;

  const _SubmitButton({
    required this.isLoading,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: enabled
              ? AppColors.buttonGradient
              : const LinearGradient(colors: [Color(0xFF90A4AE), Color(0xFFB0BEC5)]),
          borderRadius: BorderRadius.circular(14),
        ),
        child: ElevatedButton(
          onPressed: enabled ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text(
                  'Iniciar cobertura',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
        ),
      ),
    );
  }
}

class _ErrorRow extends StatelessWidget {
  final String message;
  const _ErrorRow(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEF9A9A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.errorRed, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(color: AppColors.errorRed, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
