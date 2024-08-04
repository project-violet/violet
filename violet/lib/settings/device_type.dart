// https://github.com/ominibyte/flutter_device_type/blob/master/lib/flutter_device_type.dart

import 'dart:io';
import 'dart:ui' as ui;
import 'dart:ui';

class Device {
  static double devicePixelRatio =
      PlatformDispatcher.instance.views.first.devicePixelRatio;
  static ui.Size size = PlatformDispatcher.instance.views.first.physicalSize;
  static double width = size.width;
  static double height = size.height;
  static double screenWidth = width / devicePixelRatio;
  static double screenHeight = height / devicePixelRatio;
  static ui.Size screenSize = ui.Size(screenWidth, screenHeight);
  final bool isTablet, isPhone, isIos, isAndroid, isIphoneX;
  static Device? _device;

  Device({
    required this.isTablet,
    required this.isPhone,
    required this.isIos,
    required this.isAndroid,
    required this.isIphoneX,
  });

  factory Device.get() {
    if (_device != null) return _device!;

    bool isTablet;
    bool isPhone;
    bool isIos = Platform.isIOS;
    bool isAndroid = Platform.isAndroid;
    bool isIphoneX = false;

    if (devicePixelRatio < 2 && (width >= 1000 || height >= 1000)) {
      isTablet = true;
      isPhone = false;
    } else if (devicePixelRatio == 2 && (width >= 1920 || height >= 1920)) {
      isTablet = true;
      isPhone = false;
    } else {
      isTablet = false;
      isPhone = true;
    }

    if (isIos &&
        (screenHeight == 812 ||
            screenWidth == 812 ||
            screenHeight == 896 ||
            screenWidth == 896)) isIphoneX = true;

    return _device = Device(
        isTablet: isTablet,
        isPhone: isPhone,
        isAndroid: isAndroid,
        isIos: isIos,
        isIphoneX: isIphoneX);
  }
}
