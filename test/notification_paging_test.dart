import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whoreads/core/network/api_client.dart';
import 'package:whoreads/services/notification/notification_service.dart';
import 'release_readiness_test.dart' show FakeApi, jsonResponse;

void main() {
  setUp(() {
    dotenv.testLoad(fileInput: 'BASE_URL=https://example.invalid');
    ApiClient.dio.interceptors.clear();
  });

  test('Notifications use last ID when next_cursor is absent', () async {
    final cursors = <Object?>[];
    ApiClient.dio.httpClientAdapter = FakeApi((o) {
      final cursor = o.queryParameters['cursor'];
      cursors.add(cursor);
      return jsonResponse({
        'result': {
          'contents': [
            {'id': cursor == null ? '42' : '41'},
          ],
          'has_next': cursor == null,
        },
      });
    });
    final service = NotificationService();
    await service.refresh();
    await service.fetchMore();
    expect(cursors, [null, 42]);
    expect(service.notifications.map((e) => e['id']), ['42', '41']);
    expect(service.hasNext, false);
  });

  test(
    'Repeated notification cursor fails without appending duplicates',
    () async {
      ApiClient.dio.httpClientAdapter = FakeApi(
        (o) => jsonResponse({
          'result': {
            'contents': [
              {'id': 42},
            ],
            'has_next': true,
          },
        }),
      );
      final service = NotificationService();
      await service.refresh();
      await expectLater(service.fetchMore(), throwsFormatException);
      expect(service.notifications.length, 1);
      expect(service.isLoading, false);
    },
  );
}
