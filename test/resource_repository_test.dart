import 'dart:typed_data';

import 'package:bu_horizon/models/models.dart';
import 'package:bu_horizon/repositories/resource_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SampleResourceRepository uploads', () {
    test(
      'stores upload metadata and supports upload to link transition',
      () async {
        final repository = SampleResourceRepository();
        final upload = ResourceUpload(
          bytes: Uint8List.fromList([1, 2, 3, 4]),
          fileName: 'lecture.pdf',
          mimeType: 'application/pdf',
        );

        await repository.createResource(
          offeringId: 'offering-cse-1101',
          title: 'Lecture notes',
          description: '',
          kind: ResourceKind.file,
          url: '',
          upload: upload,
        );
        var resource = (await repository.fetchResources(
          offeringId: 'offering-cse-1101',
        )).first;
        expect(resource.storagePath, 'sample/lecture.pdf');
        expect(resource.fileName, 'lecture.pdf');
        expect(resource.mimeType, 'application/pdf');
        expect(resource.sizeBytes, 4);

        await repository.updateResource(
          resourceId: resource.id,
          title: resource.title,
          description: resource.description,
          kind: ResourceKind.link,
          url: 'https://example.com/lecture',
        );
        resource = (await repository.fetchResources(
          offeringId: 'offering-cse-1101',
        )).first;
        expect(resource.url, 'https://example.com/lecture');
        expect(resource.storagePath, isEmpty);
        expect(resource.fileName, isEmpty);
        expect(resource.sizeBytes, 0);
      },
    );

    test('new file and image resources require native uploads', () async {
      final repository = SampleResourceRepository();

      await expectLater(
        repository.createResource(
          offeringId: 'offering-cse-1101',
          title: 'External PDF',
          description: '',
          kind: ResourceKind.file,
          url: 'https://example.com/lecture.pdf',
        ),
        throwsArgumentError,
      );
    });

    test('changing an upload type requires a replacement file', () async {
      final repository = SampleResourceRepository();
      await repository.createResource(
        offeringId: 'offering-cse-1101',
        title: 'Lecture notes',
        description: '',
        kind: ResourceKind.file,
        url: '',
        upload: ResourceUpload(
          bytes: Uint8List.fromList([1, 2, 3]),
          fileName: 'lecture.pdf',
          mimeType: 'application/pdf',
        ),
      );
      final resource = (await repository.fetchResources(
        offeringId: 'offering-cse-1101',
      )).first;

      await expectLater(
        repository.updateResource(
          resourceId: resource.id,
          title: resource.title,
          description: resource.description,
          kind: ResourceKind.image,
          url: '',
          keepExistingUpload: true,
        ),
        throwsArgumentError,
      );
    });
  });
}
