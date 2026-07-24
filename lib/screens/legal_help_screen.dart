import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../di/di.dart';
import '../repositories/legal_help_repository.dart';
import '../supabase/session_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';

/// Confidential report form for victims of cyber-bullying and harassment.
///
/// Submissions go to the university authority (super admin) for review. Open to
/// guests and students alike; a signed-in reporter may still submit anonymously.
class LegalHelpScreen extends StatefulWidget {
  const LegalHelpScreen({super.key});

  @override
  State<LegalHelpScreen> createState() => _LegalHelpScreenState();
}

class _LegalHelpScreenState extends State<LegalHelpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _platform = TextEditingController();
  final _location = TextEditingController();
  final _involved = TextEditingController();
  final _evidence = TextEditingController();

  ReportCategory _category = ReportCategory.cyberbullying;
  DateTime? _incidentDate;
  bool _anonymous = false;
  bool _submitting = false;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    final profile = getIt<SessionController>().profile;
    if (profile != null) {
      _name.text = profile.fullName;
      _email.text = profile.email;
    }
  }

  @override
  void dispose() {
    for (final c in [
      _description,
      _name,
      _email,
      _phone,
      _platform,
      _location,
      _involved,
      _evidence,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _incidentDate ?? DateTime.now(),
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) setState(() => _incidentDate = picked);
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      await getIt<LegalHelpRepository>().submitReport(
        LegalHelpDraft(
          category: _category,
          description: _description.text.trim(),
          isAnonymous: _anonymous,
          reporterName: _anonymous ? null : _name.text,
          contactEmail: _email.text,
          contactPhone: _phone.text,
          incidentPlatform: _platform.text,
          incidentDate: _incidentDate,
          location: _location.text,
          involvedParties: _involved.text,
          evidenceUrl: _evidence.text,
        ),
      );
      if (!mounted) return;
      setState(() => _submitted = true);
    } catch (_) {
      if (mounted) {
        showToast(context, 'Could not submit right now. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Legal Help',
          style: TextStyle(color: context.colors.textPrimary),
        ),
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: context.colors.textPrimary),
      ),
      body: ResponsivePage(
        child: _submitted
            ? _SuccessView(onClose: () => Navigator.of(context).maybePop())
            : _form(),
      ),
    );
  }

  Widget _form() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const _IntroBanner(),
          const SizedBox(height: AppSpacing.lg),
          _label('What happened?'),
          const SizedBox(height: AppSpacing.sm),
          _CategoryPicker(
            selected: _category,
            onSelect: (c) => setState(() => _category = c),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            controller: _description,
            minLines: 5,
            maxLines: 12,
            maxLength: 5000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Describe the incident *',
              hintText:
                  'Tell us what happened, when it started, and how it has affected you. '
                  'Include usernames, links or message content if you can.',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              final text = v?.trim() ?? '';
              if (text.length < 10) {
                return 'Please describe the incident (at least 10 characters).';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _FieldTile(
                  label: 'When did it happen?',
                  value: _incidentDate == null
                      ? 'Optional'
                      : DateFormat('MMM d, yyyy').format(_incidentDate!),
                  icon: Icons.event_rounded,
                  onTap: _pickDate,
                  onClear: _incidentDate == null
                      ? null
                      : () => setState(() => _incidentDate = null),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _platform,
            decoration: const InputDecoration(
              labelText: 'Where did it happen? (optional)',
              hintText: 'e.g. Facebook, WhatsApp, campus, email',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _involved,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Who was involved? (optional)',
              hintText: 'Names, usernames or a description — if known',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _evidence,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Evidence link (optional)',
              hintText: 'Link to a screenshot / drive folder',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _label('Your contact details'),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'So the authority can follow up with you privately.',
            style: TextStyle(color: context.colors.textMuted, fontSize: 12.5),
          ),
          const SizedBox(height: AppSpacing.md),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _anonymous,
            onChanged: (v) => setState(() => _anonymous = v),
            title: Text(
              'Submit anonymously',
              style: TextStyle(
                color: context.colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              'Your name is hidden. Add contact details below only if you want a reply.',
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (!_anonymous) ...[
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Your name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Contact email (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Contact phone (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
            label: _submitting ? 'Submitting…' : 'Submit report',
            icon: Icons.shield_rounded,
            onPressed: _submitting ? null : _submit,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Icon(
                Icons.lock_rounded,
                size: 14,
                color: context.colors.textMuted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Your report is confidential and visible only to the university authority.',
                  style: TextStyle(
                    color: context.colors.textMuted,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: TextStyle(
      color: context.colors.textPrimary,
      fontWeight: FontWeight.w700,
      fontSize: 16,
    ),
  );
}

class _IntroBanner extends StatelessWidget {
  const _IntroBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            context.colors.danger.withValues(alpha: 0.18),
            context.colors.primary.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(
          color: context.colors.danger.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.colors.danger.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Icon(Icons.gavel_rounded, color: context.colors.danger),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You are not alone',
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Report cyber-bullying or harassment and request legal help. '
                  'Share as much as you feel comfortable with.',
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryPicker extends StatelessWidget {
  final ReportCategory selected;
  final ValueChanged<ReportCategory> onSelect;
  const _CategoryPicker({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: ReportCategory.values.map((c) {
        final active = c == selected;
        return Pressable(
          onTap: () => onSelect(c),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: active
                  ? context.colors.primary
                  : context.colors.surfaceAlt,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: active ? context.colors.primary : context.colors.border,
              ),
            ),
            child: Text(
              c.label,
              style: TextStyle(
                color: active ? Colors.white : context.colors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _FieldTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  const _FieldTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: onClear == null
              ? null
              : IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
          border: const OutlineInputBorder(),
        ),
        child: Text(
          value,
          style: TextStyle(color: context.colors.textPrimary, fontSize: 13),
        ),
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  final VoidCallback onClose;
  const _SuccessView({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                color: context.colors.success.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.verified_rounded,
                color: context.colors.success,
                size: 44,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Report received',
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Thank you for speaking up. The university authority will review your '
              'report confidentially and reach out if you left contact details.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Done',
              icon: Icons.check_rounded,
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}
