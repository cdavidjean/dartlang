// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library atom.utils;

import 'dart:async';

import 'package:logging/logging.dart';

final String loremIpsum = "Lorem ipsum dolor sit amet, consectetur adipiscing "
    "elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. "
    "Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi "
    "ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit"
    " in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur"
    " sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt "
    "mollit anim id est laborum.";

final Logger _logger = new Logger('atom.utils');

/// Ensure the first letter is lower-case.
String toStartingLowerCase(String str) {
  if (str == null) return null;
  if (str.isEmpty) return str;
  return str.substring(0, 1).toLowerCase() + str.substring(1);
}

String toTitleCase(String str) {
  if (str == null) return null;
  if (str.isEmpty) return str;
  return str.substring(0, 1).toUpperCase() + str.substring(1);
}

String pluralize(String word, int count) {
  if (count == 1) return word;
  if (word.endsWith('s')) return '${word}es';
  return '${word}s';
}

String commas(int n) {
  String str = '${n}';
  int len = str.length;
  // if (len > 6) {
  //   int pos1 = len - 6;
  //   int pos2 = len - 3;
  //   return '${str.substring(0, pos1)},${str.substring(pos1, pos2)},${str.substring(pos2)}';
  // } else
  if (len > 3) {
    int pos = len - 3;
    return '${str.substring(0, pos)},${str.substring(pos)}';
  } else {
    return str;
  }
}

final RegExp idRegex = new RegExp(r'[_a-zA-Z0-9]');

abstract class Disposable {
  void dispose();
}

class Disposables implements Disposable {
  final bool catchExceptions;

  List<Disposable> _disposables = [];

  Disposables({this.catchExceptions});

  void add(Disposable disposable) => _disposables.add(disposable);

  bool remove(Disposable disposable) => _disposables.remove(disposable);

  void dispose() {
    for (Disposable disposable in _disposables) {
      if (catchExceptions) {
        try {
          disposable.dispose();
        } catch (e, st) {
          _logger.severe('exception during dispose', e, st);
        }
      } else {
        disposable.dispose();
      }
    }

    _disposables.clear();
  }
}

class StreamSubscriptions implements Disposable {
  final bool catchExceptions;

  List<StreamSubscription> _subscriptions = [];

  StreamSubscriptions({this.catchExceptions});

  void add(StreamSubscription subscription) => _subscriptions.add(subscription);

  bool remove(StreamSubscription subscription) =>
      _subscriptions.remove(subscription);

  void cancel() {
    for (StreamSubscription subscription in _subscriptions) {
      if (catchExceptions) {
        try {
          subscription.cancel();
        } catch (e, st) {
          _logger.severe('exception during subscription cancel', e, st);
        }
      } else {
        subscription.cancel();
      }
    }

    _subscriptions.clear();
  }

  void dispose() => cancel();
}

class DisposeableSubscription implements Disposable {
  final StreamSubscription sub;
  DisposeableSubscription(this.sub);
  void dispose() { sub.cancel(); }
}

class Edit {
  final int offset;
  final int length;
  final String replacement;

  Edit(this.offset, this.length, this.replacement);

  bool operator==(obj) {
    if (obj is! Edit) return false;
    Edit other = obj;
    return offset == other.offset && length == other.length &&
        replacement == other.replacement;
  }

  int get hashCode => offset ^ length ^ replacement.hashCode;

  String toString() => '[Edit offset: ${offset}, length: ${length}]';
}

/// A value that fires events when it changes.
class Property<T> {
  T _value;
  StreamController<T> _controller = new StreamController.broadcast();

  Property([T initialValue]) {
    _value = initialValue;
  }

  T get value => _value;
  set value(T v) {
    _value = v;
    _controller.add(_value);
  }

  bool get hasValue => _value != null;

  Stream<T> get onChanged => _controller.stream;

  String toString() => '${_value}';
}

/// A SelectionGroup:
/// - manages a set of items
/// - fires notifications when the set changes
/// - has a notion of a 'selected' or active item
class SelectionGroup<T> {
  T _selection;
  List<T> _items = [];

  StreamController<T> _addedController = new StreamController.broadcast();
  StreamController<T> _selectionChangedController = new StreamController.broadcast();
  StreamController<T> _removedController = new StreamController.broadcast();

  SelectionGroup();

  T get selection => _selection;

  List<T> get items => _items;

  int get length => _items.length;

  Stream<T> get onAdded => _addedController.stream;
  Stream<T> get onSelectionChanged => _selectionChangedController.stream;
  Stream<T> get onRemoved => _removedController.stream;

  void add(T item) {
    _items.add(item);
    _addedController.add(item);

    if (_selection == null) {
      _selection = item;
      _selectionChangedController.add(selection);
    }
  }

  void setSelection(T sel) {
    if (_selection != sel) {
      _selection = sel;
      _selectionChangedController.add(selection);
    }
  }

  void remove(T item) {
    _items.remove(item);
    _removedController.add(item);

    if (_selection == item) {
      _selection = null;
      _selectionChangedController.add(null);
    }
  }
}

bool listIdentical(List a, List b) {
  if (a.length != b.length) return false;

  for (int i = 0; i < a.length; i++) {
    var _a = a[i];
    var _b = b[i];
    if (_a == null && _b != null) return false;
    if (_a != null && _b == null) return false;
    if (_a != _b) return false;
  }

  return true;
}

// TODO: Implement this.

/// Diff the two strings and return the list of edits to convert [oldText] to
/// [newText].
List<Edit> simpleDiff(String oldText, String newText) {
  // TODO: Optimize this. Look for a single deletion, addition, or replacement
  // edit that will convert oldtext to newText, or do a wholesale replacement.

  // int oldLen = oldText.length;
  // int newLen = newText.length;
  //
  // int maxLen = math.min(oldLen, newLen);
  // int prefixLen = 0;
  //
  // while (prefixLen < maxLen) {
  //   if (oldText[prefixLen] == newText[prefixLen]) {
  //     prefixLen++;
  //   } else {
  //     break;
  //   }
  // }
  //
  // int suffixLen = 0;
  //
  // while ((suffixLen + prefixLen) < maxLen) {
  //   if (oldText[oldLen - suffixLen - 1] == newText[newLen - suffixLen - 1]) {
  //     suffixLen++;
  //   } else {
  //     break;
  //   }
  // }
  //
  // print('maxlen=${maxLen}, prefixlen=${prefixLen}, suffixlen=${suffixLen}');

  return [new Edit(0, oldText.length, newText)];
}
