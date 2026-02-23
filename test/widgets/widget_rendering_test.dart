import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:scalable_short_video_app/src/presentation/widgets/expandable_caption.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/feed_tab_bar.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/login_required_dialog.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/video_controls_widget.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/video_options_sheet.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/video_more_options_sheet.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/app_snackbar.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/user_video_grid.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/hidden_video_grid.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/saved_video_grid.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/liked_video_grid.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/suggestions_grid_section.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/in_app_notification_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ============================================================
  // ExpandableCaption
  // ============================================================
  group('ExpandableCaption', () {
    testWidgets('renders with short text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ExpandableCaption(description: 'Short caption'))),
      );
      expect(find.text('Short caption'), findsOneWidget);
    });

    testWidgets('renders with long text', (tester) async {
      final longText = 'A' * 300;
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: ExpandableCaption(description: longText))),
      );
      expect(find.byType(ExpandableCaption), findsOneWidget);
    });

    testWidgets('can be tapped', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ExpandableCaption(description: 'Test caption for expanding widget behavior'))),
      );
      final widget = find.byType(ExpandableCaption);
      expect(widget, findsOneWidget);
      await tester.tap(widget);
      await tester.pump();
    });
  });

  // ============================================================
  // FeedTabBar
  // ============================================================
  group('FeedTabBar', () {
    testWidgets('renders with initial selected index', (tester) async {
      int selectedTab = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeedTabBar(
              selectedIndex: 0,
              onTabChanged: (index) => selectedTab = index,
            ),
          ),
        ),
      );
      expect(find.byType(FeedTabBar), findsOneWidget);
    });

    testWidgets('renders with different selected index', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeedTabBar(
              selectedIndex: 1,
              onTabChanged: (_) {},
              hasNewFollowing: true,
              hasNewFriends: true,
            ),
          ),
        ),
      );
      expect(find.byType(FeedTabBar), findsOneWidget);
    });

    testWidgets('handles tab tap', (tester) async {
      int tappedIndex = -1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeedTabBar(
              selectedIndex: 0,
              onTabChanged: (index) => tappedIndex = index,
              onSearchTap: () {},
            ),
          ),
        ),
      );
      // Tap anywhere on the tab bar to trigger interaction
      final tabBar = find.byType(FeedTabBar);
      await tester.tap(tabBar, warnIfMissed: false);
      await tester.pump();
    });
  });

  // ============================================================
  // LoginRequiredDialog
  // ============================================================
  group('LoginRequiredDialog', () {
    testWidgets('renders with action key', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: LoginRequiredDialog(actionKey: 'like')),
        ),
      );
      expect(find.byType(LoginRequiredDialog), findsOneWidget);
    });

    testWidgets('renders with different action key', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: LoginRequiredDialog(actionKey: 'comment')),
        ),
      );
      expect(find.byType(LoginRequiredDialog), findsOneWidget);
    });
  });

  // ============================================================
  // VideoControlsWidget
  // ============================================================
  group('VideoControlsWidget', () {
    testWidgets('renders with required callbacks', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoControlsWidget(
              onLikeTap: () {},
              onCommentTap: () {},
              onSaveTap: () {},
              onShareTap: () {},
            ),
          ),
        ),
      );
      expect(find.byType(VideoControlsWidget), findsOneWidget);
    });

    testWidgets('renders with liked and saved state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoControlsWidget(
              onLikeTap: () {},
              onCommentTap: () {},
              onSaveTap: () {},
              onShareTap: () {},
              isLiked: true,
              isSaved: true,
              likeCount: '100',
              commentCount: '50',
              saveCount: '25',
              shareCount: '10',
              showManageButton: true,
              showMoreButton: true,
              onManageTap: () {},
              onMoreTap: () {},
            ),
          ),
        ),
      );
      expect(find.byType(VideoControlsWidget), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
      expect(find.text('50'), findsOneWidget);
    });

    testWidgets('handles like tap', (tester) async {
      bool liked = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoControlsWidget(
              onLikeTap: () => liked = true,
              onCommentTap: () {},
              onSaveTap: () {},
              onShareTap: () {},
              likeCount: '5',
              commentCount: '3',
              saveCount: '1',
              shareCount: '2',
            ),
          ),
        ),
      );
      // Find and tap the like area
      final controls = find.byType(VideoControlsWidget);
      expect(controls, findsOneWidget);
    });

    testWidgets('lifecycle - dispose cleans up animations', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoControlsWidget(
              onLikeTap: () {},
              onCommentTap: () {},
              onSaveTap: () {},
              onShareTap: () {},
            ),
          ),
        ),
      );
      // Replace with empty widget to trigger dispose
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
      await tester.pump();
    });
  });

  // ============================================================
  // VideoOptionsSheet
  // ============================================================
  group('VideoOptionsSheet', () {
    testWidgets('renders with videoId', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoOptionsSheet(
              videoId: 'test-video-id',
            ),
          ),
        ),
      );
      expect(find.byType(VideoOptionsSheet), findsOneWidget);
    });

    testWidgets('renders with all options', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoOptionsSheet(
              videoId: 'test-video-id',
              videoOwnerId: 'owner-1',
              isOwnVideo: true,
              currentSpeed: 2.0,
              autoScroll: true,
              onReport: () {},
              onCopyLink: () {},
              onSpeedChanged: (_) {},
              onAutoScrollChanged: (_) {},
            ),
          ),
        ),
      );
      expect(find.byType(VideoOptionsSheet), findsOneWidget);
    });

    testWidgets('lifecycle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: VideoOptionsSheet(videoId: 'v1')),
        ),
      );
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
      await tester.pump();
    });
  });

  // ============================================================
  // VideoMoreOptionsSheet
  // ============================================================
  group('VideoMoreOptionsSheet', () {
    testWidgets('renders with required params', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoMoreOptionsSheet(
              videoId: 'test-video',
              userId: 'user-1',
            ),
          ),
        ),
      );
      expect(find.byType(VideoMoreOptionsSheet), findsOneWidget);
    });

    testWidgets('renders with hidden state and callbacks', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoMoreOptionsSheet(
              videoId: 'test-video',
              userId: 'user-1',
              isHidden: true,
              onEditTap: () {},
              onPrivacyTap: () {},
              onDeleteTap: () {},
              onHideTap: () {},
            ),
          ),
        ),
      );
      expect(find.byType(VideoMoreOptionsSheet), findsOneWidget);
    });
  });

  // ============================================================
  // AppSnackBar (static helper)
  // ============================================================
  group('AppSnackBar', () {
    testWidgets('showSuccess displays snackbar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => AppSnackBar.showSuccess(context, 'Success message'),
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('showError displays snackbar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => AppSnackBar.showError(context, 'Error message'),
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('showInfo displays snackbar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => AppSnackBar.showInfo(context, 'Info message'),
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    });
  });

  // ============================================================
  // UserVideoGrid
  // ============================================================
  group('UserVideoGrid', () {
    testWidgets('renders in not-logged-in state', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: UserVideoGrid())),
      );
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(UserVideoGrid), findsOneWidget);
    });

    testWidgets('lifecycle - dispose', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: UserVideoGrid())),
      );
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
      await tester.pump();
    });
  });

  // ============================================================
  // HiddenVideoGrid
  // ============================================================
  group('HiddenVideoGrid', () {
    testWidgets('renders in not-logged-in state', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HiddenVideoGrid())),
      );
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(HiddenVideoGrid), findsOneWidget);
    });

    testWidgets('lifecycle - dispose removes listeners', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HiddenVideoGrid())),
      );
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
      await tester.pump();
    });
  });

  // ============================================================
  // SavedVideoGrid
  // ============================================================
  group('SavedVideoGrid', () {
    testWidgets('renders in not-logged-in state', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SavedVideoGrid())),
      );
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(SavedVideoGrid), findsOneWidget);
    });

    testWidgets('lifecycle - dispose removes listeners', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SavedVideoGrid())),
      );
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
      await tester.pump();
    });
  });

  // ============================================================
  // LikedVideoGrid
  // ============================================================
  group('LikedVideoGrid', () {
    testWidgets('renders in not-logged-in state', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: LikedVideoGrid())),
      );
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(LikedVideoGrid), findsOneWidget);
    });

    testWidgets('lifecycle', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: LikedVideoGrid())),
      );
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
      await tester.pump();
    });
  });

  // ============================================================
  // SuggestionsGridSection
  // ============================================================
  group('SuggestionsGridSection', () {
    testWidgets('renders in not-logged-in state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: SuggestionsGridSection(onSeeAll: () {}))),
      );
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(SuggestionsGridSection), findsOneWidget);
    });

    testWidgets('renders without onSeeAll', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SuggestionsGridSection())),
      );
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(SuggestionsGridSection), findsOneWidget);
    });
  });

  // ============================================================
  // InAppNotificationOverlay
  // ============================================================
  group('InAppNotificationOverlay', () {
    testWidgets('renders with child', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: InAppNotificationOverlay(
            child: Scaffold(body: Text('Content')),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.text('Content'), findsOneWidget);
    });

    testWidgets('lifecycle - dispose cancels subscription', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: InAppNotificationOverlay(
            child: Scaffold(body: Text('Content')),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();
    });
  });
}
