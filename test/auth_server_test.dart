import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:dossier/data/remote/auth/server_auth_api_service.dart';
import 'package:dossier/features/auth/models/operator_model.dart';
import 'package:dossier/features/auth/providers/auth_provider.dart';

void main() {
  group('Server Authentication & Sign-Up Tests', () {
    test('1. ServerAuthApiService.signUp creates account and returns verified token', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/auth/signup') {
          final reqBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'token': 'jwt-server-token-12345',
              'operator': {
                'id': 'op-server-999',
                'fullName': reqBody['fullName'],
                'phoneNumber': reqBody['phoneNumber'],
                'email': reqBody['email'],
                'role': reqBody['role'],
                'kioskName': reqBody['kioskName'],
                'merchantUpiVpa': reqBody['merchantUpiVpa'],
              },
              'tenant': {
                'tenantId': 'tenant-555',
                'plan': 'KIOSK_PRO',
              },
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final api = ServerAuthApiService(client: mockClient);
      final result = await api.signUp(
        kioskName: 'Apex Digital Seva',
        operatorName: 'Arjun Verma',
        phone: '9876543210',
        email: 'arjun@apex.com',
        password: 'Password123',
        pin: '1122',
        role: OperatorRole.admin,
        merchantUpiVpa: 'apex@upi',
      );

      expect(result.isSuccess, isTrue);
      expect(result.token, 'jwt-server-token-12345');
      expect(result.operator?.fullName, 'Arjun Verma');
      expect(result.operator?.kioskName, 'Apex Digital Seva');
      expect(result.isOfflineFallback, isFalse);
    });

    test('2. ServerAuthApiService.signIn authenticates with server', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/auth/signin') {
          return http.Response(
            jsonEncode({
              'token': 'jwt-session-token-888',
              'operator': {
                'id': 'op-101',
                'fullName': 'Pooja Sharma',
                'phoneNumber': '9123456780',
                'role': 'manager',
                'pin': '4321',
                'kioskName': 'Balaji Kiosk',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Invalid credentials', 401);
      });

      final api = ServerAuthApiService(client: mockClient);
      final result = await api.signIn(
        identifier: '9123456780',
        password: 'secretPassword',
      );

      expect(result.isSuccess, isTrue);
      expect(result.token, 'jwt-session-token-888');
      expect(result.operator?.fullName, 'Pooja Sharma');
      expect(result.operator?.role, OperatorRole.manager);
    });

    test('3. AuthNotifier integrates server sign-up and stores local session', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/auth/signup') {
          return http.Response(
            jsonEncode({
              'token': 'jwt-new-account-token',
              'operator': {
                'id': 'op-remote-1',
                'fullName': 'Rohan Das',
                'phoneNumber': '9988776655',
                'role': 'admin',
                'kioskName': 'Rohan CSC Hub',
              },
            }),
            201,
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
      final success = await notifier.signUp(
        kioskName: 'Rohan CSC Hub',
        operatorName: 'Rohan Das',
        phone: '9988776655',
        password: 'PassWord!1',
        pin: '5566',
      );

      expect(success, isTrue);
      final state = container.read(authProvider);
      expect(state.isAuthenticated, isTrue);
      expect(state.serverAuthToken, 'jwt-new-account-token');
      expect(state.currentOperator?.fullName, 'Rohan Das');
      expect(state.registeredOperators.length, 1);
    });

    test('4. AuthNotifier handles offline cache fallback during server outage', () async {
      // Mock client that throws network error to simulate offline
      final mockClient = MockClient((request) async {
        throw http.ClientException('No Internet Connection');
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
      
      // Sign up while offline creates local profile
      final success = await notifier.signUp(
        kioskName: 'Offline Kiosk',
        operatorName: 'Offline Operator',
        phone: '9000000000',
        password: 'OfflinePassword',
        pin: '9999',
      );

      expect(success, isTrue);
      var state = container.read(authProvider);
      expect(state.isAuthenticated, isTrue);
      expect(state.isOfflineMode, isTrue);

      // Logout and sign back in offline with cached credentials
      notifier.logout();
      expect(container.read(authProvider).isAuthenticated, isFalse);

      final signInSuccess = await notifier.signInWithCredentials(
        identifier: '9000000000',
        password: 'OfflinePassword',
      );

      expect(signInSuccess, isTrue);
      state = container.read(authProvider);
      expect(state.isAuthenticated, isTrue);
      expect(state.currentOperator?.fullName, 'Offline Operator');
    });
  });
}
