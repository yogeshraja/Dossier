import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:dossier/data/remote/auth/server_auth_api_service.dart';
import 'package:dossier/features/auth/domain/models/auth_user.dart';
import 'package:dossier/features/auth/domain/strategies/auth_strategy_factory.dart';
import 'package:dossier/features/auth/domain/strategies/email_password_auth_strategy.dart';
import 'package:dossier/features/auth/domain/strategies/phone_password_auth_strategy.dart';
import 'package:dossier/features/auth/domain/strategies/google_sso_auth_strategy.dart';
import 'package:dossier/features/auth/providers/auth_provider.dart';

void main() {
  group('Auth Strategy Inheritance & Multi-Step Activation Tests', () {
    test('1. EmailPasswordAuthStrategy signs up user and validates input format', () async {
      final invalidStrategy = EmailPasswordAuthStrategy(email: 'invalid-email', password: '123');
      final validationErr = invalidStrategy.validate();
      expect(validationErr, isNotNull);

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/auth/signup') {
          final reqBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'success': true,
              'token': 'jwt-email-token',
              'user': {
                'id': 'usr-email-1',
                'name': reqBody['name'],
                'email': reqBody['email'],
                'role': 'admin',
                'authProvider': 'email',
                'hasKiosk': false,
              },
              'hasKiosk': false,
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final validStrategy = EmailPasswordAuthStrategy(
        email: 'admin@csc.in',
        password: 'SecurePassword123',
        name: 'Ramesh Admin',
        client: mockClient,
      );

      final result = await validStrategy.authenticate(baseUrl: 'https://api.dossier.app', isSignUp: true);
      expect(result.isSuccess, isTrue);
      expect(result.user?.email, 'admin@csc.in');
      expect(result.user?.provider, AuthProviderType.email);
      expect(result.hasKiosk, isFalse);
    });

    test('2. PhonePasswordAuthStrategy signs up user with 10-digit mobile number', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/auth/signup') {
          final reqBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'success': true,
              'token': 'jwt-phone-token',
              'user': {
                'id': 'usr-phone-1',
                'name': reqBody['name'],
                'mobile': reqBody['mobile'],
                'role': 'admin',
                'authProvider': 'mobile',
                'hasKiosk': false,
              },
              'hasKiosk': false,
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final phoneStrategy = PhonePasswordAuthStrategy(
        phone: '9876543210',
        password: 'Password123',
        name: 'Suresh Desk',
        client: mockClient,
      );

      final result = await phoneStrategy.authenticate(baseUrl: 'https://api.dossier.app', isSignUp: true);
      expect(result.isSuccess, isTrue);
      expect(result.user?.phone, '9876543210');
      expect(result.user?.provider, AuthProviderType.mobile);
    });

    test('3. GoogleSsoAuthStrategy exchanges mock SSO token for authenticated user session', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/auth/google') {
          return http.Response(
            jsonEncode({
              'success': true,
              'token': 'jwt-google-sso-token',
              'user': {
                'id': 'usr-google-1',
                'name': 'Google Kiosk Owner',
                'email': 'owner@gmail.com',
                'role': 'admin',
                'authProvider': 'google',
                'hasKiosk': false,
              },
              'hasKiosk': false,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final googleStrategy = GoogleSsoAuthStrategy(
        mockEmail: 'owner@gmail.com',
        mockName: 'Google Kiosk Owner',
        mockId: 'g_12345',
        client: mockClient,
      );

      final result = await googleStrategy.authenticate(baseUrl: 'https://api.dossier.app', isSignUp: false);
      expect(result.isSuccess, isTrue);
      expect(result.user?.email, 'owner@gmail.com');
      expect(result.user?.provider, AuthProviderType.google);
      expect(result.hasKiosk, isFalse);
    });

    test('4. Full Flow: User Login -> Kiosk Setup/Activation -> Operator Shift Login', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/auth/signin') {
          return http.Response(
            jsonEncode({
              'success': true,
              'token': 'jwt-user-session',
              'user': {
                'id': 'usr-main-admin',
                'name': 'Yogesh Owner',
                'email': 'yogesh@csc.in',
                'role': 'admin',
                'authProvider': 'email',
                'hasKiosk': false,
              },
              'hasKiosk': false,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.path == '/api/v1/auth/kiosk/register') {
          final reqBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'success': true,
              'isActivated': true,
              'activationToken': 'jwt-activated-token',
              'admin': {
                'id': reqBody['userId'],
                'name': 'Yogesh Owner',
                'email': 'yogesh@csc.in',
                'role': 'admin',
              },
              'kiosk': {
                'id': 'ksk-1',
                'name': reqBody['kioskName'],
                'address': reqBody['kioskAddress'],
                'merchantUpiVpa': reqBody['merchantUpiVpa'],
              },
              'operators': [
                {
                  'id': reqBody['userId'],
                  'name': 'Yogesh Owner',
                  'role': 'admin',
                  'email': 'yogesh@csc.in',
                  'pin': reqBody['pin'],
                }
              ],
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

      // Step 1: Initial state (Not logged in, not activated)
      expect(container.read(authProvider).isUserLoggedIn, isFalse);
      expect(container.read(authProvider).isSoftwareActivated, isFalse);

      // Step 2: User logs in with Email/Password strategy
      final strategy = AuthStrategyFactory.createEmailStrategy(
        email: 'yogesh@csc.in',
        password: 'Password123',
      );
      final loginSuccess = await notifier.authenticateWithStrategy(strategy, isSignUp: false);
      expect(loginSuccess, isTrue);
      expect(container.read(authProvider).isUserLoggedIn, isTrue);
      expect(container.read(authProvider).isSoftwareActivated, isFalse); // Kiosk not yet registered!

      // Step 3: Logged-in user sets up the kiosk and activates software
      final setupSuccess = await notifier.registerKioskAndActivate(
        kioskName: 'Main CSC Center',
        kioskAddress: 'Market Road #12',
        merchantUpiVpa: 'kiosk@upi',
        pin: '4321',
      );
      expect(setupSuccess, isTrue);
      expect(container.read(authProvider).isSoftwareActivated, isTrue);
      expect(container.read(authProvider).adminOperator?.fullName, 'Yogesh Owner');
      expect(container.read(authProvider).registeredOperators.length, 1);
    });
  });
}
