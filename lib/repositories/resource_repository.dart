import 'dart:typed_data';

import 'package:injectable/injectable.dart';

import '../models/models.dart';

/// In-memory file selected by a CR for upload to object storage.
final class ResourceUpload {
  static const maxSizeBytes = 25 * 1024 * 1024;

  final Uint8List bytes;
  final String fileName;
  final String mimeType;

  const ResourceUpload({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });

  int get sizeBytes => bytes.lengthInBytes;
}

/// Repository for the signed-in student's batch study resources.
abstract interface class ResourceRepository {
  Future<List<ResourceItem>> fetchResources({String? offeringId});

  /// Resolves a fresh target when the user opens a resource. Private Storage
  /// URLs are intentionally short-lived and must not be cached by the screen.
  Future<String> resolveResourceUrl(ResourceItem resource);

  Future<void> createResource({
    required String offeringId,
    required String title,
    required String description,
    required ResourceKind kind,
    required String url,
    ResourceUpload? upload,
  });

  Future<void> updateResource({
    required String resourceId,
    required String title,
    required String description,
    required ResourceKind kind,
    required String url,
    ResourceUpload? upload,
    bool keepExistingUpload = false,
  });

  Future<void> deleteResource(String resourceId);
}

@Injectable(as: ResourceRepository)
final class SampleResourceRepository implements ResourceRepository {
  final List<ResourceItem> _resources = [
    const ResourceItem(
      id: '1',
      offeringId: 'offering-cse-1101',
      title: 'C Programming Notes',
      kind: ResourceKind.link,
      description: 'Lecture notes covering week 1-4.',
      courseCode: 'CSE-1101',
      url: 'https://example.com/notes',
      dateLabel: 'Jul 18',
    ),
    const ResourceItem(
      id: '2',
      offeringId: 'offering-cse-1102',
      title: 'Discrete Math Problem Set',
      kind: ResourceKind.link,
      description: 'Practice problems for the midterm.',
      courseCode: 'CSE-1102',
      url: 'https://example.com/problems',
      dateLabel: 'Jul 15',
    ),
  ];
  int _nextId = 10;

  @override
  Future<List<ResourceItem>> fetchResources({String? offeringId}) async =>
      List.unmodifiable(
        offeringId == null
            ? _resources
            : _resources.where((item) => item.offeringId == offeringId),
      );

  @override
  Future<String> resolveResourceUrl(ResourceItem resource) async =>
      resource.url;

  @override
  Future<void> createResource({
    required String offeringId,
    required String title,
    required String description,
    required ResourceKind kind,
    required String url,
    ResourceUpload? upload,
  }) async {
    _validateTarget(kind: kind, url: url, upload: upload, isCreate: true);
    _resources.insert(
      0,
      ResourceItem(
        id: 'sample-resource-${_nextId++}',
        offeringId: offeringId,
        title: title,
        kind: kind,
        description: description,
        url: upload == null ? url : 'sample-upload://${upload.fileName}',
        storagePath: upload == null ? '' : 'sample/${upload.fileName}',
        fileName: upload?.fileName ?? '',
        mimeType: upload?.mimeType ?? '',
        sizeBytes: upload?.sizeBytes ?? 0,
        dateLabel: 'Today',
      ),
    );
  }

  @override
  Future<void> updateResource({
    required String resourceId,
    required String title,
    required String description,
    required ResourceKind kind,
    required String url,
    ResourceUpload? upload,
    bool keepExistingUpload = false,
  }) async {
    final index = _resources.indexWhere((item) => item.id == resourceId);
    if (index == -1) return;
    _validateTarget(
      kind: kind,
      url: url,
      upload: upload,
      keepExistingUpload: keepExistingUpload,
    );
    final current = _resources[index];
    if (keepExistingUpload && current.kind != kind) {
      throw ArgumentError(
        'Choose a replacement file before changing the upload type.',
      );
    }
    _resources[index] = _resources[index].copyWith(
      title: title,
      description: description,
      kind: kind,
      url: keepExistingUpload
          ? current.url
          : upload == null
          ? url
          : 'sample-upload://${upload.fileName}',
      storagePath: keepExistingUpload
          ? current.storagePath
          : upload == null
          ? ''
          : 'sample/${upload.fileName}',
      fileName: keepExistingUpload ? current.fileName : upload?.fileName ?? '',
      mimeType: keepExistingUpload ? current.mimeType : upload?.mimeType ?? '',
      sizeBytes: keepExistingUpload
          ? current.sizeBytes
          : upload?.sizeBytes ?? 0,
    );
  }

  @override
  Future<void> deleteResource(String resourceId) async {
    _resources.removeWhere((item) => item.id == resourceId);
  }

  static void _validateTarget({
    required ResourceKind kind,
    required String url,
    ResourceUpload? upload,
    bool keepExistingUpload = false,
    bool isCreate = false,
  }) {
    final targetCount = [
      url.trim().isNotEmpty,
      upload != null,
      keepExistingUpload,
    ].where((selected) => selected).length;
    if (targetCount != 1) {
      throw ArgumentError('Choose exactly one URL or uploaded file.');
    }
    if ((upload != null || keepExistingUpload) && kind == ResourceKind.link) {
      throw ArgumentError('Uploaded resources must be files or images.');
    }
    if (upload != null &&
        (upload.sizeBytes == 0 ||
            upload.sizeBytes > ResourceUpload.maxSizeBytes)) {
      throw ArgumentError('Uploads must be between 1 byte and 25 MB.');
    }
    if (isCreate && upload == null && kind != ResourceKind.link) {
      throw ArgumentError('New file and image resources must be uploaded.');
    }
  }
}
