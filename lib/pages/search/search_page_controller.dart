import 'dart:async';

import 'package:flare_flutter/flare_cache.dart';
import 'package:flare_flutter/flare_controls.dart';
import 'package:flare_flutter/provider/asset_flare.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:tuple/tuple.dart';
import 'package:violet/component/hentai.dart';
import 'package:violet/component/hitomi/population.dart';
import 'package:violet/database/query.dart';
import 'package:violet/log/log.dart';
import 'package:violet/pages/segment/filter_page.dart';
import 'package:violet/script/script_manager.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/thread/semaphore.dart';

class SearchPageController extends GetxController {
  final FToast fToast = FToast();

  final FlareControls heroFlareControls = FlareControls();
  late AssetFlare asset;

  FilterController filterController = FilterController();

  final ScrollController scrollController = ScrollController();
  Map<String, GlobalKey> itemKeys = <String, GlobalKey>{};

  final List<int> _scrollQueue = <int>[];
  double _itemHeight = 0.0;
  bool _scrollInProgress = false;
  bool _queryEnd = false;

  var isExtended = false.obs;
  var searchPageNum = 0.obs;
  var searchTotalResultCount = 0.obs;

  final Semaphore _querySem = Semaphore(maxCount: 1);
  Tuple2<SearchResult?, String>? latestQuery;
  List<QueryResult> queryResult = [];
  List<QueryResult> filterResult = [];
  int baseCount = 0; // using for user custom page index
  bool isFilterUsed = false;

  final VoidCallback reloadForce;

  SearchPageController({required this.reloadForce});

  init(BuildContext context) {
    scrollController.addListener(scrollPositionListener);

    fToast.init(context);

    asset = AssetFlare(
      bundle: rootBundle,
      name: 'assets/flare/search_close.flr',
    );
    cachedActor(asset);
  }

  scrollPositionListener() {
    //
    // scroll position
    //
    if (itemKeys.isNotEmpty && _itemHeight <= 0.1) {
      for (var key in itemKeys.entries) {
        // invisible article is not rendered yet
        // so we can find live elements
        if (key.value.currentContext != null) {
          final bottomPadding = [8, 8, 0, 0, 0][Settings.searchResultType];
          _itemHeight = key.value.currentContext!.size!.height + bottomPadding;
          break;
        }
      }
    }

    if (scrollController.offset.isNaN) return;

    final itemPerRow = [3, 2, 1, 1, 1][Settings.searchResultType];
    const searchBarHeight = 64 + 16;
    final curI = ((scrollController.offset - searchBarHeight) / _itemHeight + 1)
            .toInt() *
        itemPerRow;

    if (curI != searchPageNum.value && isExtended.value) {
      searchPageNum.value = curI;
    }

    //
    // scroll direction
    //
    var upScrolling = scrollController.position.userScrollDirection ==
        ScrollDirection.forward;

    if (upScrolling) {
      _scrollQueue.add(-1);
    } else {
      _scrollQueue.add(1);
    }

    if (_scrollQueue.length > 64) {
      _scrollQueue.removeRange(0, _scrollQueue.length - 65);
    }

    var p = _scrollQueue.reduce((value, element) => value + element);

    if (p <= -32 && !isExtended.value) {
      isExtended.value = true;
    } else if (p >= 32 && isExtended.value) {
      isExtended.value = false;
    }

    //
    //  scroll lazy next query loading
    //
    if (_scrollInProgress || _queryEnd) return;
    if (scrollController.offset >
        scrollController.position.maxScrollExtent * 3 / 4) {
      _scrollInProgress = true;
      Future.delayed(const Duration(milliseconds: 100), () async {
        try {
          await loadNextQuery();
        } catch (e) {
          print('loadNextQuery failed: $e');
        } finally {
          _scrollInProgress = false;
        }
      }).catchError((e) {
        _scrollInProgress = false;
      });
    }
  }

  resetItemHeight() => _itemHeight = 0.0;

  showErrorToast(String message) {
    fToast.showToast(
      toastDuration: const Duration(seconds: 10),
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(),
          borderRadius: const BorderRadius.all(Radius.circular(8.0)),
        ),
        child: Text(message),
      ),
    );
  }

  loadNextQuery() async {
    await _querySem.acquire().timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        showErrorToast('Semaphore acquisition failed');

        throw TimeoutException('Failed to acquire the query semaphore');
      },
    );

    try {
      if (_queryEnd ||
          (latestQuery!.item1 != null && latestQuery!.item1!.offset == -1)) {
        return;
      }

      var next = await HentaiManager.search(latestQuery!.item2,
              latestQuery!.item1 == null ? 0 : latestQuery!.item1!.offset)
          .timeout(const Duration(seconds: 10), onTimeout: () {
        Logger.error('[Search_loadNextQuery] Search Timeout');

        throw TimeoutException('Failed to search the query');
      });

      latestQuery = Tuple2(next, latestQuery!.item2);

      if (next.results.isEmpty) {
        _queryEnd = true;
        reloadForce();
        return;
      }

      queryResult.addAll(next.results);

      if (filterController.isPopulationSort) {
        Population.sortByPopulation(queryResult);
      }

      if (searchTotalResultCount.value == 0 &&
          !latestQuery!.item2.contains('random:')) {
        Future.delayed(const Duration(milliseconds: 100)).then((value) async {
          searchTotalResultCount.value =
              await HentaiManager.countSearch(latestQuery!.item2);
        });
      }

      reloadForce();

      ScriptManager.refresh();
    } catch (e, st) {
      Logger.error('[search-error] E: $e\n'
          '$st');
      rethrow;
    } finally {
      _querySem.release();
    }
  }

  void applyFilter() {
    final result = <QueryResult>[];
    final isOr = filterController.isOr;
    queryResult.forEach((element) {
      // key := <group>:<name>
      var succ = !filterController.isOr;
      filterController.tagStates.forEach((key, value) {
        if (!value) return;

        // Check match just only one
        if (succ == isOr) return;

        // Get db column name from group
        final split = key.split('|');
        final dbColumn = prefix2Tag(split[0]);

        // There is no matched db column name
        if (element.result[dbColumn] == null && !isOr) {
          succ = false;
          return;
        }

        // If Single Tag
        if (!isSingleTag(split[0])) {
          var tag = split[1];
          if (['female', 'male'].contains(split[0])) {
            tag = '${split[0]}:${split[1]}';
          }
          if ((element.result[dbColumn] as String).contains('|$tag|') == isOr) {
            succ = isOr;
          }
        }

        // If Multitag
        else if ((element.result[dbColumn] as String == split[1]) == isOr) {
          succ = isOr;
        }
      });
      if (succ) result.add(element);
    });

    filterResult = result;
    isFilterUsed = true;

    if (filterController.isPopulationSort) {
      Population.sortByPopulation(filterResult);
    }
  }

  static String prefix2Tag(String prefix) {
    switch (prefix) {
      case 'artist':
        return 'Artists';
      case 'group':
        return 'Groups';
      case 'language':
        return 'Language';
      case 'character':
        return 'Characters';
      case 'series':
        return 'Series';
      case 'class':
        return 'Class';
      case 'type':
        return 'Type';
      case 'uploader':
        return 'Uploader';
      case 'tag':
      case 'female':
      case 'male':
        return 'Tags';
    }
    return '';
  }

  static bool isSingleTag(String prefix) {
    switch (prefix) {
      case 'language':
      case 'class':
      case 'type':
      case 'uploader':
        return true;
      case 'artist':
      case 'group':
      case 'character':
      case 'tag':
      case 'female':
      case 'male':
      case 'series':
      default:
        return false;
    }
  }

  doSearch([int baseCount = 0]) async {
    this.baseCount = baseCount;
    _queryEnd = false;
    queryResult = [];
    filterController = FilterController();
    isFilterUsed = false;
    searchTotalResultCount.value = 0;
    searchPageNum.value = 0;
    loadNextQuery();
  }

  List<QueryResult> getSearchList() {
    if (!isFilterUsed) return queryResult;
    return filterResult;
  }
}
