---
name: mobile-clean-architecture-resilience
description: Definitive rules for Flutter & Mobile Clean Architecture. Eradicates 'No Overlay' exceptions, ensures 2-column landscape responsiveness on mobile, enforces strict <200 lines per file modularity, eliminates zombie processes/controllers, and guarantees didactic comments on all functions.
---

# Mobile Clean Architecture & Visual Resilience Standard

This skill establishes mandatory architectural standards for Flutter mobile applications, preventing recurring UI crashes, broken landscape layouts, and unmaintainable code.

---

## 1. Zero 'No Overlay' Guarantee (Eradication Pattern)

### Root Cause
Widgets that render floating layers (`showModalBottomSheet`, `showDatePicker`, `Tooltip`, text selection magnifiers, and `Slider` value indicators) invoke `Overlay.of(context)`. In multi-branch navigators (e.g. `StatefulShellRoute` in GoRouter), nested routes may lack an accessible `OverlayState`, resulting in the red box with yellow text:
`No Overlay widget found. Some widgets require an Overlay widget to display...`

### The Solution: Master Screen Wrapper
Every screen in a sub-branch or standalone route must wrap its tree in a transparent `Material` and local `Overlay`:

```dart
@override
Widget build(BuildContext context) {
  return Material(
    type: MaterialType.transparency,
    child: Overlay(
      initialEntries: [
        OverlayEntry(
          builder: (context) => Scaffold(
            // Entire screen content here
          ),
        ),
      ],
    ),
  );
}
```

### Slider Overlay Immunity
Never allow standard `Slider` widgets to render default floating tooltips inside dense trees. Use `showValueIndicator: ShowValueIndicator.never` and present the value in the header row with tabular figures:
```dart
SliderTheme(
  data: SliderTheme.of(context).copyWith(
    showValueIndicator: ShowValueIndicator.never,
  ),
  child: Slider(...),
)
```

---

## 2. Adaptive Landscape (Horizontal) Design Standard

Mobile screens in landscape possess high width ($750 \sim 950\text{dp}$) but severely restricted vertical height ($340 \sim 420\text{dp}$). Never display a single-column stretched vertical list in landscape.

### The 2-Column Split Pattern
```dart
OrientationBuilder(
  builder: (context, orientation) {
    final isLandscape = orientation == Orientation.landscape;

    if (isLandscape) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Column (35-40% width): Header, Avatar, Primary Action Button
          SizedBox(
            width: 280,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                headerWidget,
                const SizedBox(height: 16),
                primaryActionButton,
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          // Right Column (Expanded): Detailed fields, cards, sliders
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              children: contentFields,
            ),
          ),
        ],
      );
    }

    // Portrait: Standard continuous column
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      children: [headerWidget, ...contentFields, primaryActionButton],
    );
  },
)
```

---

## 3. Strict File Size Limit (< 200 Lines)

1. **Hard Limit**: No file may exceed 200 lines of code.
2. **Decomposition Strategy**:
   - Screen file: Only coordinates layout, providers, and orientation routing ($100 \sim 150$ lines).
   - Header widget: Extracted to its own file ($60 \sim 100$ lines).
   - Form fields: Grouped into logical cards ($80 \sim 140$ lines each).
   - Sliders and custom controls: Dedicated reusable widgets ($70 \sim 110$ lines).

---

## 4. Lifecycle Discipline (Zero Zombie Controllers)

1. Any `TextEditingController`, `ScrollController`, `AnimationController`, or `FocusNode` initialized in `initState` **MUST** be explicitly disposed in `dispose()`.
2. Never instantiate stateful controllers inside the `build()` method.

---

## 5. Mandatory Code Documentation Header

Every class and significant function must be preceded by this standardized didactic block:
```dart
/// QUÉ HACE:
/// Explicación concisa del propósito del componente.
///
/// CÓMO FUNCIONA:
/// Descripción técnica de entradas, flujos y eventos.
///
/// POR QUÉ:
/// Justificación de arquitectura y decisiones de diseño.
```
