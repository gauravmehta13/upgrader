/*
 * Copyright (c) 2018-2023 Larry Aasen. All rights reserved.
 */

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/src/client.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:upgrader/upgrader.dart';

import 'appcast_test.dart';
import 'fake_appcast.dart';
import 'mock_itunes_client.dart';
import 'mock_play_store_client.dart';

// FYI: Platform.operatingSystem can be "macos" or "linux" in a unit test.
// FYI: defaultTargetPlatform is TargetPlatform.android in a unit test.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await preferences.clear();
    return true;
  });

  testWidgets('test Upgrader sharedInstance always returns same instance',
      (WidgetTester tester) async {
    final upgrader1 = Upgrader.sharedInstance;
    expect(upgrader1, isNotNull);
    final upgrader2 = Upgrader.sharedInstance;
    expect(upgrader2, isNotNull);
    expect(upgrader1 == upgrader2, isTrue);
  }, skip: false);

  testWidgets('test Upgrader multiple instances', (WidgetTester tester) async {
    await tester.runAsync(() async {
      final packageInfo = PackageInfo(
          appName: 'Upgrader',
          packageName: 'com.larryaasen.upgrader',
          version: '1.9.9',
          buildNumber: '400');

      final client = MockITunesSearchClient.setupMockClient();
      final upgrader = Upgrader(
          upgraderOS: MockUpgraderOS(ios: true),
          client: client,
          debugLogging: true);

      expect(tester.takeException(), null);
      await tester.pumpAndSettle();
      try {
        expect(upgrader.appName(), 'Upgrader');
      } catch (e) {
        expect(e, Upgrader.notInitializedExceptionMessage);
      }

      upgrader.installPackageInfo(packageInfo: packageInfo);
      expect(await upgrader.initialize(), isTrue);

      final upgrader1 = Upgrader(
          upgraderOS: MockUpgraderOS(ios: true),
          client: client,
          debugLogging: true);
      upgrader1.installPackageInfo(packageInfo: packageInfo);
      expect(await upgrader1.initialize(), isTrue);
    });
  });

  testWidgets('test Upgrader clearSavedSettings', (WidgetTester tester) async {
    await Upgrader.clearSavedSettings();
  }, skip: false);

  testWidgets('test Upgrader class', (WidgetTester tester) async {
    await tester.runAsync(() async {
      // test code here
      final client = MockITunesSearchClient.setupMockClient();
      final upgrader = Upgrader(
          upgraderOS: MockUpgraderOS(ios: true),
          client: client,
          debugLogging: true);

      expect(tester.takeException(), null);
      await tester.pumpAndSettle();
      try {
        expect(upgrader.appName(), 'Upgrader');
      } catch (e) {
        expect(e, Upgrader.notInitializedExceptionMessage);
      }

      upgrader.installPackageInfo(
          packageInfo: PackageInfo(
              appName: 'Upgrader',
              packageName: 'com.larryaasen.upgrader',
              version: '1.9.9',
              buildNumber: '400'));

      expect(await upgrader.initialize(), isTrue);

      // Calling initialize() a second time should do nothing
      expect(await upgrader.initialize(), isTrue);

      expect(upgrader.appName(), 'Upgrader');
      expect(upgrader.currentAppStoreVersion(), '5.6');
      expect(upgrader.currentInstalledVersion(), '1.9.9');
      expect(upgrader.isUpdateAvailable(), true);

      upgrader.installAppStoreVersion('1.2.3');
      expect(upgrader.currentAppStoreVersion(), '1.2.3');
      expect(upgrader.isUpdateAvailable(), false);

      upgrader.installAppStoreVersion('6.2.3');
      expect(upgrader.currentAppStoreVersion(), '6.2.3');
      expect(upgrader.isUpdateAvailable(), true);

      upgrader.installAppStoreVersion('1.1.1');
      expect(upgrader.currentAppStoreVersion(), '1.1.1');
      expect(upgrader.isUpdateAvailable(), false);

      await upgrader.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(upgrader.isUpdateAvailable(), true);

      upgrader.installAppStoreVersion('1.1.1');
      expect(upgrader.currentAppStoreVersion(), '1.1.1');
      expect(upgrader.isUpdateAvailable(), false);

      upgrader.installPackageInfo(
          packageInfo: PackageInfo(
              appName: 'Upgrader',
              packageName: 'com.larryaasen.upgrader.2',
              version: '1.9.9',
              buildNumber: '400'));

      await upgrader.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(upgrader.isUpdateAvailable(), true);

      upgrader.installPackageInfo(
          packageInfo: PackageInfo(
              appName: 'Upgrader',
              packageName: 'com.larryaasen.upgrader.3',
              version: '1.9.9',
              buildNumber: '400'));

      await upgrader.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(upgrader.isUpdateAvailable(), false);
    });
  });

  testWidgets('test installAppStoreListingURL', (WidgetTester tester) async {
    final upgrader = Upgrader();
    upgrader.installAppStoreListingURL(
        'https://itunes.apple.com/us/app/google-maps-transit-food/id585027354?mt=8&uo=4');

    expect(upgrader.currentAppStoreListingURL(),
        'https://itunes.apple.com/us/app/google-maps-transit-food/id585027354?mt=8&uo=4');
  }, skip: false);

  testWidgets('test UpgradeAlert', (WidgetTester tester) async {
    final client = MockITunesSearchClient.setupMockClient();
    final upgrader = Upgrader(
        upgraderOS: MockUpgraderOS(ios: true),
        client: client,
        debugLogging: true);

    upgrader.installPackageInfo(
        packageInfo: PackageInfo(
            appName: 'Upgrader',
            packageName: 'com.larryaasen.upgrader',
            version: '0.9.9',
            buildNumber: '400'));
    upgrader.initialize().then((value) {});
    await tester.pumpAndSettle();

    expect(upgrader.isUpdateAvailable(), true);
    expect(upgrader.isTooSoon(), false);

    expect(upgrader.messages, isNull);
    upgrader.messages = UpgraderMessages();
    expect(upgrader.messages, isNotNull);

    expect(upgrader.messages?.buttonTitleIgnore, 'IGNORE');
    expect(upgrader.messages?.buttonTitleLater, 'LATER');
    expect(upgrader.messages?.buttonTitleUpdate, 'UPDATE NOW');
    expect(upgrader.messages?.releaseNotes, 'Release Notes');

    upgrader.messages = MyUpgraderMessages();

    expect(upgrader.messages!.buttonTitleIgnore, 'aaa');
    expect(upgrader.messages!.buttonTitleLater, 'bbb');
    expect(upgrader.messages!.buttonTitleUpdate, 'ccc');
    expect(upgrader.messages!.releaseNotes, 'ddd');

    var called = false;
    var notCalled = true;

    final upgradeAlert = wrapper(
      UpgradeAlert(
        upgrader: upgrader,
        onUpdate: () {
          called = true;
          return true;
        },
        onIgnore: () {
          notCalled = false;
          return true;
        },
        onLater: () {
          notCalled = false;
          return true;
        },
        child: const Center(child: Text('Upgrading')),
      ),
    );
    await tester.pumpWidget(upgradeAlert);

    expect(find.text('Upgrader test'), findsOneWidget);
    expect(find.text('Upgrading'), findsOneWidget);

    // Pump the UI so the upgrader can display its dialog
    await tester.pumpAndSettle();

    expect(upgrader.isTooSoon(), true);

    expect(find.text(upgrader.messages!.title), findsOneWidget);
    expect(find.text(upgrader.body(upgrader.messages!)), findsOneWidget);
    expect(find.text(upgrader.messages!.releaseNotes), findsOneWidget);
    expect(find.text(upgrader.releaseNotes!), findsOneWidget);
    expect(find.text(upgrader.messages!.prompt), findsOneWidget);
    expect(find.byType(TextButton), findsNWidgets(3));
    expect(find.text(upgrader.messages!.buttonTitleIgnore), findsOneWidget);
    expect(find.text(upgrader.messages!.buttonTitleLater), findsOneWidget);
    expect(find.text(upgrader.messages!.buttonTitleUpdate), findsOneWidget);
    expect(find.text(upgrader.messages!.releaseNotes), findsOneWidget);

    await tester.tap(find.text(upgrader.messages!.buttonTitleUpdate));
    await tester.pumpAndSettle();
    expect(find.text(upgrader.messages!.buttonTitleIgnore), findsNothing);
    expect(find.text(upgrader.messages!.buttonTitleLater), findsNothing);
    expect(find.text(upgrader.messages!.buttonTitleUpdate), findsNothing);
    expect(find.text(upgrader.messages!.releaseNotes), findsNothing);
    expect(called, true);
    expect(notCalled, true);
    // });
  }, skip: false);

  testWidgets('test UpgradeAlert Cupertino', (WidgetTester tester) async {
    final client = MockITunesSearchClient.setupMockClient();

    const cupertinoButtonTextStyle = TextStyle(
      fontSize: 14,
      color: Colors.green,
    );
    final upgrader = Upgrader(
      upgraderOS: MockUpgraderOS(ios: true),
      client: client,
      debugLogging: true,
    );

    upgrader.installPackageInfo(
        packageInfo: PackageInfo(
            appName: 'Upgrader',
            packageName: 'com.larryaasen.upgrader',
            version: '0.9.9',
            buildNumber: '400'));
    upgrader.initialize().then((value) {});
    await tester.pumpAndSettle();

    expect(upgrader.isUpdateAvailable(), true);
    expect(upgrader.isTooSoon(), false);

    expect(upgrader.messages, isNull);
    upgrader.messages = UpgraderMessages();
    expect(upgrader.messages, isNotNull);

    expect(upgrader.messages!.buttonTitleIgnore, 'IGNORE');
    expect(upgrader.messages!.buttonTitleLater, 'LATER');
    expect(upgrader.messages!.buttonTitleUpdate, 'UPDATE NOW');

    upgrader.messages = MyUpgraderMessages();

    expect(upgrader.messages!.buttonTitleIgnore, 'aaa');
    expect(upgrader.messages!.buttonTitleLater, 'bbb');
    expect(upgrader.messages!.buttonTitleUpdate, 'ccc');

    var called = false;
    var notCalled = true;

    final upgradeAlert = wrapper(
      UpgradeAlert(
        upgrader: upgrader,
        cupertinoButtonTextStyle: cupertinoButtonTextStyle,
        dialogStyle: UpgradeDialogStyle.cupertino,
        onUpdate: () {
          called = true;
          return true;
        },
        onIgnore: () {
          notCalled = false;
          return true;
        },
        onLater: () {
          notCalled = false;
          return true;
        },
        child: const Center(child: Text('Upgrading')),
      ),
    );
    await tester.pumpWidget(upgradeAlert);

    expect(find.text('Upgrader test'), findsOneWidget);
    expect(find.text('Upgrading'), findsOneWidget);

    // Pump the UI so the upgrader can display its dialog
    await tester.pumpAndSettle();

    expect(upgrader.isTooSoon(), true);

    expect(find.text(upgrader.messages!.title), findsOneWidget);
    expect(find.text(upgrader.body(upgrader.messages!)), findsOneWidget);
    expect(find.text(upgrader.messages!.releaseNotes), findsOneWidget);
    expect(find.text(upgrader.releaseNotes!), findsOneWidget);
    expect(find.text(upgrader.messages!.prompt), findsOneWidget);
    expect(find.byType(CupertinoDialogAction), findsNWidgets(3));
    expect(
      find.byWidgetPredicate((widget) =>
          widget is CupertinoDialogAction &&
          widget.textStyle == cupertinoButtonTextStyle),
      findsNWidgets(3),
    );
    expect(find.text(upgrader.messages!.buttonTitleIgnore), findsOneWidget);
    expect(find.text(upgrader.messages!.buttonTitleLater), findsOneWidget);
    expect(find.text(upgrader.messages!.buttonTitleUpdate), findsOneWidget);

    await tester.tap(find.text(upgrader.messages!.buttonTitleUpdate));
    await tester.pumpAndSettle();
    expect(find.text(upgrader.messages!.buttonTitleIgnore), findsNothing);
    expect(find.text(upgrader.messages!.buttonTitleLater), findsNothing);
    expect(find.text(upgrader.messages!.buttonTitleUpdate), findsNothing);
    expect(called, true);
    expect(notCalled, true);
  }, skip: false);

  testWidgets('test UpgradeAlert ignore', (WidgetTester tester) async {
    final client = MockITunesSearchClient.setupMockClient();
    final upgrader =
        Upgrader(upgraderOS: MockUpgraderOS(ios: true), client: client);

    upgrader.installPackageInfo(
        packageInfo: PackageInfo(
            appName: 'Upgrader',
            packageName: 'com.larryaasen.upgrader',
            version: '0.9.9',
            buildNumber: '400'));
    upgrader.initialize().then((value) {});
    await tester.pumpAndSettle();

    expect(upgrader.isTooSoon(), false);

    expect(upgrader.messages, isNull);
    upgrader.messages = UpgraderMessages();
    expect(upgrader.messages, isNotNull);

    var called = false;
    var notCalled = true;
    final upgradeAlert = wrapper(
      UpgradeAlert(
        upgrader: upgrader,
        onUpdate: () {
          notCalled = false;
          return true;
        },
        onIgnore: () {
          called = true;
          return true;
        },
        onLater: () {
          notCalled = false;
          return true;
        },
        child: const Center(child: Text('Upgrading')),
      ),
    );
    await tester.pumpWidget(upgradeAlert);

    // Pump the UI so the upgrader can display its dialog
    await tester.pumpAndSettle();

    await tester.tap(find.text(upgrader.messages!.buttonTitleIgnore));
    await tester.pumpAndSettle();
    expect(find.text(upgrader.messages!.buttonTitleIgnore), findsNothing);
    expect(called, true);
    expect(notCalled, true);
  }, skip: false);

  testWidgets('test UpgradeAlert later', (WidgetTester tester) async {
    final client = MockITunesSearchClient.setupMockClient();
    final upgrader =
        Upgrader(upgraderOS: MockUpgraderOS(ios: true), client: client);

    upgrader.installPackageInfo(
        packageInfo: PackageInfo(
            appName: 'Upgrader',
            packageName: 'com.larryaasen.upgrader',
            version: '0.9.9',
            buildNumber: '400'));
    upgrader.initialize().then((value) {});
    await tester.pumpAndSettle();

    expect(upgrader.isTooSoon(), false);

    expect(upgrader.messages, isNull);
    upgrader.messages = UpgraderMessages();
    expect(upgrader.messages, isNotNull);

    var called = false;
    var notCalled = true;
    final upgradeAlert = wrapper(
      UpgradeAlert(
        upgrader: upgrader,
        onUpdate: () {
          notCalled = false;
          return true;
        },
        onIgnore: () {
          notCalled = false;
          return true;
        },
        onLater: () {
          called = true;
          return true;
        },
        child: const Center(child: Text('Upgrading')),
      ),
    );
    await tester.pumpWidget(upgradeAlert);

    // Pump the UI so the upgrader can display its dialog
    await tester.pumpAndSettle();

    await tester.tap(find.text(upgrader.messages!.buttonTitleLater));
    await tester.pumpAndSettle();
    expect(find.text(upgrader.messages!.buttonTitleLater), findsNothing);
    expect(called, true);
    expect(notCalled, true);
  }, skip: false);

  testWidgets('test UpgradeAlert pop scope', (WidgetTester tester) async {
    final client = MockITunesSearchClient.setupMockClient();
    final upgrader =
        Upgrader(upgraderOS: MockUpgraderOS(ios: true), client: client);

    upgrader.installPackageInfo(
        packageInfo: PackageInfo(
            appName: 'Upgrader',
            packageName: 'com.larryaasen.upgrader',
            version: '0.9.9',
            buildNumber: '400'));
    upgrader.initialize().then((value) {});
    await tester.pumpAndSettle();

    expect(upgrader.isTooSoon(), false);

    expect(upgrader.messages, isNull);
    upgrader.messages = UpgraderMessages();
    expect(upgrader.messages, isNotNull);

    var called = false;
    final upgradeAlert = wrapper(
      UpgradeAlert(
        upgrader: upgrader,
        shouldPopScope: () {
          called = true;
          return true;
        },
        child: const Center(child: Text('Upgrading')),
      ),
    );
    await tester.pumpWidget(upgradeAlert);

    // Pump the UI so the upgrader can display its dialog
    await tester.pumpAndSettle();

    // Note: his test does not pop scope because there is no way to do that.
    // await tester.pageBack();
    // await tester.pumpAndSettle();
    // expect(find.text(upgrader.messages.buttonTitleLater), findsNothing);
    expect(called, false);
  }, skip: false);

  testWidgets('test UpgradeCard upgrade', (WidgetTester tester) async {
    final client = MockITunesSearchClient.setupMockClient();
    final upgrader = Upgrader(
        upgraderOS: MockUpgraderOS(ios: true),
        client: client,
        debugLogging: true);

    upgrader.installPackageInfo(
        packageInfo: PackageInfo(
            appName: 'Upgrader',
            packageName: 'com.larryaasen.upgrader',
            version: '0.9.9',
            buildNumber: '400'));
    upgrader.initialize().then((value) {});
    await tester.pumpAndSettle();

    expect(upgrader.isTooSoon(), false);

    var called = false;
    var notCalled = true;
    final upgradeCard = wrapper(
      UpgradeCard(
        upgrader: upgrader,
        onUpdate: () {
          called = true;
          return true;
        },
        onIgnore: () {
          notCalled = false;
          return true;
        },
        onLater: () {
          notCalled = false;
        },
      ),
    );
    await tester.pumpWidget(upgradeCard);

    // Pump the UI so the upgrade card is displayed
    await tester.pumpAndSettle();

    expect(upgrader.messages, isNull);
    upgrader.messages = UpgraderMessages();
    expect(upgrader.messages, isNotNull);

    expect(find.text(upgrader.messages!.releaseNotes), findsOneWidget);
    expect(find.text(upgrader.releaseNotes!), findsOneWidget);
    await tester.tap(find.text(upgrader.messages!.buttonTitleUpdate));
    await tester.pumpAndSettle();

    expect(called, true);
    expect(notCalled, true);
    expect(find.text(upgrader.messages!.buttonTitleUpdate), findsNothing);
  }, skip: false);

  testWidgets('test UpgradeCard ignore', (WidgetTester tester) async {
    final client = MockITunesSearchClient.setupMockClient();
    final upgrader = Upgrader(
        upgraderOS: MockUpgraderOS(ios: true),
        client: client,
        debugLogging: true);

    upgrader.installPackageInfo(
        packageInfo: PackageInfo(
            appName: 'Upgrader',
            packageName: 'com.larryaasen.upgrader',
            version: '0.9.9',
            buildNumber: '400'));
    upgrader.initialize().then((value) {});
    await tester.pumpAndSettle();

    expect(upgrader.isTooSoon(), false);

    var called = false;
    var notCalled = true;
    final upgradeCard = wrapper(
      UpgradeCard(
        upgrader: upgrader,
        onUpdate: () {
          notCalled = false;
          return true;
        },
        onIgnore: () {
          called = true;
          return true;
        },
        onLater: () {
          notCalled = false;
        },
      ),
    );
    await tester.pumpWidget(upgradeCard);

    // Pump the UI so the upgrade card is displayed
    await tester.pumpAndSettle();

    expect(upgrader.messages, isNull);
    upgrader.messages = UpgraderMessages();
    expect(upgrader.messages, isNotNull);

    await tester.tap(find.text(upgrader.messages!.buttonTitleIgnore));
    await tester.pumpAndSettle();

    expect(called, true);
    expect(notCalled, true);
    expect(find.text(upgrader.messages!.buttonTitleIgnore), findsNothing);
  }, skip: false);

  testWidgets('test UpgradeCard later', (WidgetTester tester) async {
    final client = MockITunesSearchClient.setupMockClient();
    final upgrader = Upgrader(
        upgraderOS: MockUpgraderOS(ios: true),
        client: client,
        debugLogging: true);

    upgrader.installPackageInfo(
        packageInfo: PackageInfo(
            appName: 'Upgrader',
            packageName: 'com.larryaasen.upgrader',
            version: '0.9.9',
            buildNumber: '400'));
    upgrader.initialize().then((value) {});
    await tester.pumpAndSettle();

    expect(upgrader.isTooSoon(), false);

    var called = false;
    var notCalled = true;
    final upgradeCard = wrapper(
      UpgradeCard(
        upgrader: upgrader,
        onUpdate: () {
          notCalled = false;
          return true;
        },
        onIgnore: () {
          notCalled = false;
          return true;
        },
        onLater: () {
          called = true;
        },
      ),
    );
    await tester.pumpWidget(upgradeCard);

    // Pump the UI so the upgrade card is displayed
    await tester.pumpAndSettle(const Duration(milliseconds: 5000));

    expect(upgrader.messages, isNull);
    upgrader.messages = UpgraderMessages();
    expect(upgrader.messages, isNotNull);

    await tester.tap(find.text(upgrader.messages!.buttonTitleLater));
    await tester.pumpAndSettle();

    expect(called, true);
    expect(notCalled, true);
    expect(find.text(upgrader.messages!.buttonTitleLater), findsNothing);
  }, skip: false);

  testWidgets('test upgrader minAppVersion', (WidgetTester tester) async {
    final client = MockITunesSearchClient.setupMockClient();
    final upgrader = Upgrader(
        upgraderOS: MockUpgraderOS(ios: true),
        client: client,
        debugLogging: true);
    upgrader.minAppVersion = '1.0.0';

    upgrader.installPackageInfo(
        packageInfo: PackageInfo(
            appName: 'Upgrader',
            packageName: 'com.larryaasen.upgrader',
            version: '0.9.9',
            buildNumber: '400'));
    upgrader.initialize().then((value) {});
    await tester.pumpAndSettle();

    expect(upgrader.isTooSoon(), false);
    upgrader.minAppVersion = '0.5.0';
    expect(upgrader.belowMinAppVersion(), false);
    upgrader.minAppVersion = '1.0.0';
    expect(upgrader.belowMinAppVersion(), true);
    upgrader.minAppVersion = null;
    expect(upgrader.belowMinAppVersion(), false);
    upgrader.minAppVersion = 'empty';
    expect(upgrader.belowMinAppVersion(), false);
    upgrader.minAppVersion = '0.9.9+4';
    expect(upgrader.belowMinAppVersion(), false);
    upgrader.minAppVersion = '0.9.9-5.2.pre';
    expect(upgrader.belowMinAppVersion(), false);
    upgrader.minAppVersion = '1.0.0-5.2.pre';
    expect(upgrader.belowMinAppVersion(), true);

    upgrader.minAppVersion = '1.0.0';

    final upgradeCard = wrapper(
      UpgradeCard(
        upgrader: upgrader,
      ),
    );
    await tester.pumpWidget(upgradeCard);

    // Pump the UI so the upgrade card is displayed
    await tester.pumpAndSettle(const Duration(milliseconds: 5000));

    expect(upgrader.messages, isNull);
    upgrader.messages = UpgraderMessages();
    expect(upgrader.messages, isNotNull);

    expect(find.text(upgrader.messages!.buttonTitleIgnore), findsNothing);
    expect(find.text(upgrader.messages!.buttonTitleLater), findsNothing);
    expect(find.text(upgrader.messages!.buttonTitleUpdate), findsOneWidget);
  }, skip: false);

  testWidgets('test upgrader minAppVersion description android',
      (WidgetTester tester) async {
    final client = await MockPlayStoreSearchClient.setupMockClient();
    final upgrader = Upgrader(
        upgraderOS: MockUpgraderOS(android: true),
        client: client,
        debugLogging: true);

    upgrader.installPackageInfo(
        packageInfo: PackageInfo(
            appName: 'Upgrader',
            packageName: 'com.testing.test2',
            version: '2.9.9',
            buildNumber: '400'));
    upgrader.initialize().then((value) {});
    await tester.pumpAndSettle();

    expect(upgrader.belowMinAppVersion(), true);
    expect(upgrader.minAppVersion, '4.5.6');
  }, skip: false);

  testWidgets('test upgrader minAppVersion description ios',
      (WidgetTester tester) async {
    final client = MockITunesSearchClient.setupMockClient(
      description: 'Use this app. [:mav: 4.5.6]',
    );
    final upgrader = Upgrader(
        upgraderOS: MockUpgraderOS(ios: true),
        client: client,
        debugLogging: true);

    upgrader.installPackageInfo(
        packageInfo: PackageInfo(
            appName: 'Upgrader',
            packageName: 'com.larryaasen.upgrader',
            version: '2.9.9',
            buildNumber: '400'));
    upgrader.initialize().then((value) {});
    await tester.pumpAndSettle();

    expect(upgrader.belowMinAppVersion(), true);
    expect(upgrader.minAppVersion, '4.5.6');
  }, skip: false);

  testWidgets('test UpgradeWidget unknown app', (WidgetTester tester) async {
    final client = MockITunesSearchClient.setupMockClient();
    final upgrader = Upgrader(
        upgraderOS: MockUpgraderOS(ios: true),
        client: client,
        debugLogging: true,
        countryCode: 'IT',
        languageCode: 'en');

    upgrader.installPackageInfo(
        packageInfo: PackageInfo(
            appName: 'MyApp',
            packageName: 'com.google.MyApp',
            version: '0.1.0',
            buildNumber: '1'));
    upgrader.initialize().then((value) {});
    await tester.pumpAndSettle();

    expect(upgrader.isTooSoon(), false);

    var called = false;
    var notCalled = true;
    final upgradeCard = wrapper(
      UpgradeCard(
        upgrader: upgrader,
        onUpdate: () {
          notCalled = false;
          return true;
        },
        onIgnore: () {
          notCalled = false;
          return true;
        },
        onLater: () {
          called = true;
        },
      ),
    );
    await tester.pumpWidget(upgradeCard);

    // Pump the UI so the upgrade card is displayed
    await tester.pumpAndSettle();

    expect(upgrader.messages, isNull);
    upgrader.messages = UpgraderMessages();
    expect(upgrader.messages, isNotNull);

    final laterButton = find.text(upgrader.messages!.buttonTitleLater);
    expect(laterButton, findsNothing);

    expect(called, false);
    expect(notCalled, true);
  }, skip: false);

  group('initialize', () {
    test('should use fake Appcast', () async {
      final fakeAppcast = FakeAppcast();
      final client = MockITunesSearchClient.setupMockClient();
      final upgrader = Upgrader(
          upgraderOS: MockUpgraderOS(os: 'ios', ios: true),
          client: client,
          debugLogging: true,
          appcastConfig: fakeAppcast.config,
          appcast: fakeAppcast)
        ..installPackageInfo(
          packageInfo: PackageInfo(
            appName: 'Upgrader',
            packageName: 'com.larryaasen.upgrader',
            version: '1.9.6',
            buildNumber: '42',
          ),
        );

      await upgrader.initialize();

      expect(fakeAppcast.callCount, greaterThan(0));
    }, skip: false);

    test('will use appcast critical version if exists', () async {
      final upgraderOS = MockUpgraderOS(android: true);
      final Client mockClient =
          setupMockClient(filePath: 'test/testappcast_critical.xml');
      final appcast = Appcast(
          client: mockClient,
          upgraderOS: upgraderOS,
          upgraderDevice: MockUpgraderDevice());

      final upgrader = Upgrader(
        upgraderOS: upgraderOS,
        debugLogging: true,
        appcastConfig: AppcastConfiguration(
          url: 'https://sparkle-project.org/test/testappcast.xml',
        ),
        appcast: appcast,
      )..installPackageInfo(
          packageInfo: PackageInfo(
            appName: 'Upgrader',
            packageName: 'com.larryaasen.upgrader',
            version: '1.9.6',
            buildNumber: '42',
          ),
        );

      await upgrader.initialize();

      var notCalled = true;
      upgrader.willDisplayUpgrade = (
          {required bool display,
          String? minAppVersion,
          String? installedVersion,
          String? appStoreVersion}) {
        expect(display, true);
        expect(installedVersion, '1.9.6');

        /// Appcast Test critical version.
        expect(appStoreVersion, '3.0.0');
        notCalled = false;
      };

      final shouldDisplayUpgrade = upgrader.shouldDisplayUpgrade();

      expect(shouldDisplayUpgrade, isTrue);
      expect(notCalled, false);
    }, skip: false);

    test('will use appcast last item', () async {
      final upgraderOS = MockUpgraderOS(ios: true);

      final Client mockClient =
          setupMockClient(filePath: 'test/testappcastmulti.xml');
      final appcast = Appcast(
          client: mockClient,
          upgraderOS: upgraderOS,
          upgraderDevice: MockUpgraderDevice());

      final upgrader = Upgrader(
        upgraderOS: upgraderOS,
        debugLogging: true,
        appcastConfig: AppcastConfiguration(
          url: 'https://sparkle-project.org/test/testappcast.xml',
        ),
        appcast: appcast,
      )..installPackageInfo(
          packageInfo: PackageInfo(
            appName: 'Upgrader',
            packageName: 'com.larryaasen.upgrader',
            version: '1.9.6',
            buildNumber: '42',
          ),
        );

      await upgrader.initialize();

      var notCalled = true;
      upgrader.willDisplayUpgrade = (
          {required bool display,
          String? minAppVersion,
          String? installedVersion,
          String? appStoreVersion}) {
        expect(display, true);
        expect(installedVersion, '1.9.6');
        expect(appStoreVersion, '2.3.2');
        notCalled = false;
      };

      final shouldDisplayUpgrade = upgrader.shouldDisplayUpgrade();

      expect(shouldDisplayUpgrade, isTrue);
      expect(notCalled, false);
    }, skip: false);

    test('durationUntilAlertAgain defaults to 3 days', () async {
      final upgrader = Upgrader();
      expect(upgrader.durationUntilAlertAgain, const Duration(days: 3));
    }, skip: false);

    test('durationUntilAlertAgain is 0 days', () async {
      final upgrader =
          Upgrader(durationUntilAlertAgain: const Duration(seconds: 0));
      expect(upgrader.durationUntilAlertAgain, const Duration(seconds: 0));

      UpgradeAlert(upgrader: upgrader);
      expect(upgrader.durationUntilAlertAgain, const Duration(seconds: 0));

      UpgradeCard(upgrader: upgrader);
      expect(upgrader.durationUntilAlertAgain, const Duration(seconds: 0));
    }, skip: false);

    test('durationUntilAlertAgain card is valid', () async {
      final upgrader =
          Upgrader(durationUntilAlertAgain: const Duration(days: 3));
      UpgradeCard(upgrader: upgrader);
      expect(upgrader.durationUntilAlertAgain, const Duration(days: 3));

      final upgrader2 =
          Upgrader(durationUntilAlertAgain: const Duration(days: 10));
      UpgradeCard(upgrader: upgrader2);
      expect(upgrader2.durationUntilAlertAgain, const Duration(days: 10));
    }, skip: false);

    test('durationUntilAlertAgain alert is valid', () async {
      final upgrader =
          Upgrader(durationUntilAlertAgain: const Duration(days: 3));
      UpgradeAlert(upgrader: upgrader);
      expect(upgrader.durationUntilAlertAgain, const Duration(days: 3));

      final upgrader2 =
          Upgrader(durationUntilAlertAgain: const Duration(days: 10));
      UpgradeAlert(upgrader: upgrader2);
      expect(upgrader2.durationUntilAlertAgain, const Duration(days: 10));
    }, skip: false);
  });

  group('shouldDisplayUpgrade', () {
    test('should respect debugDisplayAlways property', () {
      final client = MockITunesSearchClient.setupMockClient();
      final upgrader = Upgrader(
          upgraderOS: MockUpgraderOS(ios: true),
          client: client,
          debugLogging: true);

      expect(upgrader.shouldDisplayUpgrade(), false);
      upgrader.debugDisplayAlways = true;
      expect(upgrader.shouldDisplayUpgrade(), true);
      upgrader.debugDisplayAlways = false;
      expect(upgrader.shouldDisplayUpgrade(), false);

      // Test the willDisplayUpgrade callback
      var notCalled = true;
      upgrader.willDisplayUpgrade = (
          {required bool display,
          String? minAppVersion,
          String? installedVersion,
          String? appStoreVersion}) {
        expect(display, false);
        expect(minAppVersion, isNull);
        expect(installedVersion, isNull);
        expect(appStoreVersion, isNull);
        notCalled = false;
      };
      expect(upgrader.shouldDisplayUpgrade(), false);
      expect(notCalled, false);

      upgrader.debugDisplayAlways = true;
      notCalled = true;
      upgrader.willDisplayUpgrade = (
          {required bool display,
          String? minAppVersion,
          String? installedVersion,
          String? appStoreVersion}) {
        expect(display, true);
        expect(minAppVersion, isNull);
        expect(installedVersion, isNull);
        expect(appStoreVersion, isNull);
        notCalled = false;
      };
      expect(upgrader.shouldDisplayUpgrade(), true);
      expect(notCalled, false);
    }, skip: false);

    test('should return true when version is below minAppVersion', () async {
      final upgrader = Upgrader(
          debugLogging: true,
          upgraderOS: MockUpgraderOS(ios: true),
          client: MockITunesSearchClient.setupMockClient())
        ..minAppVersion = '2.0.0'
        ..installPackageInfo(
          packageInfo: PackageInfo(
            appName: 'Upgrader',
            packageName: 'com.larryaasen.upgrader',
            version: '1.9.6',
            buildNumber: '42',
          ),
        );

      await upgrader.initialize();
      var notCalled = true;
      upgrader.willDisplayUpgrade = (
          {required bool display,
          String? minAppVersion,
          String? installedVersion,
          String? appStoreVersion}) {
        expect(display, true);
        expect(minAppVersion, '2.0.0');
        expect(upgrader.minAppVersion, '2.0.0');
        expect(installedVersion, '1.9.6');
        expect(appStoreVersion, '5.6');
        notCalled = false;
      };

      final shouldDisplayUpgrade = upgrader.shouldDisplayUpgrade();

      expect(shouldDisplayUpgrade, isTrue);
      expect(notCalled, false);
    }, skip: false);

    test('should return true when bestItem has critical update', () async {
      final upgrader = Upgrader(
          debugLogging: true,
          upgraderOS: MockUpgraderOS(ios: true),
          client: MockITunesSearchClient.setupMockClient())
        ..installPackageInfo(
          packageInfo: PackageInfo(
            appName: 'Upgrader',
            packageName: 'com.larryaasen.upgrader',
            version: '2.0.0',
            buildNumber: '42',
          ),
        );

      await upgrader.initialize();

      final shouldDisplayUpgrade = upgrader.shouldDisplayUpgrade();

      expect(shouldDisplayUpgrade, isTrue);
    }, skip: false);

    test('packageInfo is empty', () async {
      final upgrader = Upgrader(
          client: MockITunesSearchClient.setupMockClient(),
          upgraderOS: MockUpgraderOS(ios: true),
          debugLogging: true)
        ..installPackageInfo(
          packageInfo: PackageInfo(
            appName: '',
            packageName: '',
            version: '',
            buildNumber: '',
          ),
        );

      await upgrader.initialize();
      expect(upgrader.shouldDisplayUpgrade(), isFalse);
      expect(upgrader.appName(), isEmpty);
      expect(upgrader.currentInstalledVersion(), isEmpty);
    }, skip: false);
  });

  test('test UpgraderMessages', () {
    verifyMessages(UpgraderMessages(code: 'en'), 'en');
    verifyMessages(UpgraderMessages(code: 'ar'), 'ar');
    verifyMessages(UpgraderMessages(code: 'bn'), 'bn');
    verifyMessages(UpgraderMessages(code: 'da'), 'da');
    verifyMessages(UpgraderMessages(code: 'es'), 'es');
    verifyMessages(UpgraderMessages(code: 'fa'), 'fa');
    verifyMessages(UpgraderMessages(code: 'fil'), 'fil');
    verifyMessages(UpgraderMessages(code: 'fr'), 'fr');
    verifyMessages(UpgraderMessages(code: 'de'), 'de');
    verifyMessages(UpgraderMessages(code: 'el'), 'el');
    verifyMessages(UpgraderMessages(code: 'he'), 'he');
    verifyMessages(UpgraderMessages(code: 'hi'), 'hi');
    verifyMessages(UpgraderMessages(code: 'ht'), 'ht');
    verifyMessages(UpgraderMessages(code: 'hu'), 'hu');
    verifyMessages(UpgraderMessages(code: 'id'), 'id');
    verifyMessages(UpgraderMessages(code: 'it'), 'it');
    verifyMessages(UpgraderMessages(code: 'ja'), 'ja');
    verifyMessages(UpgraderMessages(code: 'kk'), 'kk');
    verifyMessages(UpgraderMessages(code: 'km'), 'km');
    verifyMessages(UpgraderMessages(code: 'ko'), 'ko');
    verifyMessages(UpgraderMessages(code: 'lt'), 'lt');
    verifyMessages(UpgraderMessages(code: 'mn'), 'mn');
    verifyMessages(UpgraderMessages(code: 'nb'), 'nb');
    verifyMessages(UpgraderMessages(code: 'nl'), 'nl');
    verifyMessages(UpgraderMessages(code: 'pt'), 'pt');
    verifyMessages(UpgraderMessages(code: 'pl'), 'pl');
    verifyMessages(UpgraderMessages(code: 'ru'), 'ru');
    verifyMessages(UpgraderMessages(code: 'sv'), 'sv');
    verifyMessages(UpgraderMessages(code: 'ta'), 'ta');
    verifyMessages(UpgraderMessages(code: 'te'), 'te');
    verifyMessages(UpgraderMessages(code: 'tr'), 'tr');
    verifyMessages(UpgraderMessages(code: 'uk'), 'uk');
    verifyMessages(UpgraderMessages(code: 'vi'), 'vi');
    verifyMessages(UpgraderMessages(code: 'zh'), 'zh');
  }, skip: false);
}

void verifyMessages(UpgraderMessages messages, String code) {
  expect(messages.languageCode, code);
  expect(messages.message(UpgraderMessage.body), isNotEmpty);
  expect(messages.message(UpgraderMessage.buttonTitleIgnore), isNotEmpty);
  expect(messages.message(UpgraderMessage.buttonTitleLater), isNotEmpty);
  expect(messages.message(UpgraderMessage.buttonTitleUpdate), isNotEmpty);
  expect(messages.message(UpgraderMessage.prompt), isNotEmpty);
  expect(messages.message(UpgraderMessage.releaseNotes), isNotEmpty);
  expect(messages.message(UpgraderMessage.title), isNotEmpty);
}

class MyUpgraderMessages extends UpgraderMessages {
  @override
  String get buttonTitleIgnore => 'aaa';

  @override
  String get buttonTitleLater => 'bbb';

  @override
  String get buttonTitleUpdate => 'ccc';

  @override
  String get releaseNotes => 'ddd';
}

Widget wrapper(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: child,
      appBar: AppBar(title: const Text('Upgrader test')),
    ),
  );
}
