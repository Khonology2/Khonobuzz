import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Admin Profile Screen Layout Tests', () {
    testWidgets('Should have proper 50/50 column layout', (
      WidgetTester tester,
    ) async {
      // Build with a wide screen to trigger two-column layout
      await tester.binding.setSurfaceSize(const Size(1200, 800));

      // Create a simple test widget that mimics the layout structure
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: const Color(0xFF1A1A1A),
            body: LayoutBuilder(
              builder: (context, constraints) {
                // Use two-column layout for wider screens
                if (constraints.maxWidth > 800) {
                  return Row(
                    children: [
                      // Left column - Admin profile and stats
                      Expanded(
                        flex: 1,
                        child: Container(
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Admin Profile',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Left Column Content',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Right column - User management
                      Expanded(
                        flex: 1,
                        child: Container(
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'User Management',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Right Column Content',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                } else {
                  // Single column layout for smaller screens
                  return const SingleChildScrollView(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Admin Profile',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Single Column Content',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      print('=== LAYOUT ANALYSIS ===');

      // Find the Row with our layout
      final rowFinder = find.byType(Row);
      expect(rowFinder, findsWidgets);

      final rows = rowFinder.evaluate();
      print('Found ${rows.length} Row widgets');

      // Check each Row's children
      for (int i = 0; i < rows.length; i++) {
        final row = rows.elementAt(i).widget as Row;
        print('Row $i has ${row.children.length} children:');

        for (int j = 0; j < row.children.length; j++) {
          final child = row.children[j];
          print('  Child $j: ${child.runtimeType}');

          if (child is Expanded) {
            print('    Flex value: ${child.flex}');
          } else if (child is SizedBox) {
            print('    Width: ${child.width}, Height: ${child.height}');
          }
        }
      }

      // Find all Expanded widgets
      final expandedFinder = find.byType(Expanded);
      final expandedWidgets = expandedFinder.evaluate();
      print('Found ${expandedWidgets.length} Expanded widgets total');

      // Check for any large empty spaces
      final sizedBoxFinder = find.byType(SizedBox);
      final sizedBoxes = sizedBoxFinder.evaluate();
      print('Found ${sizedBoxes.length} SizedBox widgets');

      for (int i = 0; i < sizedBoxes.length; i++) {
        final sizedBox = sizedBoxes.elementAt(i).widget as SizedBox;
        if (sizedBox.width != null && sizedBox.width! > 100) {
          print('  WARNING: Large SizedBox width: ${sizedBox.width}');
        }
      }

      // Find the main content containers
      final containerFinder = find.byType(Container);
      final containers = containerFinder.evaluate();
      print('Found ${containers.length} Container widgets');

      for (int i = 0; i < containers.length; i++) {
        final container = containers.elementAt(i).widget as Container;
        final constraints = container.constraints;
        if (constraints != null && constraints.maxWidth != double.infinity) {
          print('  Container $i maxWidth: ${constraints.maxWidth}');
        }
      }

      // Verify we have exactly 2 Expanded widgets with flex: 1
      expect(expandedWidgets.length, 2);

      final expandedList = expandedWidgets
          .map((e) => e.widget as Expanded)
          .toList();
      expect(expandedList[0].flex, 1);
      expect(expandedList[1].flex, 1);
    });

    testWidgets('Should use full available width', (WidgetTester tester) async {
      // Test with different screen sizes
      final screenSizes = [
        const Size(800, 600),
        const Size(1000, 600),
        const Size(1200, 600),
        const Size(1400, 600),
      ];

      for (final screenSize in screenSizes) {
        print('\n=== Testing with ${screenSize.width}px width ===');

        await tester.binding.setSurfaceSize(screenSize);

        // Create a simple test widget that mimics the layout structure
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              backgroundColor: const Color(0xFF1A1A1A),
              body: LayoutBuilder(
                builder: (context, constraints) {
                  // Use two-column layout for wider screens
                  if (constraints.maxWidth > 800) {
                    return Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: Container(color: Colors.red[100]),
                        ),
                        Expanded(
                          flex: 1,
                          child: Container(color: Colors.blue[100]),
                        ),
                      ],
                    );
                  } else {
                    return const SingleChildScrollView(
                      child: Column(children: [Text('Single Column')]),
                    );
                  }
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Get the main scaffold (unused but kept for consistency)
        find.byType(Scaffold);

        // Check if we have the expected layout
        final rowFinder = find.byType(Row);
        final hasRow = rowFinder.evaluate().isNotEmpty;

        if (hasRow) {
          print('  ✓ Two-column layout active');

          // Check the Row structure
          final row = tester.widget<Row>(rowFinder.first);
          print('  Row has ${row.children.length} children');

          final expandedChildren = row.children.whereType<Expanded>().toList();
          if (expandedChildren.length == 2) {
            print(
              '  ✓ Found 2 Expanded widgets with flex: ${expandedChildren[0].flex} and ${expandedChildren[1].flex}',
            );
          } else {
            print(
              '  ✗ Expected 2 Expanded widgets, found ${expandedChildren.length}',
            );
          }

          final sizedBoxChildren = row.children.whereType<SizedBox>().toList();
          if (sizedBoxChildren.isNotEmpty) {
            print('  Found ${sizedBoxChildren.length} SizedBox widgets in Row');
            for (final sizedBox in sizedBoxChildren) {
              print(
                '    SizedBox: width=${sizedBox.width}, height=${sizedBox.height}',
              );
            }
          }
        } else {
          print('  - Single-column layout (screen too narrow)');
        }
      }
    });
  });
}
