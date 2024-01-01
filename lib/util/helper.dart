// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

// Suppress excepction
Future catchUnwind(Future Function() body) async {
  try {
    await body();
  } catch (_) {}
}

Future fixedPoint<T>(Future Function() body, T Function() value) async {
  do {
    final prev = value();

    await body();

    if (prev == value()) {
      break;
    }
  } while (true);
}
