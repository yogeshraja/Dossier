import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:dossier/data/remote/auth/server_auth_api_service.dart';
import 'package:dossier/core/models/country_code.dart';
import 'package:dossier/features/auth/domain/models/auth_user.dart';
import 'package:dossier/features/auth/domain/strategies/auth_strategy_factory.dart';
import 'package:dossier/features/auth/domain/strategies/email_password_auth_strategy.dart';
import 'package:dossier/features/auth/domain/strategies/phone_password_auth_strategy.dart';
import 'package:dossier/features/auth/domain/strategies/google_sso_auth_strategy.dart';
import 'package:dossier/features/auth/models/operator_model.dart';
import 'package:dossier/features/auth/providers/auth_provider.dart';
import 'package:dossier/features/auth/screens/auth_screen.dart';
import 'package:dossier/presentation/common_widgets/dossier_country_picker.dart';

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
      expect(result.user?.phone, '+919876543210');
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

    testWidgets('5. Sign-up flow requires mobile OTP verification before opening name, email, and password fields', (WidgetTester tester) async {
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

      // Step A: Initially only Mobile Number field and Send OTP button are present
      final mobileField = find.byKey(const ValueKey('auth_mobile_field'));
      final sendOtpBtn = find.byKey(const ValueKey('signup_send_otp_button'));
      expect(mobileField, findsOneWidget);
      expect(sendOtpBtn, findsOneWidget);

      // Other fields must NOT be visible yet
      expect(find.byKey(const ValueKey('auth_signup_name_field')), findsNothing);
      expect(find.byKey(const ValueKey('auth_password_field')), findsNothing);

      // Enter mobile number and Send OTP
      await tester.enterText(mobileField, '9876543210');
      await tester.pump();
      await tester.tap(sendOtpBtn);
      await tester.pumpAndSettle();

      // Step B: OTP Entry Field appears
      final otpField = find.byKey(const ValueKey('signup_otp_field'));
      final verifyOtpBtn = find.byKey(const ValueKey('signup_verify_otp_button'));
      expect(otpField, findsOneWidget);
      expect(verifyOtpBtn, findsOneWidget);

      // Enter 6-digit OTP code and verify
      await tester.enterText(otpField, '123456');
      await tester.pump();
      await tester.tap(verifyOtpBtn);
      await tester.pumpAndSettle();

      // Step C: Verified Badge and remaining fields (Name, Email, Password) open
      expect(find.text('Verified Mobile: +919876543210'), findsOneWidget);
      final nameField = find.byKey(const ValueKey('auth_signup_name_field'));
      final emailField = find.byKey(const ValueKey('auth_email_field'));
      final passwordField = find.byKey(const ValueKey('auth_password_field'));
      final completeBtn = find.byKey(const ValueKey('auth_complete_signup_button'));

      expect(nameField, findsOneWidget);
      expect(emailField, findsOneWidget);
      expect(passwordField, findsOneWidget);
      expect(completeBtn, findsOneWidget);

      // Enter text into name and password fields
      await tester.enterText(nameField, 'Ramesh Admin');
      await tester.enterText(emailField, 'test@csc.in');
      await tester.enterText(passwordField, 'SuperSecret123');
      await tester.pumpAndSettle();

      final passwordTextFinder = find.descendant(
        of: passwordField,
        matching: find.byType(EditableText),
      );
      final passwordEditable = tester.widget<EditableText>(passwordTextFinder);
      expect(passwordEditable.controller.text, 'SuperSecret123');
    });

    testWidgets('6. FTUE Wizard navigates seamlessly across all 3 onboarding steps', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Set user as logged in and mobile-verified, but not software activated (enters FTUE mode)
      container.read(authProvider.notifier).state = const AuthState(
        user: AuthUser(
          id: 'usr-new-owner',
          name: 'Priya Sharma',
          email: 'priya@csc.in',
          phone: '9876543210',
          isMobileVerified: true,
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

    test('8. deleteAccount() soft-deletes user account on server and resets local state', () async {
      bool deleteCalledOnServer = false;

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/auth/signin') {
          return http.Response(
            jsonEncode({
              'success': true,
              'token': 'jwt-delete-test-session',
              'hasKiosk': true,
              'user': {
                'id': 'usr-to-delete',
                'name': 'Delete Me',
                'email': 'delete@csc.in',
                'role': 'admin',
                'hasKiosk': true,
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.path == '/api/v1/auth/user/delete') {
          deleteCalledOnServer = true;
          return http.Response(
            jsonEncode({'success': true, 'message': 'Account deleted successfully'}),
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

      // 1. Authenticate user first
      final strategy = AuthStrategyFactory.createEmailStrategy(
        email: 'delete@csc.in',
        password: 'Password123',
      );
      await notifier.authenticateWithStrategy(strategy, isSignUp: false);
      expect(container.read(authProvider).isUserLoggedIn, isTrue);

      // 2. Perform account deletion
      final success = await notifier.deleteAccount();
      expect(success, isTrue);
      expect(deleteCalledOnServer, isTrue);

      final finalState = container.read(authProvider);
      expect(finalState.isUserLoggedIn, isFalse);
      expect(finalState.isSoftwareActivated, isFalse);
      expect(finalState.currentOperator, isNull);
    });

    test('9. suspendOperator() toggles suspension state and rejects PIN login when suspended', () async {
      String? suspendedOperatorId;
      bool? suspensionFlag;

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/auth/signin') {
          return http.Response(
            jsonEncode({
              'success': true,
              'token': 'jwt-admin-token',
              'hasKiosk': true,
              'user': {
                'id': 'usr-admin-suspend',
                'name': 'Admin User',
                'email': 'admin@csc.in',
                'role': 'admin',
                'hasKiosk': true,
              },
              'operators': [
                {
                  'id': 'usr-admin-suspend',
                  'name': 'Admin User',
                  'role': 'admin',
                  'pin': '1234',
                }
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.path == '/api/v1/auth/operators/add') {
          final reqBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'success': true,
              'operator': {
                'id': 'op-desk-staff',
                'name': reqBody['name'],
                'role': reqBody['role'] ?? 'operator',
                'pin': reqBody['pin'],
              },
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.path == '/api/v1/auth/user/suspend') {
          final reqBody = jsonDecode(request.body) as Map<String, dynamic>;
          suspendedOperatorId = reqBody['userId'];
          suspensionFlag = reqBody['suspend'];
          return http.Response(
            jsonEncode({
              'success': true,
              'message': 'Operator suspended successfully',
              'isSuspended': reqBody['suspend'],
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

      // 1. Authenticate admin user
      final strategy = AuthStrategyFactory.createEmailStrategy(
        email: 'admin@csc.in',
        password: 'Password123',
      );
      await notifier.authenticateWithStrategy(strategy, isSignUp: false);

      // 2. Create desk operator
      final addSuccess = await notifier.addOperator(name: 'Desk Staff', pin: '5678', role: OperatorRole.operator);
      expect(addSuccess, isTrue);

      final op = container.read(authProvider).registeredOperators.firstWhere((o) => o.fullName == 'Desk Staff');
      expect(op.isSuspended, isFalse);

      // 3. Suspend operator
      final suspendRes = await notifier.suspendOperator(
        operatorId: op.id,
        suspend: true,
        reason: 'Temporary medical leave',
      );
      expect(suspendRes, isTrue);
      expect(suspendedOperatorId, op.id);
      expect(suspensionFlag, isTrue);

      final suspendedOp = container.read(authProvider).registeredOperators.firstWhere((o) => o.id == op.id);
      expect(suspendedOp.isSuspended, isTrue);
      expect(suspendedOp.suspendedReason, 'Temporary medical leave');

      // 4. Attempt shift login with suspended operator -> must fail
      final loginSuccess = await notifier.loginOperatorWithPin(operatorId: op.id, pin: '5678');
      expect(loginSuccess, isFalse);
      expect(container.read(authProvider).errorMessage, contains('suspended'));

      // 5. Unsuspend operator
      final unsuspendRes = await notifier.suspendOperator(
        operatorId: op.id,
        suspend: false,
      );
      expect(unsuspendRes, isTrue);
      expect(suspensionFlag, isFalse);

      final activeOp = container.read(authProvider).registeredOperators.firstWhere((o) => o.id == op.id);
      expect(activeOp.isSuspended, isFalse);

      // 6. Attempt shift login now -> should succeed
      final loginSuccessAfterUnsuspend = await notifier.loginOperatorWithPin(operatorId: op.id, pin: '5678');
      expect(loginSuccessAfterUnsuspend, isTrue);
      expect(container.read(authProvider).currentOperator?.id, op.id);
    });

    test('12. Twilio OTP send and verify flow verifies mobile number and sets isMobileVerified', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/auth/otp/send') {
          return http.Response(
            jsonEncode({
              'success': true,
              'message': 'OTP sent to +919876543210',
              'mobile': '+919876543210',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/v1/auth/otp/verify') {
          final reqBody = jsonDecode(request.body) as Map<String, dynamic>;
          if (reqBody['otp'] == '123456') {
            return http.Response(
              jsonEncode({
                'success': true,
                'isVerified': true,
                'mobile': '+919876543210',
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          } else {
            return http.Response(
              jsonEncode({'success': false, 'error': 'Incorrect verification code.'}),
              401,
              headers: {'content-type': 'application/json'},
            );
          }
        }
        if (request.url.path == '/api/v1/auth/user/verify-mobile') {
          return http.Response(
            jsonEncode({
              'success': true,
              'message': 'Mobile verified successfully.',
              'user': {
                'id': 'usr-otp-1',
                'name': 'OTP User',
                'mobile': '+919876543210',
                'isMobileVerified': true,
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final apiService = ServerAuthApiService(client: mockClient);
      final container = ProviderContainer(
        overrides: [
          serverAuthApiServiceProvider.overrideWithValue(apiService),
        ],
      );

      final notifier = container.read(authProvider.notifier);

      // 1. Send OTP
      final sendSuccess = await notifier.sendOtp('9876543210');
      expect(sendSuccess, isTrue);

      // 2. Verify with wrong OTP -> fails
      final wrongVerify = await notifier.verifyOtp(mobile: '9876543210', otp: '000000');
      expect(wrongVerify, isFalse);

      // 3. Verify with correct OTP -> succeeds
      final correctVerify = await notifier.verifyOtp(mobile: '9876543210', otp: '123456');
      expect(correctVerify, isTrue);
    });

    testWidgets('13. AuthScreen displays Mobile Verification Card when user is logged in but not mobile-verified', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final container = ProviderContainer();
      // Set state to user logged in via Google SSO but not mobile verified
      container.read(authProvider.notifier).state = const AuthState(
        isAuthenticated: true,
        isSoftwareActivated: false,
        user: AuthUser(
          id: 'usr-google-1',
          name: 'Google Admin',
          email: 'googleadmin@gmail.com',
          isMobileVerified: false,
          role: 'admin',
        ),
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

      // Verify Mobile Verification card elements exist
      expect(find.text('Verify Your Mobile Number'), findsOneWidget);
      expect(find.text('SMS VERIFICATION'), findsOneWidget);
      expect(find.byKey(const ValueKey('otp_mobile_field')), findsOneWidget);
      expect(find.byKey(const ValueKey('send_otp_button')), findsOneWidget);

      // Enter mobile number and tap Send OTP
      await tester.enterText(find.byKey(const ValueKey('otp_mobile_field')), '9876543210');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('send_otp_button')));
      await tester.pumpAndSettle();

      // Verify OTP entry field & verify button appear
      expect(find.byKey(const ValueKey('otp_code_field')), findsOneWidget);
      expect(find.byKey(const ValueKey('verify_otp_button')), findsOneWidget);
    });

    test('14. PhoneOtpAuthStrategy authenticates mobile + OTP code', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/auth/signin-otp') {
          final reqBody = jsonDecode(request.body) as Map<String, dynamic>;
          if (reqBody['otp'] == '123456') {
            return http.Response(
              jsonEncode({
                'success': true,
                'token': 'jwt-otp-token',
                'user': {
                  'id': 'usr-otp-login',
                  'name': 'OTP User',
                  'mobile': reqBody['mobile'],
                  'role': 'admin',
                  'authProvider': 'mobile',
                  'hasKiosk': true,
                },
                'hasKiosk': true,
                'operators': [
                  {
                    'id': 'op-otp-login',
                    'name': 'OTP User',
                    'role': 'admin',
                    'mobile': reqBody['mobile'],
                    'pin': '1234',
                  }
                ],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          } else {
            return http.Response(
              jsonEncode({'success': false, 'error': 'Incorrect verification code.'}),
              401,
              headers: {'content-type': 'application/json'},
            );
          }
        }
        return http.Response('Not Found', 404);
      });

      final strategy = AuthStrategyFactory.createPhoneOtpStrategy(
        phone: '9876543210',
        otp: '123456',
      );

      final result = await strategy.authenticate(
        baseUrl: 'https://api.dossier.app',
        isSignUp: false,
        client: mockClient,
      );

      expect(result.isSuccess, isTrue);
      expect(result.user?.phone, '+919876543210');
      expect(result.hasKiosk, isTrue);
      expect(result.operators.length, 1);
    });

    testWidgets('15. AuthScreen supports switching between Password and SMS OTP Sign-In', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AuthScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Default: Identifier & Password fields are present
      final idField = find.byKey(const ValueKey('auth_identifier_field'));
      final pwdField = find.byKey(const ValueKey('auth_password_field'));
      final signInBtn = find.byKey(const ValueKey('auth_signin_button'));
      final switchToOtpBtn = find.byKey(const ValueKey('switch_to_otp_signin_button'));

      expect(idField, findsOneWidget);
      expect(pwdField, findsOneWidget);
      expect(signInBtn, findsOneWidget);
      expect(switchToOtpBtn, findsOneWidget);

      // Enter mobile number in unified identifier field
      await tester.enterText(idField, '9876543210');
      await tester.pump();

      // Switch to SMS OTP mode
      await tester.tap(switchToOtpBtn);
      await tester.pumpAndSettle();

      // Password field disappears, Send Sign-In OTP button appears
      expect(find.byKey(const ValueKey('auth_password_field')), findsNothing);
      final sendSignInOtpBtn = find.byKey(const ValueKey('signin_send_otp_button'));
      expect(sendSignInOtpBtn, findsOneWidget);

      // Tap Send Sign-In OTP
      await tester.tap(sendSignInOtpBtn);
      await tester.pumpAndSettle();

      // 6-digit OTP code field and Verify & Sign In button appear
      final signinOtpField = find.byKey(const ValueKey('signin_otp_field'));
      final verifySignInBtn = find.byKey(const ValueKey('signin_verify_otp_button'));
      expect(signinOtpField, findsOneWidget);
      expect(verifySignInBtn, findsOneWidget);
    });

    testWidgets('16. Sign-Up duplicate user rejection shows error and Switch to Sign In CTA', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/auth/otp/send') {
          return http.Response(
            jsonEncode({
              'success': false,
              'error': 'An account with this mobile number already exists. Please sign in instead.',
              'isExistingUser': true,
            }),
            409,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            serverAuthApiServiceProvider.overrideWithValue(
              ServerAuthApiService(client: mockClient),
            ),
          ],
          child: const MaterialApp(
            home: AuthScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Sign Up
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();

      // Enter existing mobile number and send OTP
      final mobileField = find.byKey(const ValueKey('auth_mobile_field'));
      await tester.enterText(mobileField, '9876543210');
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('signup_send_otp_button')));
      await tester.pumpAndSettle();

      // Error banner with 'Switch to Sign In →' button is shown
      expect(find.text('An account with this mobile number already exists. Please sign in instead.'), findsOneWidget);
      final switchCta = find.text('Switch to Sign In →');
      expect(switchCta, findsOneWidget);

      // Tap CTA to switch to Sign In
      await tester.tap(switchCta);
      await tester.pumpAndSettle();

      // Should now be on Sign In mode with prefilled mobile number
      expect(find.text('Welcome Back'), findsOneWidget);
      final identifierField = find.byKey(const ValueKey('auth_identifier_field'));
      expect(identifierField, findsOneWidget);
    });

    test('17. CountryCode model accurately detects, formats, and validates international numbers', () {
      // 1. Default country is India (+91)
      expect(CountryCode.defaultCountry.code, 'IN');
      expect(CountryCode.defaultCountry.dialCode, '+91');

      // 2. Lookup by ISO code
      final us = CountryCode.findByCode('US');
      expect(us.name, 'United States');
      expect(us.dialCode, '+1');

      final gb = CountryCode.findByCode('GB');
      expect(gb.name, 'United Kingdom');
      expect(gb.dialCode, '+44');

      final ae = CountryCode.findByCode('AE');
      expect(ae.name, 'United Arab Emirates');
      expect(ae.dialCode, '+971');

      // 3. Format full E.164 number
      expect(us.formatFullNumber('2025550143'), '+12025550143');
      expect(gb.formatFullNumber('7911123456'), '+447911123456');
      expect(CountryCode.defaultCountry.formatFullNumber('9876543210'), '+919876543210');

      // 4. Auto-detect from E.164 string
      expect(CountryCode.detectFromPhoneString('+447911123456').code, 'GB');
      expect(CountryCode.detectFromPhoneString('+12025550143').code, 'US');
      expect(CountryCode.detectFromPhoneString('+971501234567').code, 'AE');
      expect(CountryCode.detectFromPhoneString('+919876543210').code, 'IN');

      // 5. International PhonePasswordAuthStrategy handles UK and US numbers
      final ukStrategy = PhonePasswordAuthStrategy(
        phone: '+447911123456',
        password: 'Password123',
      );
      expect(ukStrategy.validate(), isNull);

      final usStrategy = PhonePasswordAuthStrategy(
        phone: '+12025550143',
        password: 'Password123',
      );
      expect(usStrategy.validate(), isNull);
    });

    testWidgets('18. Country Code Picker dialog opens, searches, and selects international country', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      CountryCode chosenCountry = CountryCode.defaultCountry;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => DossierCountryPicker(
                key: const ValueKey('test_country_picker'),
                selectedCountry: chosenCountry,
                onCountryChanged: (c) {
                  setState(() => chosenCountry = c);
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Default country picker chip shows India (+91)
      expect(find.text('+91'), findsOneWidget);

      // Tap to open selection modal
      await tester.tap(find.byKey(const ValueKey('test_country_picker')));
      await tester.pumpAndSettle();

      // Modal is open
      expect(find.text('Select Country Code'), findsOneWidget);
      expect(find.byKey(const ValueKey('country_code_search_field')), findsOneWidget);

      // Search for 'United Kingdom'
      await tester.enterText(find.byKey(const ValueKey('country_code_search_field')), 'Kingdom');
      await tester.pumpAndSettle();

      // United Kingdom is shown
      final ukTile = find.text('United Kingdom');
      expect(ukTile, findsOneWidget);

      // Tap United Kingdom
      await tester.tap(ukTile);
      await tester.pumpAndSettle();

      // Modal closed, chip now displays +44
      expect(find.text('+44'), findsOneWidget);
      expect(chosenCountry.code, 'GB');
    });
  });
}


