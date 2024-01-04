// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:collection';
import 'dart:io';

import 'package:dart_git/git.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:violet/util/git.dart';

class BookmarkGroupKeyVal {
  int? id;
  String? name;
  String? dateTime;
  String? description;
  int? color;
  int? gorder;
}

class BookmarkArticleKeyVal {
  int? id;
  int? article;
  String? dateTime;
  int? groupId;
}

class GitBookmark {
  static Map<BookmarkGroupKeyVal,List<BookmarkArticleKeyVal>>? bookmarkInfo;
  static Future<Map<BookmarkGroupKeyVal,List<BookmarkArticleKeyVal>>?> process() async {
    // https://e-hentai.org/favorites.php?page=0&favcat=0
    // https://exhentai.org/favorites.php?page=0&favcat=0

    Map<BookmarkGroupKeyVal,List<BookmarkArticleKeyVal>> result = <BookmarkGroupKeyVal,List<BookmarkArticleKeyVal>>{};

    final git = BookmarkGit();
    final gitPath = '${(await getTemporaryDirectory()).path}/_tmp_bookmark_from_git';
    if(await Directory(gitPath).exists()){
      await Directory(gitPath).delete(recursive: true);
    }
    GitRepository gitRepo = await git.clone(gitPath);
    String getRelatedPath(String absolutePath){
      return absolutePath
        .replaceAll(gitPath, '')
        .split('/')
        .where((p) => p.isNotEmpty)
        .join('/');
    }

    List<FileSystemEntity> getList(){
      return Directory(gitPath)
        .listSync(recursive: true, followLinks: false)
        .where((absolutePath) => getRelatedPath(absolutePath.path)
          .split('/')
          .firstOrNull
          ?.isNotEmpty ?? false)
        .where((absolutePath) => getRelatedPath(absolutePath.path)
          .split('/')
          .firstOrNull != '.git').toList();
    }
    if(await Directory(gitPath).exists()){
      final listInPath = getList();
      print(listInPath);
      await Future.forEach(listInPath,(absolutePath) async {
        var bookmark = <BookmarkArticleKeyVal>[];
        var desc = '';
        final relativePath = getRelatedPath(absolutePath.path);
        if(relativePath.split('/').isNotEmpty){
          if(relativePath.split('/').firstOrNull != '.git'){
            if(relativePath.split('/').lastOrNull?.endsWith('.db') ?? false){
              Database db = await openDatabase(absolutePath.path);
              final bookmarkGroups = await db.query('BookmarkGroup');
              for(var bookmarkGroup in bookmarkGroups){
                BookmarkGroupKeyVal group = BookmarkGroupKeyVal();
                // "Id", "Name", "DateTime", "Description", "Color", "Gorder"
                //  Int, String,   String  ,    String    ,   Int  ,   Int
                bookmarkGroup.forEach((key,value){
                  if(key == 'Id') group.id = int.tryParse(value.toString());
                  if(key == 'Name') group.name = value.toString();
                  if(key == 'DataTime') group.dateTime = value.toString();
                  if(key == 'Description') group.description = value.toString();
                  if(key == 'Color') group.color = int.tryParse(value.toString());
                  if(key == 'Gorder') group.gorder = int.tryParse(value.toString());
                });
                final bookmarkArticles = await db.query('BookmarkArticle');
                // "Id", "Article", "DateTime", "GroupId"
                //  Int,    Int   ,  String   ,   Int
                for(final bookmarkArticle in bookmarkArticles){
                  BookmarkArticleKeyVal article = BookmarkArticleKeyVal();
                  bookmarkArticle.forEach((key, value) {
                    if(key == 'Id') article.id = int.tryParse(value.toString());
                    if(key == 'Article') article.article = int.tryParse(value.toString());
                    if(key == 'DateTime') article.dateTime = value.toString();
                    if(key == 'GroupId') article.groupId = int.tryParse(value.toString());
                  });
                  if(group.gorder == article.groupId){                    
                    result[group] ??= <BookmarkArticleKeyVal>[];
                    result[group]!.add(article);
                  }
                }
              }
              await db.close();
            }
          }
        }
      });
    }
    return bookmarkInfo = result;
  }
}
