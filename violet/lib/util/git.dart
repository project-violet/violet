import 'dart:io';
import 'dart:convert';

import 'package:dart_git/exceptions.dart';
import 'package:dart_git/git.dart';
import 'package:dart_git/plumbing/objects/commit.dart';
import 'package:go_git_dart/go_git_dart.dart' as go_git_dart;
import 'package:dart_git/dart_git.dart' as dart_git;
import 'package:violet/log/log.dart';
import 'package:violet/settings/settings.dart';

class BookmarkGit {
  String? repo;
  String? host;
  String? key;
  String? pass;
  go_git_dart.GitBindings? gitBindings;
  Future<void> _init() async {
    repo = Settings.bookmarkRepository;
    host = Settings.bookmarkHost;
    key = Settings.bookmarkPrivateKey;
    pass = Settings.bookmarkPrivateKeyPassword;
  }
  Future<GitRepository> init(String path) async {
    await _init();
    try {
      GitRepository.init(path);
      Logger.info('[BookmarkGit.init] Successfully init repo');
    } catch(e,st){
      Logger.error('[BookmarkGit.init] $e\n'
        '$st');
    }
    GitRepository gitRepo = await load(path);
    if(gitRepo.config.remote('origin') == null){
      try {
        gitRepo.addRemote('origin', 'git@$host:$repo.git');
        Logger.info('[BookmarkGit.init] Successfully add remote origin to git@$host:$repo.git');
      } catch(e,st){
        Logger.error('[BookmarkGit.clone] $e\n'
          '$st');
      }
    }
    return gitRepo;
  }

  Future<GitRepository> load(String path) async {
    await _init();
    late GitRepository gitRepo;
    try {
      gitRepo = GitRepository.load(path);
    } catch(e){
      rethrow;
    }
    return gitRepo;
  }

  Future<GitRepository> clone(String path) async {
    await _init();
    var gitBindings = go_git_dart.GitBindings();
    try {
      gitBindings.clone(
        'git@$host:$repo.git',
        path,
        utf8.encode(key!),
        pass!
      );
      Logger.info('[BookmarkGit.clone] Successfully cloned from git@$host:$repo.git');
    } catch(e,st){
      Logger.error('[BookmarkGit.clone] $e\n'
        '$st');
      await init(path);
    }
    GitRepository gitRepo = await load(path);
    if(gitRepo.config.remote('origin') == null){
      try {
        gitRepo.addRemote('origin', 'git@$host:$repo.git');
      } catch(e,st){
        Logger.error('[BookmarkGit.clone] $e\n'
          '$st');
      }
    }
    return gitRepo;
  }

  Future<GitRepository> addAll(String path) async {
    GitRepository gitRepo = await load(path);
    if(Directory(path).existsSync()){
      List<FileSystemEntity> listInPath = Directory(path).listSync(recursive: true,followLinks: false);
      // ignore: avoid_function_literals_in_foreach_calls
      listInPath.forEach((absolutePath) {
        final relativePath = absolutePath.path
          .replaceFirst(path, '') // It removes the current path in string
          .split('/') // It handles '/a//b/c' to ['','a','','b','c']
          .where((p) => p.isNotEmpty) // It handles ['','a','','b','c'] to ['a','b','c']
          .join('/'); // It handles ['a','b','c'] to 'a/b/c'
        if(relativePath.split('/').isNotEmpty){
          if(relativePath.split('/').firstOrNull != '.git'){
            gitRepo.add(absolutePath.path);
          }
        }
      });
    }
    return gitRepo;
  }

  Future<GitRepository> commit(String path) async {
    await _init();
    GitRepository gitRepo = GitRepository.load(path);
    gitRepo.config.user = GitAuthor(
      name: 'Violet Committer', // It handles git config user.name
      email: 'violet@no-reply.koromo.xyz' // It handles git config user.email
    ); 
    try {
      gitRepo.commit( // It handles commit
        message: DateTime.now().toIso8601String(), // Message with DateTime
        author: gitRepo.config.user!, // Author with Violet Committer
        committer: gitRepo.config.user! // Committer with VioletCommitter
      );
    } catch(e,st){
      if(e is GitEmptyCommit){
        Logger.warning('[BookmarkGit.commit] Nothing to commit');
      } else {
        Logger.error('[BookmarkGit.commit] $e\n'
          '$st');
      }
    }
    return gitRepo;
  }

  Future<void> push(String path) async {
    await _init();
    var gitBindings = go_git_dart.GitBindings();
    try {
      gitBindings.push(
        'origin',
        path,
        utf8.encode(key!),
        pass!
      );
      Logger.info('[BookmarkGit.push] Successfully pushed\n'
        'to git@$host:$repo.git');
    } catch(e,st){
      Logger.error('[BookmarkGit.push] $e\n'
        '$st');
    }
    
  }
}