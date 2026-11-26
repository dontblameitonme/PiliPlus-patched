import 'package:PiliPlus/common/skeleton/skeleton.dart';
import 'package:PiliPlus/common/widgets/defer_until_route_settled.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/memoized_scroll_item.dart';
import 'package:PiliPlus/models/common/dynamic/dynamics_type.dart';
import 'package:PiliPlus/models/dynamics/result.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

DynamicsDataModel _parseDynamicsInIsolate(
  (Map<String, dynamic>, DynParseConfig) args,
) {
  return DynamicsDataModel.fromJson(
    args.$1,
    type: DynamicsTabType.all,
    parseConfig: args.$2,
  );
}

void main() {
  group('PushTransitionGate', () {
    test('completes immediately when animation is null or completed', () async {
      final gate1 = PushTransitionGate()..attach(null);
      expect(gate1.isSettled, isTrue);
      await gate1.waitSettled();
      gate1.dispose();

      final gate2 = PushTransitionGate()..attach(kAlwaysCompleteAnimation);
      expect(gate2.isSettled, isTrue);
      await gate2.waitSettled();
      gate2.dispose();
    });

    testWidgets('waits while forward and wakes on completion or dispose', (
      tester,
    ) async {
      final controller = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 250),
      );

      final gate = PushTransitionGate();
      controller.forward();
      gate.attach(controller);
      expect(gate.isSettled, isFalse);

      var resolved = false;
      final waitFuture = gate.waitSettled().then((_) => resolved = true);
      await tester.pump(const Duration(milliseconds: 100));
      expect(resolved, isFalse);

      await tester.pumpAndSettle();
      await waitFuture;
      expect(resolved, isTrue);
      expect(gate.isSettled, isTrue);
      gate.dispose();
      controller.dispose();

      final pendingController = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 250),
      );
      final gateOnPop = PushTransitionGate();
      pendingController.forward();
      gateOnPop.attach(pendingController);
      var popWoke = false;
      final popFuture = gateOnPop.waitSettled().then((_) => popWoke = true);
      gateOnPop.dispose();
      await popFuture;
      expect(popWoke, isTrue);
      pendingController.dispose();
    });

    testWidgets('handles HeroController frame-1 offstage proxy transition', (
      tester,
    ) async {
      final controller = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 250),
      );
      final proxy = ProxyAnimation(kAlwaysCompleteAnimation);
      final gate = PushTransitionGate();

      controller.forward();
      gate.attach(proxy, offstage: true);
      expect(gate.isSettled, isFalse);

      // Simulated HeroController post-frame restoration of real route animation.
      proxy.parent = controller;
      await tester.pump(const Duration(milliseconds: 80));
      expect(gate.isSettled, isFalse);

      await tester.pumpAndSettle();
      expect(gate.isSettled, isTrue);

      gate.dispose();
      controller.dispose();
    });

    testWidgets('failsafe timer settles gate if animation stalls', (
      tester,
    ) async {
      final controller = AnimationController(
        vsync: tester,
        duration: const Duration(seconds: 5),
      );

      final gate = PushTransitionGate();
      controller.forward();
      gate.attach(controller);
      expect(gate.isSettled, isFalse);

      await tester.pump(const Duration(milliseconds: 500));
      expect(gate.isSettled, isTrue);
      gate.dispose();
      controller.dispose();
    });
  });

  group('DeferUntilRouteSettled', () {
    testWidgets('shows placeholder during route transition then builds child', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  PageRouteBuilder(
                    transitionDuration: const Duration(milliseconds: 300),
                    pageBuilder: (_, _, _) => Material(
                      child: DeferUntilRouteSettled(
                        placeholder: const Text('placeholder'),
                        builder: (_) => const Text('settled-body'),
                      ),
                    ),
                  ),
                ),
                child: const Text('push'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('push'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.text('placeholder'), findsOneWidget);
      expect(find.text('settled-body'), findsNothing);

      await tester.pumpAndSettle();
      expect(find.text('settled-body'), findsOneWidget);
      expect(find.text('placeholder'), findsNothing);
    });
  });

  group('MemoizedScrollItem', () {
    testWidgets(
      'skips rebuild on append refresh, rebuilds on revision/data/theme change',
      (tester) async {
        var buildCount = 0;
        var childBrightnessBuildCount = 0;
        const data = 'item-1';
        var revision = 0;
        var darkMode = false;
        Brightness? observedBrightness;
        late StateSetter outerSetState;

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              outerSetState = setState;
              return MaterialApp(
                theme: darkMode ? ThemeData.dark() : ThemeData.light(),
                home: MemoizedScrollItem(
                  data: data,
                  revision: revision,
                  builder: (_) {
                    buildCount++;
                    return Builder(
                      builder: (innerCtx) {
                        childBrightnessBuildCount++;
                        observedBrightness = Theme.of(innerCtx).brightness;
                        return Text('$data:$revision');
                      },
                    );
                  },
                ),
              );
            },
          ),
        );

        expect(buildCount, 1);
        expect(observedBrightness, Brightness.light);

        // Parent rebuilds with unchanged data & revision (appending next page).
        outerSetState(() {});
        await tester.pump();
        expect(buildCount, 1);

        // Mutation bumps revision.
        outerSetState(() => revision = 1);
        await tester.pump();
        expect(buildCount, 2);

        // Theme switch triggers didChangeDependencies invalidation even when
        // Theme.of is only read by a nested descendant widget.
        outerSetState(() => darkMode = true);
        await tester.pumpAndSettle();
        expect(buildCount, greaterThanOrEqualTo(3));
        expect(childBrightnessBuildCount, greaterThanOrEqualTo(3));
        expect(observedBrightness, Brightness.dark);
      },
    );
  });

  group('Skeleton & NetworkImgLayer', () {
    testWidgets('Skeleton has no ShaderMask or animations', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Skeleton(child: Text('static-skeleton')),
        ),
      );
      expect(find.text('static-skeleton'), findsOneWidget);
      expect(find.byType(ShaderMask), findsNothing);
      expect(find.byType(AnimatedBuilder), findsNothing);
    });

    testWidgets('NetworkImgLayer defaults to zero fade durations and solid box', (
      tester,
    ) async {
      const layer = NetworkImgLayer(
        src: null,
        width: 160,
        height: 100,
      );
      expect(layer.fadeInDuration, Duration.zero);
      expect(layer.fadeOutDuration, Duration.zero);

      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: layer)));
      expect(find.byType(ColoredBox), findsWidgets);
    });
  });

  test(
    'DynamicsDataModel.fromJson with DynParseConfig runs cleanly in compute',
    () async {
      final json = <String, dynamic>{
        'has_more': true,
        'offset': '123',
        'total': 10,
        'items': [
          {
            'id_str': '1001',
            'type': 'DYNAMIC_TYPE_WORD',
            'visible': true,
            'modules': {
              'module_author': {
                'mid': 42,
                'name': 'tester',
                'face': 'https://example.com/a.jpg',
                'decorate': {'card_url': 'https://example.com/c.png'},
              },
              'module_dynamic': {
                'desc': {'text': 'hello isolate'},
              },
            },
          },
          {
            'id_str': '1002',
            'type': 'DYNAMIC_TYPE_WORD',
            'visible': true,
            'modules': {
              'module_dynamic': {
                'desc': {'text': 'blocked keyword'},
                'additional': {'type': 'ADDITIONAL_TYPE_GOODS'},
              },
            },
          },
        ],
      };

      const config = (
        banWordPattern: 'blocked',
        antiGoodsDyn: true,
        showDynDispute: true,
        showDynInteraction: true,
        showDecorate: true,
      );

      final parsed = await compute(_parseDynamicsInIsolate, (json, config));
      expect(parsed.hasMore, isTrue);
      expect(parsed.offset, '123');
      expect(parsed.items?.length, 1);
      expect(parsed.items!.single.idStr, '1001');
      expect(parsed.items!.single.modules.moduleAuthor?.decorate, isNotNull);
    },
  );
}
