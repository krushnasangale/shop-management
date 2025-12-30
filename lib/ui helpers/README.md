# UI Helpers - App Text Styles

## Overview
The `app_text_styles.dart` file provides a centralized extension on `BuildContext` for consistent text styling across the entire FlashBill application. This eliminates the need to extract theme colors in individual widgets and ensures all text styles automatically adapt to theme changes.

## Benefits

✅ **Single Source of Truth**: All text colors are defined in `theme_provider.dart`  
✅ **Automatic Theme Support**: Text colors automatically change with light/dark mode  
✅ **Cleaner Code**: No need to extract `primaryTextColor` and `secondaryTextColor` variables  
✅ **Type Safety**: All styles are strongly typed with proper null safety  
✅ **Consistency**: Ensures uniform text styling across the entire app  
✅ **Easy Maintenance**: Update theme once, affects all pages automatically

## Usage

### Import
```dart
import 'package:flashbill/ui helpers/app_text_styles.dart';
```

### Before (Old Way ❌)
```dart
@override
Widget build(BuildContext context) {
  final primaryTextColor = Theme.of(context).textTheme.bodyLarge?.color;
  final secondaryTextColor = Theme.of(context).textTheme.bodyMedium?.color;

  return Text(
    'Hello World',
    style: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: primaryTextColor,
    ),
  );
}
```

### After (New Way ✅)
```dart
@override
Widget build(BuildContext context) {
  return Text(
    'Hello World',
    style: context.headingLarge,
  );
}
```

## Available Text Styles

### Primary Text Styles (Black in Light Mode, White in Dark Mode)

| Style | Size | Weight | Usage |
|-------|------|--------|-------|
| `displayLarge` | 32px | Bold | Large display titles |
| `displayMedium` | 28px | Bold | Medium display titles |
| `headingLarge` | 24px | Bold | Page headers, main titles |
| `headingMedium` | 20px | Bold | Section headers |
| `headingSmall` | 18px | Bold | Subsection headers |
| `titleLarge` | 16px | w600 | Card titles, emphasized text |
| `titleMedium` | 14px | w600 | Small titles, labels |
| `bodyLargeText` | 16px | Normal | Main body text |
| `bodyMediumText` | 14px | Normal | Regular body text |
| `bodySmallText` | 12px | Normal | Small body text |

### Secondary Text Styles (Grey Color)

| Style | Size | Weight | Usage |
|-------|------|--------|-------|
| `subtitleLarge` | 16px | Normal | Large subtitle/description |
| `subtitleMedium` | 14px | Normal | Standard subtitle/description |
| `subtitleSmall` | 12px | Normal | Small subtitle/helper text |
| `captionLarge` | 12px | Italic | Large caption/footnote |
| `captionMedium` | 10px | Italic | Small caption/footnote |

### Direct Color Access

```dart
context.primaryTextColor      // Black (light) / White (dark)
context.secondaryTextColor    // Grey
context.primaryColor          // Theme primary color (Blue)
context.cardColor             // Card background color
context.backgroundColor       // Scaffold background color
```

## Common Patterns

### Basic Text
```dart
// Heading
Text('Welcome', style: context.headingLarge)

// Body text
Text('Description here', style: context.bodyMediumText)

// Subtitle/hint
Text('Helper text', style: context.subtitleMedium)
```

### With Customization
```dart
// Add custom properties using copyWith
Text(
  'Custom Title',
  style: context.headingMedium?.copyWith(
    color: Colors.blue,
    letterSpacing: 1.2,
  ),
)

// Height for better line spacing
Text(
  'Multi-line content that needs proper spacing',
  style: context.subtitleMedium?.copyWith(height: 1.5),
)
```

### Mixed Styles
```dart
Column(
  children: [
    Text('Title', style: context.headingLarge),
    SizedBox(height: 8),
    Text('Subtitle', style: context.subtitleMedium),
    SizedBox(height: 16),
    Text('Body content', style: context.bodyMediumText),
  ],
)
```

### Icons with Themed Colors
```dart
Icon(
  Icons.info,
  color: context.secondaryTextColor,
  size: 16,
)
```

## Migration Guide

To migrate existing code:

1. **Add Import**
   ```dart
   import 'package:flashbill/ui helpers/app_text_styles.dart';
   ```

2. **Remove Color Variable Extraction**
   ```dart
   // Remove these lines
   final primaryTextColor = Theme.of(context).textTheme.bodyLarge?.color;
   final secondaryTextColor = Theme.of(context).textTheme.bodyMedium?.color;
   ```

3. **Replace TextStyle Declarations**
   - `TextStyle(color: primaryTextColor, fontSize: 24, fontWeight: FontWeight.bold)` 
     → `context.headingLarge`
   
   - `TextStyle(color: secondaryTextColor, fontSize: 14)` 
     → `context.subtitleMedium`
   
   - `TextStyle(color: primaryTextColor, fontSize: 16, fontWeight: FontWeight.w600)` 
     → `context.titleLarge`

## Examples from Codebase

### Privacy Policy Page
```dart
// Section title
Text(
  'Introduction',
  style: context.headingSmall,
)

// Section content
Text(
  'FlashBill is committed to protecting your privacy...',
  style: context.subtitleMedium?.copyWith(height: 1.5),
)

// Footer
Text(
  '© 2025 FlashBill. All rights reserved.',
  style: context.captionLarge,
)
```

### Bill Success Page
```dart
// Success message
Text(
  'Bill Created Successfully!',
  style: context.headingLarge,
)

// Subtitle
Text(
  'Your bill has been saved to the system',
  style: context.subtitleMedium,
)

// Status labels
Text('Status', style: context.subtitleMedium)
Text('Completed', style: context.titleMedium?.copyWith(color: Colors.green))
```

### Product List
```dart
// Product name
Text(
  productName,
  style: context.titleLarge?.copyWith(fontSize: 15),
)

// Unit info
Text(unit, style: context.subtitleSmall)

// No products message
Text(
  'No products found',
  style: context.subtitleMedium,
)
```

## Best Practices

1. **Use Semantic Names**: Choose the style that matches the semantic purpose, not just the size
2. **Customize Sparingly**: Use `copyWith()` only when necessary; prefer the predefined styles
3. **Consistent Hierarchy**: Maintain visual hierarchy (display > heading > title > body > caption)
4. **Theme First**: Always rely on theme colors; avoid hardcoded colors except for special cases
5. **Null Safety**: Use `?.` when chaining with `copyWith()` as styles are nullable

## Theme Configuration

The colors are defined in `lib/providers/theme_provider.dart`:

```dart
textTheme: const TextTheme(
  bodyLarge: TextStyle(color: Colors.black),   // Light mode
  bodyMedium: TextStyle(color: Colors.grey),   // Both modes
)

// Dark mode
textTheme: const TextTheme(
  bodyLarge: TextStyle(color: Colors.white),   // Dark mode
  bodyMedium: TextStyle(color: Colors.grey),   // Both modes
)
```

## Files Updated

The following files have been migrated to use `AppTextStyles`:

- ✅ `lib/pages/profile/privacy_policy.dart`
- ✅ `lib/pages/billing/bill_success_page.dart`
- ✅ `lib/pages/products/available_products.dart`
- ✅ `lib/pages/purchase/purchase_entry_details.dart`

## Future Enhancements

Consider adding:
- Button text styles
- Input decoration styles
- Error/warning/success text styles
- Platform-specific styles (iOS vs Android)
