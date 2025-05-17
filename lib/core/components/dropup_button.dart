import 'package:flutter/material.dart';

/// A button that shows a popup menu above the button (dropup) when tapped.
class DropupButton<T> extends StatelessWidget {
  /// The button's child widget
  final Widget child;
  
  /// The items to show in the dropup menu
  final List<PopupMenuEntry<T>> items;
  
  /// Called when an item in the menu is selected
  final Function(T?)? onSelected;
  
  /// The button style
  final ButtonStyle? style;
  
  /// Optional constraints for the menu
  final BoxConstraints? menuConstraints;
  
  /// The amount of vertical offset to apply to the menu (negative moves up, positive moves down)
  final double verticalOffset;
  
  /// The elevation of the menu
  final double elevation;
  
  /// Custom shape for the menu
  final ShapeBorder? menuShape;
  
  /// Background color of the menu
  final Color? menuColor;

  const DropupButton({
    Key? key,
    required this.child,
    required this.items,
    this.onSelected,
    this.style,
    this.menuConstraints,
    this.verticalOffset = -0.0,
    this.elevation = 8.0,
    this.menuShape,
    this.menuColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => _showDropupMenu(context),
      style: style,
      child: child,
    );
  }

  void _showDropupMenu(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final Offset offset = button.localToGlobal(Offset.zero, ancestor: overlay);
    
    final width = button.size.width;
    // Extract padding value safely from style
    final edgeInsetsHeight = style?.padding != null 
        ? (style!.padding!.resolve({})?.vertical ?? 0.0) 
        : 0.0;

    double itemsHeightOffset = 0;
    for (var item in items) {
      itemsHeightOffset -= item.height;
      debugPrint('item height: ${item.height}');
    }

    debugPrint('edgeInsetsHeight: $edgeInsetsHeight');
    itemsHeightOffset -= (edgeInsetsHeight);
    debugPrint('itemsHeightOffset: $itemsHeightOffset');
    
    // Position directly above the button with the same width
    showMenu<T>(
      context: context,
      useRootNavigator: true, // Important for bottom sheets
      position: RelativeRect.fromLTRB(
        offset.dx, // Left aligned with button
        offset.dy + verticalOffset + itemsHeightOffset, // Above button with offset
        offset.dx + width, // Right aligned with button
        offset.dy, // Bottom of menu at top of button
      ),
      elevation: elevation,
      shape: menuShape ?? RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: menuColor ?? Colors.white,
      // Force the menu width to match the button width exactly
      constraints: menuConstraints ?? BoxConstraints(
        minWidth: width,
        maxWidth: width,
      ),
      items: items,
    ).then((T? value) {
      if (onSelected != null && value != null) {
        onSelected!(value);
      }
    });
  }
}
