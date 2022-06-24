import 'package:get/get.dart';
import 'package:violet/pages/viewer/others/preload_page_view.dart';
import 'package:violet/pages/viewer/others/scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:violet/pages/viewer/viewer_page_provider.dart';
import 'package:violet/settings/settings.dart';

enum ViewType {
  vertical,
  horizontal,
}

class ViewerController extends GetxController {
  final ViewerPageProvider provider;
  var page = 0.obs;
  var viewType =
      Settings.isHorizontal ? ViewType.horizontal.obs : ViewType.vertical.obs;
  var viewScrollType =
      Settings.scrollVertical ? ViewType.vertical.obs : ViewType.horizontal.obs;
  var padding = Settings.padding.obs;
  var animation = Settings.animation.obs;
  var rightToLeft = Settings.rightToLeft.obs;
  var leftRightButton = (!Settings.disableOverlayButton).obs;
  var appBarToBottom = Settings.moveToAppBarToBottom.obs;
  var showSlider = Settings.showSlider.obs;
  var indicator = Settings.showPageNumberIndicator.obs;
  var fullscreen = (!Settings.disableFullScreen).obs;
  var imgQuality = Settings.imageQuality.obs;
  late RxBool thumb;
  var thumbSize = Settings.thumbSize.obs;
  var timer = false.obs;
  var timerTick = Settings.timerTick.obs;
  var search = false.obs;
  var onSession = true.obs;
  late RxInt articleId;

  final ItemScrollController _verticalItemScrollController =
      ItemScrollController();
  final PreloadPageController _horizontalPageController =
      PreloadPageController();

  late int maxPage;

  ViewerController(this.provider) {
    articleId = provider.id.obs;
    maxPage = provider.uris.length;
    thumb = provider.useFileSystem.obs;
  }

  jump(int page) {
    if (page < 0) return;
    if (page >= maxPage) return;

    this.page.value = page;

    if (viewType.value == ViewType.vertical) {
      _verticalItemScrollController.scrollTo(
        index: page,
        duration: const Duration(microseconds: 1),
        alignment: 0.12,
      );
    } else {
      _horizontalPageController.jumpToPage(page);
    }
  }

  prev() => jump(page.value - 1);
  next() => jump(page.value + 1);
}
