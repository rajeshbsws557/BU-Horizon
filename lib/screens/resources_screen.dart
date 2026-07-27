import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:mime/mime.dart';
import 'package:url_launcher/url_launcher.dart';

import '../di/di.dart';
import '../models/course_offering.dart';
import '../models/models.dart';
import '../repositories/course_repository.dart';
import '../repositories/resource_repository.dart';
import '../supabase/session_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/course_catalog.dart';
import '../widgets/motion.dart';
import '../widgets/pending_approval_view.dart';


/// Course-first resources for the signed-in student's batch.
class ResourcesScreen extends StatefulWidget {
  const ResourcesScreen({super.key});

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen> {
  late final CourseRepository _coursesRepository = getIt<CourseRepository>();
  bool _loading = true;
  bool _mutating = false;
  List<CourseOffering> _courses = const [];

  bool get _canManage =>
      getIt<SessionController>().profile?.role.toLowerCase() == 'cr';

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    if (mounted) setState(() => _loading = true);
    try {
      final courses = await _coursesRepository.fetchCourses();
      if (!mounted) return;
      setState(() {
        _courses = courses;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      showToast(context, 'Could not load your batch courses');
    }
  }

  Future<void> _addCourse() async {
    final input = await showCourseEditorSheet(context);
    if (input == null || !mounted) return;
    await _runMutation(
      () => _coursesRepository.createCourse(input),
      successMessage: 'Course added for your batch',
    );
  }

  Future<void> _editCourse(CourseOffering course) async {
    final input = await showCourseEditorSheet(context, course: course);
    if (input == null || !mounted) return;
    await _runMutation(
      () => _coursesRepository.updateCourse(course.id, input),
      successMessage: 'Course updated',
    );
  }

  Future<void> _deleteCourse(CourseOffering course) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete course?'),
        content: Text(
          '${course.code} will be removed from this batch. Its notices, '
          'resources and attendance will no longer appear in the student app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: dialogContext.colors.danger,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _runMutation(
      () => _coursesRepository.deleteCourse(course.id),
      successMessage: 'Course removed',
    );
  }

  Future<void> _runMutation(
    Future<void> Function() operation, {
    required String successMessage,
  }) async {
    if (_mutating) return;
    setState(() => _mutating = true);
    try {
      await operation();
      if (!mounted) return;
      showToast(context, successMessage);
      await _loadCourses();
    } catch (_) {
      if (mounted) showToast(context, 'Could not save that change');
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  void _openCourse(CourseOffering course) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _CourseResourcesScreen(course: course),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: getIt<SessionController>(),
      builder: (context, _) {
        final canManage = _canManage;
        final isPending =
            getIt<SessionController>().profile?.isPendingVerification == true;
        return Scaffold(
          appBar: AppBar(
            title: Text(
              'Resources',
              style: TextStyle(color: context.colors.textPrimary),
            ),
            backgroundColor: Colors.transparent,
            iconTheme: IconThemeData(color: context.colors.textPrimary),
            actions: [
              if (canManage && !isPending)
                IconButton(
                  onPressed: _mutating ? null : _addCourse,
                  tooltip: 'Add course',
                  icon: const Icon(Icons.add_rounded),
                ),
            ],
          ),
          body: isPending
              ? const PendingApprovalView(featureName: 'resources')
              : CourseCatalogView(

            isLoading: _loading,
            canManage: canManage,
            courses: _courses,
            featureName: 'resources',
            emptyIcon: Icons.folder_open_outlined,
            onRefresh: _loadCourses,
            onOpen: _openCourse,
            onEdit: canManage ? _editCourse : null,
            onDelete: canManage ? _deleteCourse : null,
          ),
        );
      },
    );
  }
}

class _CourseResourcesScreen extends StatefulWidget {
  final CourseOffering course;

  const _CourseResourcesScreen({required this.course});

  @override
  State<_CourseResourcesScreen> createState() => _CourseResourcesScreenState();
}

class _CourseResourcesScreenState extends State<_CourseResourcesScreen> {
  late final ResourceRepository _repository = getIt<ResourceRepository>();
  bool _loading = true;
  bool _mutating = false;
  List<ResourceItem> _resources = const [];

  bool get _canManage =>
      getIt<SessionController>().profile?.role.toLowerCase() == 'cr';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final resources = await _repository.fetchResources(
        offeringId: widget.course.id,
      );
      if (!mounted) return;
      setState(() {
        _resources = resources;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      showToast(context, 'Could not load course resources');
    }
  }

  Future<void> _open(ResourceItem resource) async {
    try {
      final target = await _repository.resolveResourceUrl(resource);
      if (!mounted) return;
      if (target.isEmpty) {
        showToast(context, 'This resource is no longer available');
        return;
      }
      final uri = Uri.tryParse(target);
      final opened =
          uri != null &&
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (opened || !mounted) return;
    } catch (_) {
      if (!mounted) return;
    }
    if (mounted) {
      showToast(context, 'Could not open ${resource.title}');
    }
  }

  Future<void> _addResource() async {
    final input = await showResourceEditorSheet(context);
    if (input == null || !mounted) return;
    await _runMutation(
      () => _repository.createResource(
        offeringId: widget.course.id,
        title: input.title,
        description: input.description,
        kind: input.kind,
        url: input.url,
        upload: input.upload,
      ),
      successMessage: 'Resource shared',
    );
  }

  Future<void> _editResource(ResourceItem resource) async {
    final input = await showResourceEditorSheet(context, resource: resource);
    if (input == null || !mounted) return;
    await _runMutation(
      () => _repository.updateResource(
        resourceId: resource.id,
        title: input.title,
        description: input.description,
        kind: input.kind,
        url: input.url,
        upload: input.upload,
        keepExistingUpload: input.keepExistingUpload,
      ),
      successMessage: 'Resource updated',
    );
  }

  Future<void> _deleteResource(ResourceItem resource) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete resource?'),
        content: Text(
          '“${resource.title}” will no longer be visible to students.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: dialogContext.colors.danger,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _runMutation(
      () => _repository.deleteResource(resource.id),
      successMessage: 'Resource deleted',
    );
  }

  Future<void> _runMutation(
    Future<void> Function() operation, {
    required String successMessage,
  }) async {
    if (_mutating) return;
    setState(() => _mutating = true);
    try {
      await operation();
      if (!mounted) return;
      showToast(context, successMessage);
      await _load();
    } catch (_) {
      if (mounted) showToast(context, 'Could not save that change');
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: getIt<SessionController>(),
      builder: (context, _) {
        final canManage = _canManage;
        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.course.code,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Resources',
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.transparent,
            iconTheme: IconThemeData(color: context.colors.textPrimary),
          ),
          floatingActionButton: canManage
              ? FloatingActionButton.extended(
                  onPressed: _mutating ? null : _addResource,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add resource'),
                )
              : null,
          body: RefreshIndicator(
            color: context.colors.primary,
            backgroundColor: context.colors.surfaceAlt,
            onRefresh: _load,
            child: _loading
                ? const _ResourceSkeletonList()
                : _resources.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      _CourseHeader(course: widget.course),
                      SizedBox(
                        height: MediaQuery.sizeOf(context).height * 0.48,
                        child: EmptyState(
                          icon: Icons.folder_open_outlined,
                          title: 'No resources yet',
                          message: canManage
                              ? 'Share the first file or link for this course.'
                              : 'Your CR has not shared a resource for this course yet.',
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      96,
                    ),
                    itemCount: _resources.length + 1,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _CourseHeader(course: widget.course);
                      }
                      final resource = _resources[index - 1];
                      return Entrance(
                        index: index - 1,
                        child: ResourceCard(
                          resource: resource,
                          canManage: canManage,
                          onOpen: () => _open(resource),
                          onEdit: () => _editResource(resource),
                          onDelete: () => _deleteResource(resource),
                        ),
                      );
                    },
                  ),
          ),
        );
      },
    );
  }
}

class _CourseHeader extends StatelessWidget {
  final CourseOffering course;
  const _CourseHeader({required this.course});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            context.colors.primary.withValues(alpha: 0.18),
            context.colors.accentCyan.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(
          color: context.colors.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: context.colors.primary,
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: const Icon(Icons.menu_book_rounded, color: Colors.white),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.code,
                  style: TextStyle(
                    color: context.colors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  course.title,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
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

class ResourceCard extends StatelessWidget {
  final ResourceItem resource;
  final bool canManage;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ResourceCard({
    super.key,
    required this.resource,
    required this.canManage,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  (IconData, Color, String) _style(
    BuildContext context,
  ) => switch (resource.kind) {
    ResourceKind.link => (Icons.link_rounded, context.colors.primary, 'Link'),
    ResourceKind.image => (Icons.image_rounded, context.colors.purple, 'Image'),
    ResourceKind.file => (
      Icons.description_rounded,
      context.colors.accentCyan,
      'File',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final (icon, color, kindLabel) = _style(context);
    return Semantics(
      label: '${resource.title}. ${resource.description}',
      button: true,
      excludeSemantics: true,
      child: Pressable(
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: cardDecoration(context: context),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            kindLabel,
                            style: TextStyle(
                              color: color,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          resource.dateLabel,
                          style: TextStyle(
                            color: context.colors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      resource.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    if (resource.description.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        resource.description,
                        style: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (canManage)
                PopupMenuButton<_ResourceAction>(
                  tooltip: 'Resource actions',
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: context.colors.textMuted,
                  ),
                  onSelected: (action) {
                    switch (action) {
                      case _ResourceAction.edit:
                        onEdit();
                      case _ResourceAction.delete:
                        onDelete();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: _ResourceAction.edit,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Edit resource'),
                      ),
                    ),
                    PopupMenuItem(
                      value: _ResourceAction.delete,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.delete_outline_rounded,
                          color: context.colors.danger,
                        ),
                        title: Text(
                          'Delete resource',
                          style: TextStyle(color: context.colors.danger),
                        ),
                      ),
                    ),
                  ],
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Icon(
                    Icons.open_in_new_rounded,
                    size: 18,
                    color: context.colors.textMuted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ResourceAction { edit, delete }

class _ResourceSkeletonList extends StatelessWidget {
  const _ResourceSkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, __) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: cardDecoration(context: context),
        child: const Row(
          children: [
            Skeleton(
              height: 44,
              width: 44,
              radius: BorderRadius.all(Radius.circular(AppRadii.md)),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(height: 11, width: 55),
                  SizedBox(height: AppSpacing.sm),
                  Skeleton(height: 14, width: 180),
                  SizedBox(height: AppSpacing.sm),
                  Skeleton(height: 12, width: 220),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

typedef ResourceInput = ({
  String title,
  String description,
  ResourceKind kind,
  String url,
  ResourceUpload? upload,
  bool keepExistingUpload,
});

enum _ResourceSource { link, upload }

String _formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kib = bytes / 1024;
  if (kib < 1024) return '${kib.toStringAsFixed(kib < 10 ? 1 : 0)} KB';
  final mib = kib / 1024;
  return '${mib.toStringAsFixed(mib < 10 ? 1 : 0)} MB';
}

Future<ResourceInput?> showResourceEditorSheet(
  BuildContext context, {
  ResourceItem? resource,
}) {
  return showModalBottomSheet<ResourceInput>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ResourceEditorSheet(resource: resource),
  );
}

class _ResourceEditorSheet extends StatefulWidget {
  final ResourceItem? resource;
  const _ResourceEditorSheet({this.resource});

  @override
  State<_ResourceEditorSheet> createState() => _ResourceEditorSheetState();
}

class _ResourceEditorSheetState extends State<_ResourceEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _url;
  late ResourceKind _kind;
  late _ResourceSource _source;
  ResourceUpload? _upload;
  String? _fileError;
  bool _picking = false;

  bool get _hasExistingUpload =>
      widget.resource?.storagePath.isNotEmpty ?? false;

  bool get _canKeepExistingUpload =>
      _hasExistingUpload && widget.resource?.kind == _kind;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.resource?.title ?? '');
    _description = TextEditingController(
      text: widget.resource?.description ?? '',
    );
    _source = _hasExistingUpload
        ? _ResourceSource.upload
        : _ResourceSource.link;
    _url = TextEditingController(
      text: _hasExistingUpload ? '' : widget.resource?.url ?? '',
    );
    _kind = widget.resource?.kind ?? ResourceKind.link;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    if (_picking) return;
    setState(() {
      _picking = true;
      _fileError = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: _kind == ResourceKind.image ? FileType.image : FileType.any,
        allowMultiple: false,
        withData: true,
      );
      if (result == null || !mounted) return;
      final file = result.files.single;
      final bytes = file.bytes;
      if (file.size > ResourceUpload.maxSizeBytes) {
        setState(() => _fileError = 'Choose a file no larger than 25 MB.');
        return;
      }
      if (bytes == null || bytes.isEmpty) {
        setState(
          () =>
              _fileError = 'Could not read that file. Please choose it again.',
        );
        return;
      }
      final mimeType =
          lookupMimeType(file.name, headerBytes: bytes) ??
          'application/octet-stream';
      if (_kind == ResourceKind.image && !mimeType.startsWith('image/')) {
        setState(() => _fileError = 'Choose a supported image file.');
        return;
      }
      setState(() {
        _upload = ResourceUpload(
          bytes: bytes,
          fileName: file.name,
          mimeType: mimeType,
        );
      });
    } catch (_) {
      if (mounted) {
        setState(() => _fileError = 'Could not access the selected file.');
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_source == _ResourceSource.upload &&
        _upload == null &&
        !_canKeepExistingUpload) {
      setState(() => _fileError = 'Choose a file to upload.');
      return;
    }
    Navigator.of(context).pop((
      title: _title.text.trim(),
      description: _description.text.trim(),
      kind: _kind,
      url: _source == _ResourceSource.link ? _url.text.trim() : '',
      upload: _source == _ResourceSource.upload ? _upload : null,
      keepExistingUpload:
          _source == _ResourceSource.upload &&
          _upload == null &&
          _canKeepExistingUpload,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadii.lg),
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.md,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.colors.border,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    widget.resource == null ? 'Add resource' : 'Edit resource',
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Share a downloadable file, image or web link with your batch.',
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  TextFormField(
                    controller: _title,
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: 160,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      prefixIcon: Icon(Icons.title_rounded),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter a resource title'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<_ResourceSource>(
                      segments: const [
                        ButtonSegment(
                          value: _ResourceSource.link,
                          icon: Icon(Icons.link_rounded),
                          label: Text('Web link'),
                        ),
                        ButtonSegment(
                          value: _ResourceSource.upload,
                          icon: Icon(Icons.upload_file_rounded),
                          label: Text('Upload'),
                        ),
                      ],
                      selected: {_source},
                      onSelectionChanged: (selected) {
                        final source = selected.first;
                        setState(() {
                          _source = source;
                          // Selected bytes belong to the previous source/type;
                          // make the user pick again after switching modes.
                          _upload = null;
                          _fileError = null;
                          if (source == _ResourceSource.upload &&
                              _kind == ResourceKind.link) {
                            _kind =
                                _hasExistingUpload &&
                                    widget.resource!.kind != ResourceKind.link
                                ? widget.resource!.kind
                                : ResourceKind.file;
                          } else if (source == _ResourceSource.link) {
                            _kind = ResourceKind.link;
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (_source == _ResourceSource.link)
                    TextFormField(
                      controller: _url,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'URL',
                        hintText: 'https://…',
                        prefixIcon: Icon(Icons.link_rounded),
                      ),
                      validator: (value) {
                        if (_source != _ResourceSource.link) return null;
                        final uri = Uri.tryParse(value?.trim() ?? '');
                        if (uri == null ||
                            !uri.hasScheme ||
                            !const {'http', 'https'}.contains(uri.scheme)) {
                          return 'Enter a valid http(s) URL';
                        }
                        return null;
                      },
                    )
                  else ...[
                    DropdownButtonFormField<ResourceKind>(
                      initialValue: _kind == ResourceKind.image
                          ? ResourceKind.image
                          : ResourceKind.file,
                      decoration: const InputDecoration(
                        labelText: 'Upload type',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: ResourceKind.file,
                          child: Text('File'),
                        ),
                        DropdownMenuItem(
                          value: ResourceKind.image,
                          child: Text('Image'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _kind = value;
                            _upload = null;
                            _fileError = null;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _UploadPicker(
                      selectedName:
                          _upload?.fileName ??
                          (_canKeepExistingUpload
                              ? widget.resource!.fileName
                              : ''),
                      selectedSize:
                          _upload?.sizeBytes ??
                          (_canKeepExistingUpload
                              ? widget.resource!.sizeBytes
                              : 0),
                      error: _fileError,
                      picking: _picking,
                      onPick: _pickFile,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _description,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  PrimaryButton(
                    label: widget.resource == null
                        ? 'Share resource'
                        : 'Save changes',
                    icon: widget.resource == null
                        ? Icons.upload_file_rounded
                        : Icons.check_rounded,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UploadPicker extends StatelessWidget {
  final String selectedName;
  final int selectedSize;
  final String? error;
  final bool picking;
  final VoidCallback onPick;

  const _UploadPicker({
    required this.selectedName,
    required this.selectedSize,
    required this.error,
    required this.picking,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.colors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: error == null ? context.colors.border : context.colors.danger,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            selectedName.isEmpty ? 'No file selected' : selectedName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selectedName.isEmpty
                  ? context.colors.textSecondary
                  : context.colors.textPrimary,
              fontWeight: selectedName.isEmpty
                  ? FontWeight.w400
                  : FontWeight.w600,
            ),
          ),
          if (selectedSize > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              _formatFileSize(selectedSize),
              style: TextStyle(color: context.colors.textMuted, fontSize: 11.5),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: picking ? null : onPick,
            icon: picking
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.attach_file_rounded),
            label: Text(selectedName.isEmpty ? 'Choose file' : 'Replace file'),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            error ?? 'Maximum upload size: 25 MB',
            style: TextStyle(
              color: error == null
                  ? context.colors.textMuted
                  : context.colors.danger,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}
