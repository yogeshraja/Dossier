import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:dossier/data/remote/auth/server_auth_api_service.dart';
import 'package:dossier/features/auth/models/operator_model.dart';
import 'package:dossier/features/auth/providers/auth_provider.dart';

void main() {
  group('Software Activation & Two-Tier Operator Auth Tests', () {
    test('1. Admin activateSoftware registers kiosk and returns activation token with operators list', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/auth/activate') {
          final reqBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'success': true,
              'isActivated': true,
              'activationToken': 'jwt-activation-token-999',
              'admin': {
                'id': 'usr-admin-1',
                'name': reqBody['adminName'],
                'mobile': reqBody['mobile'],
                'role': 'admin',
              },
              'kiosk': {
                'id': 'ksk-100',
                'name': reqBody['kioskName'],
                'phone': reqBody['mobile'],
              },
              'operators': [
                {
                  'id': 'usr-admin-1',
                  'name': reqBody['adminName'],
                  'mobile': reqBody['mobile'],
                  'role': 'admin',
                  'pin': reqBody['pin'],
                }
              ],
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final api = ServerAuthApiService(client: mockClient);
      final result = await api.activateSoftware(
        adminName: 'Rajesh Kumar',
        phone: '9876543210',
        email: 'rajesh@csc.in',
        password: 'AdminPassword1',
        pin: '1234',
        kioskName: 'Balaji CSC Center',
        isNewRegistration: true,
      );

      expect(result.isSuccess, isTrue);
      expect(result.isActivated, isTrue);
      expect(result.token, 'jwt-activation-token-999');
      expect(result.operator?.fullName, 'Rajesh Kumar');
      expect(result.operator?.role, OperatorRole.admin);
      expect(result.operators.length, 1);
    });

    test('2. Admin provisions desk operator on server via createOperatorOnServer', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/auth/operators') {
          final reqBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'success': true,
              'operator': {
                'id': 'op-staff-2',
                'name': reqBody['name'],
                'role': reqBody['role'],
                'mobile': reqBody['mobile'],
                'email': reqBody['email'],
              },
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Unauthorized', 401);
      });

      final api = ServerAuthApiService(client: mockClient);
      final result = await api.createOperatorOnServer(
        token: 'valid-jwt-token',
        name: 'Suresh Desk',
        pin: '5678',
        role: OperatorRole.operator,
        phone: '9123456780',
        kioskName: 'Balaji CSC Center',
      );

      expect(result.isSuccess, isTrue);
      expect(result.operator?.fullName, 'Suresh Desk');
      expect(result.operator?.role, OperatorRole.operator);
      expect(result.operator?.pin, '5678');
    });

    test('3. AuthNotifier orchestrates Software Activation -> Operator Creation -> Operator PIN shift login', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/auth/activate') {
          return http.Response(
            jsonEncode({
              'success': true,
              'isActivated': true,
              'activationToken': 'token-xyz',
              'admin': {
                'id': 'adm-1',
                'name': 'Master Admin',
                'mobile': '9998887776',
                'role': 'admin',
              },
              'kiosk': {'id': 'ksk-1', 'name': 'Apex Kiosk'},
              'operators': [
                {'id': 'adm-1', 'name': 'Master Admin', 'role': 'admin', 'pin': '1111'}
              ],
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.path == '/api/v1/auth/operators') {
          final reqBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'success': true,
              'operator': {
                'id': 'op-counter-1',
                'name': reqBody['name'],
                'role': 'operator',
                'pin': reqBody['pin'],
              },
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.path == '/api/v1/auth/operator-login') {
          return http.Response(
            jsonEncode({
              'success': true,
              'token': 'shift-jwt-token',
              'operator': {
                'id': 'op-counter-1',
                'name': 'Counter Staff 1',
                'role': 'operator',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final container = ProviderContainer(
        overrides: [
          serverAuthApiServiceProvider.overrideWithValue(
            ServerAuthApiService(client: mockClient),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authProvider.notifier);

      // Step 1: Software is initially unactivated
      expect(container.read(authProvider).isSoftwareActivated, isFalse);
      expect(container.read(authProvider).isAuthenticated, isFalse);

      // Step 2: Admin activates software
      final activated = await notifier.activateSoftware(
        adminName: 'Master Admin',
        phone: '9998887776',
        password: 'Pass',
        pin: '1111',
        kioskName: 'Apex Kiosk',
        isNewRegistration: true,
      );
      expect(activated, isTrue);
      expect(container.read(authProvider).isSoftwareActivated, isTrue);
      expect(container.read(authProvider).isAuthenticated, isTrue);

      // Step 3: Admin provisions a staff operator
      final added = await notifier.addOperator(
        name: 'Counter Staff 1',
        pin: '9999',
        role: OperatorRole.operator,
      );
      expect(added, isTrue);
      expect(container.read(authProvider).registeredOperators.length, 2);

      // Step 4: Logout shift and login with staff operator PIN
      notifier.logout();
      expect(container.read(authProvider).isAuthenticated, isFalse);
      expect(container.read(authProvider).isSoftwareActivated, isTrue); // Software remains activated

      final shiftLogin = await notifier.loginOperatorWithPin(
        operatorId: 'op-counter-1',
        pin: '9999',
      );
      expect(shiftLogin, isTrue);
      expect(container.read(authProvider).isAuthenticated, isTrue);
      expect(container.read(authProvider).currentOperator?.fullName, 'Counter Staff 1');
    });
  });
}
