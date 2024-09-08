// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

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
import 'package:violet/context/modal_bottom_sheet_context.dart';
import 'package:violet/database/query.dart';
import 'package:violet/log/log.dart';
import 'package:violet/pages/segment/filter_page_controller.dart';
import 'package:violet/script/script_manager.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/thread/semaphore.dart';

class SearchPageController extends GetxController {
  final FlareControls heroFlareControls = FlareControls();
  late AssetFlare asset;

  FilterController filterController = FilterController(
      heroKey: 'searchtype${ModalBottomSheetContext.getCount()}');

  ScrollController? scrollController;
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
    asset = AssetFlare(
      bundle: rootBundle,
      name: 'assets/flare/search_close.flr',
    );
    cachedActor(asset);
  }

  initScroll(BuildContext context) {
    if (scrollController == null) {
      scrollController = ScrollController();
      scrollController!.addListener(scrollPositionListener);
    }
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
          final bottomPadding =
              [8, 8, 0, 0, 0][Settings.searchResultType.index];
          _itemHeight = key.value.currentContext!.size!.height + bottomPadding;
          break;
        }
      }
    }

    if (scrollController!.offset.isNaN) return;

    final itemPerRow = [3, 2, 1, 1, 1][Settings.searchResultType.index];
    const searchBarHeight = 64 + 16;
    final curI =
        ((scrollController!.offset - searchBarHeight) / _itemHeight + 1)
                .toInt() *
            itemPerRow;

    if (curI != searchPageNum.value && isExtended.value) {
      searchPageNum.value = curI;
    }

    //
    // scroll direction
    //
    var upScrolling = scrollController!.position.userScrollDirection ==
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
    if (scrollController!.offset >
        scrollController!.position.maxScrollExtent * 3 / 4) {
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
    FToast().showToast(
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
    final aquire = _querySem.acquire();
    if (!Settings.ignoreTimeout) {
      aquire.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          showErrorToast('Semaphore acquisition failed');

          throw TimeoutException('Failed to acquire the query semaphore');
        },
      );
    }
    await aquire;

    try {
      if (_queryEnd ||
          (latestQuery!.item1 != null && latestQuery!.item1!.offset == -1)) {
        return;
      }

      final search = HentaiManager.search(
        latestQuery!.item2,
        latestQuery!.item1 == null ? 0 : latestQuery!.item1!.offset,
        latestQuery!.item1 == null ? 0 : latestQuery!.item1!.next ?? 0,
      );
      if (!Settings.ignoreTimeout) {
        search.timeout(const Duration(seconds: 10), onTimeout: () {
          Logger.error('[Search_loadNextQuery] Search Timeout');

          throw TimeoutException('Failed to search the query');
        });
      }
      var next = await search;

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

  applyFilter() {
    filterResult = filterController.applyFilter(queryResult);
    isFilterUsed = true;
  }

  doSearch([int baseCount = 0]) async {
    this.baseCount = baseCount;
    _queryEnd = false;
    queryResult = [];
    filterController = FilterController(
        heroKey: 'searchtype${ModalBottomSheetContext.getCount()}');
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
