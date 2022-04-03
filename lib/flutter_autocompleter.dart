import 'dart:async';
import 'dart:math';

import 'package:async/async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';

class Autocompleter<T> extends StatefulWidget {
  /// A customizable autocomplete widget for text field
  const Autocompleter(
      {Key? key,
      required this.controller,
      required this.callback,
      required this.itemBuilder,
      this.emptyBuilder,
      this.loadingBuilder,
      this.errorBuilder,
      this.beforeHook,
      this.afterHook,
      this.onTap,
      this.debounce = 0,
      this.maxItems,
      this.maxHeight,
      this.decorationBuilder,
      this.padding,
      this.margin,
      this.direction = VerticalDirection.down,
      this.hideOnKeyboardDismissed = true,
      this.flip = false,
      this.clipBehavior = Clip.hardEdge,
      required this.child})
      : super(key: key);

  /// [TextEditingController] of the input field.
  final TextEditingController controller;

  /// Suggestion provider that should returns a list of [T].
  final Future<List<T>> Function(String text) callback;

  /// Widget to be shown for each item in the list returned by [callback].
  final Widget Function(BuildContext context, T item) itemBuilder;

  /// Content to be shown when the list returned by [callback] is empty.
  final Widget Function(BuildContext context)? emptyBuilder;

  /// Widget to be shown when [callback] is executing.
  final Widget Function(BuildContext context)? loadingBuilder;

  /// Widget to be shown when exception is thrown while executing [callback].
  final Widget Function(BuildContext context)? errorBuilder;

  /// The hook to be invoked right before [callback] is called.
  /// Useful for performing validation, or length check before listing suggestions.
  /// Return false to stop getting suggestion and hide the suggestion list.
  final bool Function(String text)? beforeHook;

  /// The hook to be invoked right after [callback] is called.
  /// Useful for removing exact match from the list.
  /// Return false to hide the suggestion list.
  final bool Function(List<T>)? afterHook;

  /// The action when a list item is tapped.
  final void Function(T suggestion)? onTap;

  /// Delay [callback] for specific time in milliseconds. Useful for avoid frequent calls to [callback].
  final int debounce;

  /// The maximum items to be listed.
  final int? maxItems;

  /// The maximum height of the list.
  final double? maxHeight;

  /// The appearance of the suggestion list.
  final BoxDecoration Function(VerticalDirection direction)? decorationBuilder;

  /// The padding for suggestion list.
  final EdgeInsets Function(VerticalDirection direction)? padding;

  /// The margin for suggestion list.
  final EdgeInsets Function(VerticalDirection direction)? margin;

  /// The direction of the suggestion list.
  final VerticalDirection direction;

  /// Hide the suggestion list when the keyboard is dismissed.
  final bool hideOnKeyboardDismissed;

  /// Flip to the other side when no spaces left for the current [direction].
  final bool flip;

  /// The clip behavior for the suggestion list.
  final Clip clipBehavior;

  /// Widget that the suggestion list should be attached to.
  final Widget child;

  @override
  _AutocompleterState<T> createState() => _AutocompleterState<T>();
}

class _AutocompleterState<T> extends State<Autocompleter<T>>
    with WidgetsBindingObserver {
  final GlobalKey _overlayKey = GlobalKey();
  final GlobalKey _childKey = GlobalKey();
  final LayerLink _layerLink = LayerLink();
  final FocusNode _focusNode = FocusNode();
  KeyboardVisibilityController? _keyboardVisibilityController;
  StreamSubscription<bool>? _keyboardSubscription;
  ScrollController? _scrollController;

  late OverlayEntry _overlay;

  CancelableCompleter? _completer;

  /// If [_items] is null, the list would be empty without showing emptyBuilder
  List<T>? _items = [];
  bool _error = false;
  bool _loading = true;
  bool _flipped = false;
  Size? _childSize;
  Timer? _timerDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance!.addObserver(this);
    _overlay = _overlayEntry();
    widget.controller.addListener(_handleChange);
    WidgetsBinding.instance!.addPostFrameCallback((_) {
      _updateChild();
    });
    if (widget.hideOnKeyboardDismissed) {
      _keyboardVisibilityController = KeyboardVisibilityController();
      _keyboardSubscription = _keyboardVisibilityController!.onChange
          .listen(_onKeyboardVisibilityChanged);
    }
  }

  @override
  void dispose() {
    _hideAutocompleter();
    _focusNode.dispose();
    _timerDebounce?.cancel();
    WidgetsBinding.instance!.removeObserver(this);
    widget.controller.removeListener(_handleChange);
    _scrollController?.removeListener(_flipIfOverflowed);
    _keyboardSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.flip) {
      _scrollController = Scrollable.of(context)?.widget.controller
        ?..addListener(_flipIfOverflowed);
    }
  }

  @override
  void didUpdateWidget(Autocompleter<T> oldWidget) {
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleChange);
      widget.controller.addListener(_handleChange);
    }
    if (!oldWidget.flip && widget.flip) {
      WidgetsBinding.instance?.addPostFrameCallback((_) {
        _scrollController = Scrollable.of(context)?.widget.controller
          ?..addListener(_flipIfOverflowed);
        _flipIfOverflowed();
      });
    }
    if (oldWidget.flip && !widget.flip) {
      _scrollController?.removeListener(_flipIfOverflowed);
    }
    if (oldWidget.child != widget.child) {
      WidgetsBinding.instance?.addPostFrameCallback((_) => _updateChild());
    }
    if (!oldWidget.hideOnKeyboardDismissed && widget.hideOnKeyboardDismissed) {
      _keyboardVisibilityController = KeyboardVisibilityController();
      _keyboardSubscription = _keyboardVisibilityController!.onChange
          .listen(_onKeyboardVisibilityChanged);
    }
    if (oldWidget.hideOnKeyboardDismissed && !widget.hideOnKeyboardDismissed) {
      _keyboardSubscription!.cancel();
      _keyboardSubscription = null;
      _keyboardVisibilityController = null;
    }
    if (oldWidget.beforeHook != widget.beforeHook ||
        oldWidget.afterHook != widget.afterHook) {
      WidgetsBinding.instance?.addPostFrameCallback((_) => _handleChange(true));
    }
    if (oldWidget.direction != widget.direction ||
        oldWidget.emptyBuilder != widget.emptyBuilder) {
      WidgetsBinding.instance
          ?.addPostFrameCallback((_) => _updateAutocompleter());
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void didChangeMetrics() {
    _updateChild();
    _updateAutocompleter();
  }

  void _updateChild() {
    var child = _childKey.currentContext?.findRenderObject() as RenderBox;
    _childSize = child.size;
  }

  void _onKeyboardVisibilityChanged(bool visible) {
    if (!visible && widget.hideOnKeyboardDismissed) {
      _focusNode.unfocus();
    }
  }

  void _flipIfOverflowed() {
    bool overflowed = false;
    if (widget.flip) {
      final RenderBox? child =
          _childKey.currentContext?.findRenderObject() as RenderBox?;
      if (child != null) {
        final RenderBox? overlay =
            _overlayKey.currentContext?.findRenderObject() as RenderBox?;
        if (overlay == null) return;
        double keyboardHeight = EdgeInsets.fromWindowPadding(
                WidgetsBinding.instance!.window.viewInsets,
                WidgetsBinding.instance!.window.devicePixelRatio)
            .bottom;
        double childY = child.localToGlobal(Offset.zero).dy;
        EdgeInsets unsafeArea = EdgeInsets.fromWindowPadding(
            WidgetsBinding.instance!.window.padding,
            WidgetsBinding.instance!.window.devicePixelRatio);
        double overlayHeight = overlay.size.height;
        double screenHeight =
            WidgetsBinding.instance!.window.physicalSize.height /
                WidgetsBinding.instance!.window.devicePixelRatio;
        bool bottomOverflowed = widget.direction == VerticalDirection.down &&
            childY +
                    _childSize!.height +
                    overlayHeight +
                    keyboardHeight +
                    unsafeArea.bottom >
                screenHeight;
        bool topOverflowed = widget.direction == VerticalDirection.up &&
            childY - overlayHeight - unsafeArea.top < 0;
        if (bottomOverflowed ^ topOverflowed) {
          overflowed = true;
        } else {
          overflowed = false;
        }
      }
    }
    if (overflowed) {
      if (!_flipped) {
        _overlay.markNeedsBuild();
      }
      _flipped = true;
    } else {
      if (_flipped) {
        _overlay.markNeedsBuild();
      }
      _flipped = false;
    }
  }

  void _handleChange([bool skipDebounce = false]) async {
    _error = false;
    _loading = true;
    var newValue = widget.controller.text;
    if (widget.beforeHook != null && !widget.beforeHook!(newValue)) {
      _items = null;
      _loading = false;
      _updateAutocompleter();
      return;
    }
    if (widget.loadingBuilder != null) _updateAutocompleter();
    if (widget.debounce > 0 && !skipDebounce) {
      if (_timerDebounce?.isActive ?? false) _timerDebounce?.cancel();

      _timerDebounce = Timer(Duration(milliseconds: widget.debounce), () {
        _handleChange(true);
      });
      return;
    }

    _completer?.operation.cancel();
    _completer = CancelableCompleter<List<T>>(onCancel: () {
      _loading = false;
    });
    _loading = true;
    _completer!.complete(widget.callback(newValue));
    _completer!.operation.then((items) {
      _items = items;
      if (widget.afterHook != null && !widget.afterHook!(_items!)) {
        _items = null;
        _loading = false;
        _error = false;
        _updateAutocompleter();
        return;
      }
      _loading = false;
      _updateAutocompleter();
    }, onError: (object, stackTrace) {
      _error = true;
      _updateAutocompleter();
      if (kDebugMode) {
        print(stackTrace);
      }
    });
  }

  OverlayEntry _overlayEntry() {
    return OverlayEntry(
      builder: (BuildContext context) {
        VerticalDirection direction = (_flipped
            ? (widget.direction == VerticalDirection.down
                ? VerticalDirection.up
                : VerticalDirection.down)
            : widget.direction);
        Alignment alignment =
            Alignment(0, direction == VerticalDirection.down ? 1.0 : -1.0);
        return Positioned(
          key: _overlayKey,
          width: _childSize?.width ?? 0,
          child: CompositedTransformFollower(
            link: _layerLink,
            followerAnchor: Alignment(alignment.x, alignment.y * -1),
            targetAnchor: alignment,
            child: Material(
              color: Colors.transparent,
              child: Container(
                clipBehavior: widget.clipBehavior,
                margin:
                    widget.margin != null ? widget.margin!(direction) : null,
                decoration: widget.decorationBuilder != null
                    ? widget.decorationBuilder!(direction)
                    : BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8.0),
                        boxShadow: const [
                            BoxShadow(blurRadius: 3.0, color: Colors.black12)
                          ]),
                child: _error
                    ? (widget.errorBuilder != null
                        ? widget.errorBuilder!(context)
                        : const SizedBox())
                    : (_loading && widget.loadingBuilder != null
                        ? widget.loadingBuilder!(context)
                        : (_items == null
                            ? const SizedBox()
                            : (_items!.isEmpty
                                ? (widget.emptyBuilder != null
                                    ? widget.emptyBuilder!(context)
                                    : const SizedBox())
                                : ListView.builder(
                                    shrinkWrap: true,
                                    padding: widget.padding != null
                                        ? widget.padding!(direction)
                                        : EdgeInsets.zero,
                                    itemCount: widget.maxItems != null
                                        ? min(widget.maxItems!, _items!.length)
                                        : _items!.length,
                                    itemBuilder: ((context, i) {
                                      var item = widget.itemBuilder(
                                          context, _items![i]);
                                      if (widget.onTap != null) {
                                        item = GestureDetector(
                                            behavior:
                                                HitTestBehavior.translucent,
                                            child: item,
                                            onTap: () {
                                              widget.onTap!(_items![i]);
                                              _focusNode.unfocus();
                                            });
                                      }
                                      return item;
                                    }))))),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAutocompleter() {
    if (!_overlay.mounted) Overlay.of(context)?.insert(_overlay);
  }

  void _hideAutocompleter() {
    _completer?.operation.cancel();
    if (_overlay.mounted) _overlay.remove();
  }

  void _updateAutocompleter() {
    if (!_overlay.mounted) {
      return;
    }
    _overlay.markNeedsBuild();
    WidgetsBinding.instance?.addPostFrameCallback((_) => _flipIfOverflowed());
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
        link: _layerLink,
        child: Container(
            key: _childKey,
            child: Focus(
              focusNode: _focusNode,
              onFocusChange: (focused) {
                if (focused) {
                  _showAutocompleter();
                } else {
                  _hideAutocompleter();
                }
              },
              child: widget.child,
            )));
  }
}
