import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spending_tracker/data/fixture_spending_repository.dart';
import 'package:spending_tracker/data/net/network_gate.dart';
import 'package:spending_tracker/data/net/product_lookup.dart';
import 'package:spending_tracker/domain/online_features.dart';

void main() {
  late FixtureSpendingRepository repo;
  late List<http.BaseRequest> requests;
  late DateTime now;

  setUp(() async {
    repo = FixtureSpendingRepository();
    requests = [];
    now = DateTime(2026, 9, 29, 12);
    await repo.setSetting(onlineFeaturesSettingKey, 'true');
    await repo.setSetting(OnlineFeature.productLookup.settingKey, 'true');
  });

  OpenFoodFactsLookup lookupAnswering(
      http.Response Function(http.Request) answer) {
    final gate = NetworkGate(repo,
        clientFactory: () => MockClient((request) async {
              requests.add(request);
              return answer(request);
            }));
    return OpenFoodFactsLookup(gate, repo, clock: () => now);
  }

  http.Response json(Object body, {int status = 200}) => http.Response.bytes(
      utf8.encode(jsonEncode(body)), status,
      headers: {'content-type': 'application/json'});

  test('asks Open Food Facts v3 with the app user agent', () async {
    final lookup = lookupAnswering((_) => json({
          'status': 'success',
          'product': {'product_name': 'Pepsi'},
        }));
    expect(await lookup.nameFor('6223001360612'), 'Pepsi');
    final request = requests.single;
    expect(request.url.host, 'world.openfoodfacts.org');
    expect(request.url.path, '/api/v3/product/6223001360612');
    expect(request.headers['User-Agent'], 'Masarifi/3.0 (personal Android app)');
  });

  test('prefers the Arabic name, then the name, then brand and quantity',
      () async {
    var product = <String, Object?>{
      'product_name_ar': 'بيبسي',
      'product_name': 'Pepsi',
      'brands': 'Pepsi',
      'quantity': '330 ml',
    };
    final lookup = lookupAnswering(
        (_) => json({'status': 'success', 'product': product}));
    expect(await lookup.nameFor('111111'), 'بيبسي');
    product = {'product_name_ar': ' ', 'product_name': 'Pepsi'};
    expect(await lookup.nameFor('111112'), 'Pepsi');
    product = {'product_name': '', 'brands': 'Juhayna, Juhayna Group',
        'quantity': '1 L'};
    expect(await lookup.nameFor('111113'), 'Juhayna 1 L');
    product = {'brands': ''};
    expect(await lookup.nameFor('111114'), isNull);
  });

  test('an unknown product, an error or a bad body gives no name', () async {
    var answer = json({'status': 'failure', 'result': {'id': 'product_not_found'}},
        status: 404);
    final lookup = lookupAnswering((_) => answer);
    expect(await lookup.nameFor('222222'), isNull);
    answer = http.Response('oops', 500);
    expect(await lookup.nameFor('222223'), isNull);
    answer = http.Response('not json', 200);
    expect(await lookup.nameFor('222224'), isNull);
  });

  test('a code that is not a product barcode is never sent', () async {
    final lookup = lookupAnswering((_) => json({}));
    expect(await lookup.nameFor('https://example.org'), isNull);
    expect(await lookup.nameFor('12/34'), isNull);
    expect(requests, isEmpty);
  });

  test('with the lookup switched off nothing is sent', () async {
    await repo.setSetting(OnlineFeature.productLookup.settingKey, 'false');
    final lookup = lookupAnswering((_) => json({}));
    expect(await lookup.nameFor('333333'), isNull);
    expect(requests, isEmpty);
  });

  test('at most 15 lookups a minute, remembered across lookups', () async {
    final lookup = lookupAnswering(
        (_) => json({'status': 'success', 'product': {'product_name': 'X'}}));
    for (var i = 0; i < 15; i++) {
      expect(await lookup.nameFor('40000$i'), 'X');
      now = now.add(const Duration(seconds: 1));
    }
    expect(await lookup.nameFor('500000'), isNull);
    expect(requests, hasLength(15));
    // A new lookup object reads the same stamps from the settings.
    final again = OpenFoodFactsLookup(
        NetworkGate(repo,
            clientFactory: () => MockClient((r) async {
                  requests.add(r);
                  return json({'status': 'success', 'product': {'product_name': 'Y'}});
                })),
        repo,
        clock: () => now);
    expect(await again.nameFor('500001'), isNull);
    // A minute after the first one, room opens again.
    now = DateTime(2026, 9, 29, 12, 1, 0, 1);
    expect(await again.nameFor('500002'), 'Y');
  });
}
