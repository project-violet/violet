import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';

class _ToastCard extends StatelessWidget {
  final String message;
  final ToastAction? action;
  final ToastType type;

  const _ToastCard({
    Key? key,
    required this.message,
    this.action,
    required this.type,
  })  : assert(key != null),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    ToastOverlay? toastOverlay;
    try {
      toastOverlay = Provider.of<ToastOverlay>(context);
    } on ProviderNotFoundException catch (e) {
      print(e);
    }

    Color? backgroundColor;
    Color? textColor;
    switch (type) {
      case ToastType.success:
        backgroundColor =
            toastOverlay?.successfullBackgroundColor ?? Colors.green;
        textColor = toastOverlay?.successfullTextColor ??
            Colors.white.withOpacity(0.87);
        break;
      case ToastType.warning:
        backgroundColor =
            toastOverlay?.warningBackgroundColor ?? Colors.deepOrange;
        textColor =
            toastOverlay?.warningTextColor ?? Colors.white.withOpacity(0.87);
        break;
      case ToastType.error:
        backgroundColor = toastOverlay?.errorBackgroundColor ?? Colors.red;
        textColor =
            toastOverlay?.errorTextColor ?? Colors.white.withOpacity(0.87);
        break;
      case ToastType.notification:
        backgroundColor =
            toastOverlay?.normalBackgroundColor ?? Theme.of(context).cardColor;
        textColor =
            toastOverlay?.normalTextColor ?? Colors.white.withOpacity(0.87);
        break;
      default:
    }

    Widget result = Card(
      color: backgroundColor!.withOpacity(0.97),
      margin: EdgeInsets.zero,
      child: GestureDetector(
        onTap: toastOverlay!.enableTapToHide
            ? () => ToastManager()._hideToastByKey(key!)
            : null,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 17, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: Text(
                  message,
                  textAlign: TextAlign.left,
                  style: TextStyle(color: textColor),
                ),
              ),
              action?.build(
                    context,
                    () => ToastManager()._hideToastByKey(key!),
                  ) ??
                  SizedBox(),
            ],
          ),
        ),
      ),
    );

    if (toastOverlay?.enableSwipeToDismiss != false) {
      result = Dismissible(
        key: key!,
        onDismissed: (_) {
          ToastManager()._hideToastByKey(key!, showAnim: false);
        },
        child: result,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: result,
    );
  }
}

class ToastFuture {
  final _ToastCard _toastCard;

  ToastFuture._(
    this._toastCard,
  );

  void dismiss() {
    ToastManager().hideToast(this);
  }
}

class ToastAction {
  final String label;
  final Color textColor;
  final Color disabledTextColor;
  final void Function(void Function()) onPressed;

  const ToastAction({
    Key? key,
    required this.onPressed,
    required this.disabledTextColor,
    required this.label,
    required this.textColor,
  });

  Widget build(BuildContext context, void Function() hideToast) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: TextButton(
        onPressed: () => onPressed(hideToast),
        child: Text(label),
      ),
    );
  }
}

enum ToastType {
  error,
  success,
  warning,
  notification,
}

/// [ToastOverlay] initialize and dispose [ToastManager] toast controller
///
/// [ToastOverlay] should be inside [MaterialApp] to get [Theme.of(context)]
///
/// EXAMPLE:
/// ```dart
/// MaterialApp(
///   ...
///   builder: (context, child) {
///     return ToastOverlay(child: child);
///   },
///   ...
/// );
/// ```
/// {@end-tool}
/// {@tool sample}
class ToastOverlay extends StatelessWidget {
  /// Toast successfull type background color
  ///
  /// default is [Colors.green]
  final Color successfullBackgroundColor;

  /// Toast successfull type text color
  ///
  /// default is [Colors.white] with opacity 0.87
  final Color successfullTextColor;

  /// Toast warning type background color
  /// default is [Colors.deepOrange]
  final Color warningBackgroundColor;

  /// Toast warning type text color
  ///
  /// default is [Colors.white] with opacity 0.87
  final Color warningTextColor;

  /// Toast error type background color
  /// default is [Colors.red]
  final Color errorBackgroundColor;

  /// Toast error type text color
  ///
  /// default is [Colors.white] with opacity 0.87
  final Color errorTextColor;

  /// Toast normal notification type background color
  ///
  /// default is inversed theme card color
  final Color normalBackgroundColor;

  /// Toast normal notification type text color
  ///
  /// default is inversed theme text color
  final Color normalTextColor;

  /// Is toast should be wrapped with Dismissible
  ///
  /// default is [true]
  final bool enableSwipeToDismiss;

  /// Is toast should be hide on tap
  ///
  /// default is [false]
  final bool enableTapToHide;

  final Widget child;

  const ToastOverlay({
    Key? key,
    required this.child,
    required this.successfullBackgroundColor,
    required this.successfullTextColor,
    required this.warningBackgroundColor,
    required this.warningTextColor,
    required this.errorBackgroundColor,
    required this.errorTextColor,
    required this.normalBackgroundColor,
    required this.normalTextColor,
    this.enableSwipeToDismiss = true,
    this.enableTapToHide = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var statusBarHeight = MediaQuery.of(context).padding.top + 8;

    return Provider<ToastOverlay>.value(
      value: this,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          child,
          SafeArea(
            child: Theme(
              data: _generateInverseTheme(context),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 400),
                child: StreamBuilder<List<ToastFuture>>(
                  stream: ToastManager()._toastsController,
                  builder: (context, toastsSnapshot) {
                    return AnimatedList(
                      key: ToastManager()._toastAnimatedListKey,
                      initialItemCount: toastsSnapshot.data?.length ?? 0,
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemBuilder: (context, index, animation) {
                        return AnimatedBuilder(
                          animation: animation,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(
                                0,
                                -statusBarHeight * (1 - animation.value),
                              ),
                              child: child,
                            );
                          },
                          child: SizeTransition(
                            sizeFactor: animation,
                            child: FadeTransition(
                              opacity: animation,
                              child: toastsSnapshot.data!
                                  .elementAt(index)
                                  ._toastCard,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  ThemeData _generateInverseTheme(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool isThemeDark = theme.brightness == Brightness.dark;

    final Brightness brightness =
        isThemeDark ? Brightness.light : Brightness.dark;
    final Color themeBackgroundColor = isThemeDark
        ? colorScheme.onSurface
        : Color.alphaBlend(
            colorScheme.onSurface.withOpacity(0.80), colorScheme.surface);

    return ThemeData(
      cardTheme: theme.cardTheme,
      brightness: brightness,
      backgroundColor: themeBackgroundColor,
      colorScheme: ColorScheme(
        primary: colorScheme.onPrimary,
        primaryVariant: colorScheme.onPrimary,
        secondary:
            isThemeDark ? colorScheme.primaryVariant : colorScheme.secondary,
        secondaryVariant: colorScheme.onSecondary,
        surface: colorScheme.onSurface,
        background: themeBackgroundColor,
        error: colorScheme.onError,
        onPrimary: colorScheme.primary,
        onSecondary: colorScheme.secondary,
        onSurface: colorScheme.surface,
        onBackground: colorScheme.background,
        onError: colorScheme.error,
        brightness: brightness,
      ),
    );
  }
}

/// Singleton class that controls a toasts
class ToastManager {
  static final ToastManager _toastServiceSingleton = ToastManager._internal();

  factory ToastManager() {
    return _toastServiceSingleton;
  }
  ToastManager._internal();

  final _toastAnimatedListKey = GlobalKey<AnimatedListState>();
  final BehaviorSubject<List<ToastFuture>> _toastsController =
      BehaviorSubject<List<ToastFuture>>.seeded([]);

  ToastFuture? showToast(
    String message, {
    ToastType type = ToastType.notification,
    ToastAction? action,
    Duration duration = const Duration(seconds: 4),
  }) {
    if (_toastsController == null) {
      print('Toast manager is not initialized');
      return null;
    }
    if (message == null) {
      print('No message');
      return null;
    }

    final toastFuture = ToastFuture._(
      _ToastCard(
        key: UniqueKey(),
        message: message,
        action: action,
        type: type,
      ),
    );

    _toastAnimatedListKey.currentState?.insertItem(0);
    _toastsController?.add([
      toastFuture,
      ..._toastsController.value,
    ]);

    Future.delayed(duration, () {
      hideToast(toastFuture);
    });

    return toastFuture;
  }

  void hideToast(ToastFuture toastFuture, {showAnim = true}) async {
    if (_toastsController == null) {
      print('Toast manager is not initialized');
      return;
    }
    if (toastFuture == null) {
      print('No toastFuture');
      return;
    }
    if (_toastsController.value?.contains(toastFuture) != true) {
      return;
    }

    _toastAnimatedListKey.currentState?.removeItem(
      _toastsController.value.indexOf(toastFuture),
      (context, animation) {
        return SizeTransition(
          sizeFactor: animation,
          child: FadeTransition(
            opacity: animation,
            child: toastFuture._toastCard,
          ),
        );
      },
      duration: showAnim ? Duration(milliseconds: 300) : Duration.zero,
    );
    _toastsController.add(
      _toastsController.value..remove(toastFuture),
    );
  }

  void _hideToastByKey(Key toastKey, {showAnim = true}) async {
    if (_toastsController == null) {
      print('Toast manager is not initialized');
      return;
    }
    if (toastKey == null) {
      print('No toastFuture');
      return;
    }
    var toastFuture = _toastsController.value?.firstWhere(
      (toastFuture) => toastFuture._toastCard.key == toastKey,
    );
    hideToast(toastFuture!, showAnim: showAnim);
  }
}


/*
// wrap MaterialApp builder's child with ToastOverlay and set your custom params
MaterialApp(
  ...
  builder: (context, child) {
    return ToastOverlay(child: child);
  },
  ...
);



var toastFuture = ToastManager().showToast(
  'YOUR MESSAGE TO USER',
  type: ToastType.error, // set toast type to change presetted theme color 
  action: ToastAction(
    label: 'HAY',
    onPressed: (hideToastFn) {
      print('yay');
      hideToastFn();
    },
  ),
  duration: Duration(seconds: 3),
);



toastFuture.dismiss(); // to hide toast


 */