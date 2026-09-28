import 'dart:convert';
import 'package:flutter/material.dart';
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
import 'package:dossier/features/auth/screens/auth_screen.dart';

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

    testWidgets('5. AuthScreen form fields maintain strict isolation between email and password', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AuthScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap 'Sign Up' tab
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();

      // Locate fields by ValueKey
      final nameField = find.byKey(const ValueKey('auth_signup_name_field'));
      final emailField = find.byKey(const ValueKey('auth_email_field'));
      final passwordField = find.byKey(const ValueKey('auth_password_field'));

      expect(nameField, findsOneWidget);
      expect(emailField, findsOneWidget);
      expect(passwordField, findsOneWidget);

      // Enter text into name field
      await tester.enterText(nameField, 'Ramesh Admin');
      await tester.pumpAndSettle();

      // Enter text into email field
      await tester.enterText(emailField, 'test@csc.in');
      await tester.pumpAndSettle();

      // Verify that email input DID NOT fill the password field
      final passwordTextFinder = find.descendant(
        of: passwordField,
        matching: find.byType(EditableText),
      );
      final passwordEditable = tester.widget<EditableText>(passwordTextFinder);
      expect(passwordEditable.controller.text, isEmpty);

      // Verify that email field contains the exact email
      final emailTextFinder = find.descendant(
        of: emailField,
        matching: find.byType(EditableText),
      );
      final emailEditable = tester.widget<EditableText>(emailTextFinder);
      expect(emailEditable.controller.text, 'test@csc.in');

      // Now enter password and verify
      await tester.enterText(passwordField, 'SuperSecret123');
      await tester.pumpAndSettle();
      expect(passwordEditable.controller.text, 'SuperSecret123');
    });

    testWidgets('6. FTUE Wizard navigates seamlessly across all 3 onboarding steps', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Set user as logged in but not software activated (enters FTUE mode)
      container.read(authProvider.notifier).state = const AuthState(
        user: AuthUser(
          id: 'usr-new-owner',
          name: 'Priya Sharma',
          email: 'priya@csc.in',
          role: 'admin',
          hasKiosk: false,
        ),
        isAuthenticated: true,
        isSoftwareActivated: false,
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: AuthScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Step 1: Center Identity
      expect(find.text('FTUE ONBOARDING'), findsOneWidget);
      expect(find.text('Step 1 of 3'), findsOneWidget);
      expect(find.text('Center Name & Physical Address'), findsOneWidget);
      expect(find.byKey(const ValueKey('kiosk_setup_name_field')), findsOneWidget);

      // Tap Continue to Step 2
      final step1Btn = find.text('Continue to POS Setup →');
      await tester.ensureVisible(step1Btn);
      await tester.tap(step1Btn);
      await tester.pumpAndSettle();

      // Step 2: Touch POS & Hardware
      expect(find.text('Step 2 of 3'), findsOneWidget);
      expect(find.text('Touch POS & Payments Setup'), findsOneWidget);
      expect(find.byKey(const ValueKey('kiosk_setup_upi_field')), findsOneWidget);
      expect(find.text('58mm (Compact - 32 Chars)'), findsOneWidget);

      // Switch paper width chip
      final chip80 = find.text('80mm (Standard - 48 Chars)');
      await tester.ensureVisible(chip80);
      await tester.tap(chip80);
      await tester.pumpAndSettle();

      // Tap Continue to Step 3
      final step2Btn = find.text('Continue to Security PIN →');
      await tester.ensureVisible(step2Btn);
      await tester.tap(step2Btn);
      await tester.pumpAndSettle();

      // Step 3: Master Security PIN & Launch
      expect(find.text('Step 3 of 3'), findsOneWidget);
      expect(find.text('Master Admin PIN & Launch'), findsOneWidget);
      expect(find.byKey(const ValueKey('kiosk_setup_pin_field')), findsOneWidget);
      expect(find.byKey(const ValueKey('kiosk_setup_pin_confirm_field')), findsOneWidget);
      expect(find.text('Configuration Summary'), findsOneWidget);
      expect(find.text('Complete Setup & Launch 🚀'), findsOneWidget);
    });

    test('7. Returning sign-in preserves active kiosk status and bypasses FTUE setup', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/auth/signin') {
          return http.Response(
            jsonEncode({
              'success': true,
              'token': 'jwt-returning-session',
              'hasKiosk': true,
              'user': {
                'id': 'usr-existing-admin',
                'name': 'Aarav Gupta',
                'email': 'aarav@csc.in',
                'role': 'admin',
                'hasKiosk': true,
              },
              'kiosk': {
                'id': 'ksk-99',
                'name': 'Aarav CSC Document Center',
              },
              'operators': [
                {
                  'id': 'op-aarav',
                  'name': 'Aarav Gupta',
                  'role': 'admin',
                  'pin': '1234',
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
      final strategy = AuthStrategyFactory.createEmailStrategy(
        email: 'aarav@csc.in',
        password: 'Password123',
      );

      final loginSuccess = await notifier.authenticateWithStrategy(strategy, isSignUp: false);
      expect(loginSuccess, isTrue);

      final state = container.read(authProvider);
      // Verify returning user has kiosk activated and does not enter FTUE
      expect(state.isUserLoggedIn, isTrue);
      expect(state.isSoftwareActivated, isTrue);
      expect(state.adminOperator?.fullName, 'Aarav Gupta');
    });
  });
}

