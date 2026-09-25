// Developed by Rajesh Biswas (rajeshbiswas.dev)
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../di/di.dart';
import '../navigation/app_router.dart';
import '../supabase/auth_service.dart';
import '../supabase/reference_data_service.dart';
import '../supabase/session_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/horizon_logo.dart';
import '../widgets/status_dialog.dart';


/// Registration collects the identity information required by the database
/// (poll Q20): name, roll, Student ID, university email (@bu.ac.bd), phone,
/// session (2025-26 format), faculty and department. Faculty/department come
/// from live reference data; the batch is resolved from department + session
/// before sign-up so the profile lands in the right batch.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _rollController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _sessionController = TextEditingController();
  final _passwordController = TextEditingController();

  final _auth = getIt<AuthService>();
  final _refData = getIt<ReferenceDataService>();

  bool _obscurePassword = true;
  bool _submitting = false;

  /// Newly admitted students don't receive their @bu.ac.bd email for ~6 months.
  /// When they tick "I don't have a University Mail yet", they register with a
  /// personal email and land as a provisional (pending_verification) account
  /// that a super admin or their batch CR approves.
  bool _noUniversityEmail = false;


  // Academic System (poll Q2/Q3): 'semester' (1st–8th) or 'yearly' (1st–4th).
  // The chosen system and current term become the source of truth for the
  // student's profile and drive how the app labels their terms.
  String _academicSystem = 'semester';
  int? _currentTerm;

  /// Number of terms offered by the selected academic system.
  int get _termCount => _academicSystem == 'yearly' ? 4 : 8;

  /// Singular unit label for the selected system.
  String get _termUnit => _academicSystem == 'yearly' ? 'Year' : 'Semester';

  /// Ordinal like '1st', '2nd', '3rd', '4th' … for the dropdown labels.
  String _ordinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    return switch (n % 10) {
      1 => '${n}st',
      2 => '${n}nd',
      3 => '${n}rd',
      _ => '${n}th',
    };
  }

  // Reference data for the dropdowns.

  List<FacultyOption> _faculties = [];
  List<DepartmentOption> _departments = [];
  String? _facultyId;
  String? _departmentId;
  bool _loadingRefs = true;
  bool _fetchingRefs = false;
  String? _refError;

  @override
  void initState() {
    super.initState();
    _loadReferenceData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rollController.dispose();
    _studentIdController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _sessionController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadReferenceData() async {
    if (_fetchingRefs) return;
    _fetchingRefs = true;
    setState(() {
      _loadingRefs = true;
      _refError = null;
    });
    try {
      final faculties = await _refData.faculties();
      final departments = await _refData.departments();
      if (!mounted) return;
      if (faculties.isEmpty || departments.isEmpty) {
        // The form is unusable without the dropdowns; treat as a load failure.
        setState(() {
          _loadingRefs = false;
          _refError = 'empty';
        });
        return;
      }
      setState(() {
        _faculties = faculties;
        _departments = departments;
        _loadingRefs = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingRefs = false;
        _refError = e.toString();
      });
    } finally {
      _fetchingRefs = false;
    }
  }

  List<DepartmentOption> get _departmentsForFaculty => _facultyId == null
      ? const []
      : _departments.where((d) => d.facultyId == _facultyId).toList();

  Future<void> _register() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_facultyId == null || _departmentId == null) {
      showErrorDialog(
        context,
        title: 'Missing Details',
        message: 'Please select your faculty and department to continue.',
        primaryLabel: 'OK',
      );
      return;
    }
    if (_currentTerm == null) {
      showErrorDialog(
        context,
        title: 'Missing Details',
        message: 'Please choose your current ${_termUnit.toLowerCase()} to '
            'continue.',
        primaryLabel: 'OK',
      );
      return;
    }

    setState(() => _submitting = true);
    final session = _sessionController.text.trim();
    final departmentId = _departmentId!;

    try {
      // Resolve the batch for this department + session so the profile lands in
      // the correct batch. A missing batch is not fatal — the account is still
      // created and an admin/CR can assign the batch later.
      final batchId = await _refData.resolveBatchId(
        departmentId: departmentId,
        session: session,
      );

      final response = await _auth.signUp(
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim().toLowerCase(),
        password: _passwordController.text,
        studentId: _studentIdController.text.trim(),
        roll: _rollController.text.trim(),
        phone: _phoneController.text.trim(),
        facultyId: _facultyId,
        departmentId: departmentId,
        batchId: batchId,
        academicSystem: _academicSystem,
        currentTerm: _currentTerm,
        isProvisional: _noUniversityEmail,
      );
      if (!mounted) return;

      // With email confirmation enabled there is no active session yet.
      if (response.session == null) {
        await showSuccessDialog(
          context,
          title: 'Account Created!',
          message: 'Almost there — confirm your email from your inbox, '
              'then sign in. Your account will be reviewed by your class '
              'representative before batch content is unlocked.',
          primaryLabel: 'Go to Sign In',
        );
        if (!mounted) return;
        context.go(AppRoutes.login);
      } else {
        await getIt<SessionController>().refresh();
        if (!mounted) return;
        await showSuccessDialog(
          context,
          title: 'Welcome to BU Horizon!',
          message: 'Your account was created. Your class representative '
              'will review it shortly — once approved, your batch content '
              'will be unlocked.',
          primaryLabel: 'Continue',
        );
        if (!mounted) return;
        context.go(AppRoutes.home);
      }

    } on AuthFailure catch (e) {
      if (mounted) {
        showErrorDialog(
          context,
          title: 'Registration Failed',
          message: e.message,
        );
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog(
          context,
          title: 'Something Went Wrong',
          message: 'We couldn\'t create your account right now. Please check '
              'your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loadingRefs) {
      return const Center(child: CircularProgressIndicator());
    }
    // Reference data is required for the Faculty/Department dropdowns — show a
    // clear retry state instead of a form that cannot be completed.
    if (_refError != null) {
      final isNetwork =
          _refError!.toLowerCase().contains('socket') ||
          _refError!.toLowerCase().contains('timeout') ||
          _refError!.toLowerCase().contains('connection') ||
          _refError!.toLowerCase().contains('network') ||
          _refError!.toLowerCase().contains('clientexception');
      final isEmpty = _refError == 'empty';

      final icon = isEmpty
          ? Icons.storage_rounded
          : (isNetwork ? Icons.wifi_off_rounded : Icons.error_outline_rounded);
      final title = isEmpty
          ? 'No Faculties Available'
          : (isNetwork ? 'Connection Problem' : 'Could Not Load Departments');
      final message = isEmpty
          ? 'University reference data has not been set up yet. Please check back later.'
          : (isNetwork
                ? 'Could not connect to the campus server. Check your internet connection and try again.'
                : 'An unexpected error occurred while loading university departments. Please try again or contact support.');

      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: context.colors.danger.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: context.colors.danger, size: 34),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Try Again',
                icon: Icons.refresh_rounded,
                onPressed: _fetchingRefs ? null : _loadReferenceData,
              ),
            ],
          ),
        ),
      );
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: HorizonLogo(size: 80)),
                const SizedBox(height: 24),
                Text(
                  'Create Account',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Join the BU Horizon campus network.',
                  style: TextStyle(
                    fontSize: 14,
                    color: context.colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                ..._buildFields(context),
                const SizedBox(height: 28),
                PrimaryButton(
                  label: _submitting ? 'Creating account...' : 'Sign Up',
                  icon: Icons.person_add_alt_1_rounded,
                  onPressed: _submitting ? null : _register,
                ),
                const SizedBox(height: 18),
                Center(
                  child: TextButton(
                    onPressed: () => context.pop(),
                    child: RichText(
                      text: TextSpan(
                        text: 'Already have an account? ',
                        style: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 14,
                        ),
                        children: [
                          TextSpan(
                            text: 'Sign In',
                            style: TextStyle(
                              color: context.colors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'Developer: Rajesh Biswas (rajeshbiswas.dev)',
                    style: TextStyle(
                      color: context.colors.textMuted,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _dec(BuildContext context, String hint, {Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: context.colors.textMuted),
      filled: true,
      fillColor: context.colors.surfaceAlt,
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: context.colors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: context.colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: context.colors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: context.colors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: context.colors.danger, width: 1.5),
      ),
    );
  }

  Widget _label(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 16),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: context.colors.textSecondary,
      ),
    ),
  );

  /// The "I don't have a University Mail yet" opt-in. Switches the email field
  /// to accept a personal address and marks the sign-up as provisional.
  Widget _buildNoUniversityEmailToggle(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () =>
                setState(() => _noUniversityEmail = !_noUniversityEmail),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: _noUniversityEmail,
                      onChanged: (v) =>
                          setState(() => _noUniversityEmail = v ?? false),
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "I don't have a University Mail yet",
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_noUniversityEmail)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 34, right: 4),
              child: Text(
                'New students can register with a personal email. Your account '
                'will be reviewed by an admin or your class representative, and '
                'you can add your @bu.ac.bd email later to become fully '
                'verified.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: context.colors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildFields(BuildContext context) {

    final textStyle = TextStyle(color: context.colors.textPrimary);
    return [
      _label(context, 'Full Name'),
      TextFormField(
        controller: _nameController,
        textInputAction: TextInputAction.next,
        style: textStyle,
        decoration: _dec(context, 'e.g., Rajesh Biswas'),
        validator: (v) =>
            (v == null || v.trim().isEmpty) ? 'Enter your full name' : null,
      ),
      _label(context, 'Student ID'),
      TextFormField(
        controller: _studentIdController,
        textInputAction: TextInputAction.next,
        style: textStyle,
        decoration: _dec(context, 'From your Student ID card'),
        validator: (v) =>
            (v == null || v.trim().isEmpty) ? 'Enter your Student ID' : null,
      ),
      _label(context, 'Class Roll'),
      TextFormField(
        controller: _rollController,
        textInputAction: TextInputAction.next,
        style: textStyle,
        decoration: _dec(context, 'e.g., 047'),
        validator: (v) =>
            (v == null || v.trim().isEmpty) ? 'Enter your class roll' : null,
      ),
      _label(context, _noUniversityEmail ? 'Personal Email' : 'University Email'),
      TextFormField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        style: textStyle,
        decoration: _dec(
          context,
          _noUniversityEmail ? 'name@gmail.com' : 'name@bu.ac.bd',
        ),
        validator: (v) {
          final value = (v ?? '').trim().toLowerCase();
          if (_noUniversityEmail) {
            // Provisional students register with any valid personal email.
            if (value.isEmpty) return 'Enter your personal email';
            final any = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
            if (!any.hasMatch(value)) return 'Enter a valid email address';
            return null;
          }
          if (value.isEmpty) return 'Enter your university email';
          // Must be the university domain (poll Q20).
          final re = RegExp(r'^[^@\s]+@bu\.ac\.bd$');
          if (!re.hasMatch(value)) return 'Use your @bu.ac.bd university email';
          return null;
        },
      ),
      _buildNoUniversityEmailToggle(context),
      _label(context, 'Phone Number'),

      TextFormField(
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.next,
        style: textStyle,
        decoration: _dec(context, 'e.g., 01712-345678'),
        validator: (v) {
          final value = (v ?? '').trim();
          if (value.isEmpty) return 'Enter your phone number';
          if (!RegExp(r'^[0-9+\-\s()]{6,20}$').hasMatch(value)) {
            return 'Enter a valid phone number';
          }
          return null;
        },
      ),
      _label(context, 'Session'),
      TextFormField(
        controller: _sessionController,
        textInputAction: TextInputAction.next,
        keyboardType: TextInputType.datetime,
        style: textStyle,
        decoration: _dec(context, 'e.g., 2025-26'),
        validator: (v) {
          final value = (v ?? '').trim();
          if (value.isEmpty) return 'Enter your session';
          // Session format like 2025-26 (poll Q4/Q20).
          if (!RegExp(r'^\d{4}-\d{2}$').hasMatch(value)) {
            return 'Use the format 2025-26';
          }
          return null;
        },
      ),
      _label(context, 'Academic System'),
      SegmentedButton<String>(
        style: SegmentedButton.styleFrom(
          backgroundColor: context.colors.surfaceAlt,
          foregroundColor: context.colors.textSecondary,
          selectedForegroundColor: Colors.white,
          selectedBackgroundColor: context.colors.primary,
          side: BorderSide(color: context.colors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        segments: const [
          ButtonSegment(
            value: 'semester',
            label: Text('Semester'),
            icon: Icon(Icons.calendar_view_week_rounded, size: 18),
          ),
          ButtonSegment(
            value: 'yearly',
            label: Text('Year'),
            icon: Icon(Icons.calendar_today_rounded, size: 18),
          ),
        ],
        selected: {_academicSystem},
        onSelectionChanged: (selected) => setState(() {
          _academicSystem = selected.first;
          // Reset the dependent dropdown when the system changes so a stale
          // value (e.g. 8th) can't survive a switch to yearly (max 4th).
          _currentTerm = null;
        }),
      ),
      _label(context, 'Choose $_termUnit'),
      DropdownButtonFormField<int>(
        key: ValueKey('term-$_academicSystem'),
        initialValue: _currentTerm,
        isExpanded: true,
        style: textStyle,
        dropdownColor: context.colors.surface,
        decoration: _dec(
          context,
          'Select your current ${_termUnit.toLowerCase()}',
        ),
        items: List.generate(_termCount, (i) => i + 1)
            .map(
              (n) => DropdownMenuItem(
                value: n,
                child: Text('${_ordinal(n)} $_termUnit'),
              ),
            )
            .toList(),
        onChanged: (value) => setState(() => _currentTerm = value),
        validator: (v) =>
            v == null ? 'Select your current ${_termUnit.toLowerCase()}' : null,
      ),
      _label(context, 'Faculty'),

      DropdownButtonFormField<String>(
        initialValue: _facultyId,
        isExpanded: true,
        style: textStyle,
        dropdownColor: context.colors.surface,
        decoration: _dec(context, 'Select your faculty'),
        items: _faculties
            .map((f) => DropdownMenuItem(value: f.id, child: Text(f.name)))
            .toList(),
        onChanged: (value) => setState(() {
          _facultyId = value;
          _departmentId = null; // reset dependent dropdown
        }),
        validator: (v) => v == null ? 'Select your faculty' : null,
      ),
      _label(context, 'Department'),
      DropdownButtonFormField<String>(
        initialValue: _departmentId,
        isExpanded: true,
        style: textStyle,
        dropdownColor: context.colors.surface,
        decoration: _dec(
          context,
          _facultyId == null
              ? 'Select a faculty first'
              : 'Select your department',
        ),
        items: _departmentsForFaculty
            .map((d) => DropdownMenuItem(value: d.id, child: Text(d.name)))
            .toList(),
        onChanged: _facultyId == null
            ? null
            : (value) => setState(() => _departmentId = value),
        validator: (v) => v == null ? 'Select your department' : null,
      ),
      _label(context, 'Password'),
      TextFormField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        textInputAction: TextInputAction.done,
        style: textStyle,
        decoration: _dec(
          context,
          'Min. 8 characters',
          suffix: IconButton(
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: context.colors.textSecondary,
            ),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        validator: (v) => (v == null || v.length < 8)
            ? 'Password must be at least 8 characters'
            : null,
      ),
    ];
  }
}
