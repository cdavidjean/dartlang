
/// A console output view.
library atom.console;

import 'dart:html' show ScrollAlignment;

import '../atom.dart';
import '../atom_statusbar.dart';
import '../elements.dart';
import '../state.dart';
import '../utils.dart';
import '../views.dart';
import 'launch.dart';

class ConsoleController implements Disposable {
  ConsoleView view;
  ConsoleStatusElement statusElement;

  Disposables disposables = new Disposables();

  ConsoleController() {
    view = new ConsoleView();
    statusElement = new ConsoleStatusElement(this, false);

    disposables.add(atom.commands.add(
        'atom-workspace', '${pluginId}:toggle-console', (_) {
      _toggleView();
    }));
  }

  void initStatusBar(StatusBar statusBar) {
    statusElement._init(statusBar);
  }

  void _toggleView() => view.toggle();

  void dispose() {
    view.dispose();
    statusElement.dispose();
    disposables.dispose();
  }
}

class ConsoleView extends AtomView {
  static bool get autoShowConsole =>
      atom.config.getValue('${pluginId}.autoShowConsole');

  CoreElement tabsElement;

  _LaunchController _activeController;
  Map<Launch, _LaunchController> _controllers = {};

  ConsoleView() : super('Console', classes: 'console-view',
      prefName: 'Console', rightPanel: false, showTitle: false,
      groupName: 'bottomView') {
    content..add([
      div(c: 'console-title-area')..add([
        tabsElement = div(c: 'console-tabs')
      ])
    ]);

    subs.add(launchManager.onLaunchAdded.listen(_launchAdded));
    subs.add(launchManager.onLaunchActivated.listen(_launchActivated));
    subs.add(launchManager.onLaunchTerminated.listen(_launchTerminated));
    subs.add(launchManager.onLaunchRemoved.listen(_launchRemoved));

    root.listenForUserCopy();
  }

  void _launchAdded(Launch launch) {
    _controllers[launch] = new _LaunchController(this, launch);

    // Auto show when a launch starts.
    if (!isVisible() && autoShowConsole) {
      show();
    }
  }

  void _launchTerminated(Launch launch) {
    _controllers[launch].handleTerminated();
  }

  void _launchActivated(Launch launch) {
    if (_activeController != null) _activeController.deactivate();
    _activeController = _controllers[launch];
    if (_activeController != null) _activeController.activate();
  }

  void _launchRemoved(Launch launch) {
    final _LaunchController controller = _controllers.remove(launch);
    controller.dispose();
    if (controller == _activeController) _activeController = null;

    if (_controllers.isEmpty && isVisible()) {
      hide();
    }
  }
}

class _LaunchController implements Disposable {
  // Only show a set amount of lines of output.
  static const _maxLines = 200;

  final ConsoleView view;
  final Launch launch;

  CoreElement container;
  CoreElement buttons;
  CoreElement output;
  StreamSubscriptions subs = new StreamSubscriptions();

  String _lastText = '';
  dynamic _scrollTop;

  _LaunchController(this.view, this.launch) {
    view.tabsElement.add([
      container = div(c: 'badge process-tab')..add([
        span(text: launch.launchType.type),
        span(text: ' • '),
        span(text: launch.title),
        span(text: ' • '),
        buttons = div(c: 'run-buttons')
      ])
    ]);
    container.click(() => launch.manager.setActiveLaunch(launch));

    _updateToggles();
    _updateButtons();

    output = new CoreElement('pre', classes: 'console-line');
    // Allow the text in the console to be selected.
    output.element.tabIndex = -1;

    subs.add(launch.onStdio.listen((text) => _emitText(
        text.text, error: text.error, subtle: text.subtle, highlight: text.highlight)));
  }

  void activate() {
    _updateToggles();
    _updateButtons();
    view.content.add(output.element);

    if (_scrollTop != null) {
      output.element.parent.scrollTop = _scrollTop;
    } else {
      output.element.scrollIntoView(ScrollAlignment.BOTTOM);
    }
  }

  void handleTerminated() {
    _updateToggles();
    _updateButtons();

    container.toggleClass('launch-terminated', true);

    if (!_lastText.endsWith('\n')) _emitText('\n');
    _emitText('• exited with code ${launch.exitCode} •', highlight: true);
    //_emitBadge('exit ${launch.exitCode}', launch.errored ? 'error' : 'info');
  }

  void deactivate() {
    _scrollTop = output.element.parent.scrollTop;
    _updateToggles();
    _updateButtons();
    output.dispose();
  }

  void _updateToggles() {
    container.toggleClass('badge-info', launch.isActive);
    // container.toggleClass('badge-error', launch.isActive && launch.errored);
  }

  void _updateButtons() {
    buttons.clear();

    // debug
    if (launch.isRunning && launch.canDebug()) {
      CoreElement debug = buttons.add(
          span(text: '\u200B', c: 'process-icon icon-bug'));
      debug.toggleClass('text-highlight', launch.isActive);
      debug.tooltip = 'Open the Observatory';
      debug.click(() {
        shell.openExternal('http://localhost:${launch.servicePort}/');
      });
    }

    // kill
    if (launch.canKill() && launch.isRunning) {
      CoreElement kill = buttons.add(
          span(text: '\u200B', c: 'process-icon icon-primitive-square'));
      kill.toggleClass('text-highlight', launch.isActive);
      kill.tooltip = 'Terminate process';
      kill.click(() => launch.kill());
    }

    // clear
    if (launch.isTerminated) {
      CoreElement clear = buttons.add(
          span(text: '\u200B', c: 'process-icon icon-x'));
      clear.toggleClass('text-highlight', launch.isActive);
      clear.tooltip = 'Remove the completed launch';
      clear.click(() => launchManager.removeLaunch(launch));
    }
  }

  void dispose() {
    container.dispose();
    output.dispose();
    subs.cancel();
  }

  // void _emitBadge(String text, String type) {
  //   _scrollTop = null;
  //   output.add(span(text: text, c: 'badge badge-${type}'));
  //
  //   if (output.element.parent != null) {
  //     output.element.scrollIntoView(ScrollAlignment.BOTTOM);
  //   }
  // }

  // ' (dart:core-patch/errors_patch.dart:27)'
  // ' (packages/flutter/src/rendering/flex.dart:475)'
  // ' (/Users/foo/flutter/flutter_playground/lib/main.dart:6)'
  // ' (file:///Users/foo/flutter/flutter_playground/lib/main.dart:6)'
  // ' (http:localhost:8080/src/errors.dart:27)'
  // ' (http:localhost:8080/src/errors.dart:27:12)'
  // ' (file:///ssd2/sky/engine/src/out/android_Release/gen/sky/bindings/Customhooks.dart:35)'
  //
  // 'test/utils_test.dart 21 '
  // 'test/utils_test.dart 21:7 '
  final RegExp _consoleMatcher =
      new RegExp(r' \((\S+\.dart):(\d+)(:\d+)?\)|(\S+\.dart) (\d+)(:\d+)? ');

  void _emitText(String str, {bool error: false, bool subtle: false, bool highlight: false}) {
    _scrollTop = null;
    _lastText = str;

    List<Match> matches = _consoleMatcher.allMatches(str).toList();

    CoreElement e;

    if (matches.isEmpty) {
      e = span(text: str);
    } else {
      e = span();

      int offset = 0;

      for (Match match in matches) {
        String ref = match.group(1) ?? match.group(4);
        String line = match.group(2) ?? match.group(5);
        int startIndex = match.start + (match.group(1) != null ? 2 : 0);

        e.add(span(text: str.substring(offset, startIndex)));

        String text = '${ref}:${line}';
        CoreElement link = e.add(span(text: text));

        offset = startIndex + text.length;

        launch.resolve(ref).then((String path) {
          if (path != null) {
            link.toggleClass('trace-link');
            link.click(() {
              editorManager.jumpToLine(
                path,
                int.parse(line, onError: (_) => 1) - 1,
                selectLine: true
              );
            });
          }
        });
      }

      if (offset != str.length) {
        e.add(span(text: str.substring(offset)));
      }
    }

    if (highlight) e.toggleClass('text-highlight');
    if (error) e.toggleClass('console-error');
    if (subtle) e.toggleClass('text-subtle');

    output.add(e);

    List children = output.element.children;
    if (children.length > _maxLines) {
      children.remove(children.first);
    }

    if (output.element.parent != null) {
      output.element.scrollIntoView(ScrollAlignment.BOTTOM);
    }
  }
}

class ConsoleStatusElement implements Disposable {
  final ConsoleController parent;
  bool _showing;
  StreamSubscriptions subs = new StreamSubscriptions();

  Tile statusTile;

  CoreElement _element;
  CoreElement _badgeSpan;

  ConsoleStatusElement(this.parent, this._showing) {
    subs.add(launchManager.onLaunchAdded.listen(_handleLaunchesChanged));
    subs.add(launchManager.onLaunchTerminated.listen(_handleLaunchesChanged));
    subs.add(launchManager.onLaunchRemoved.listen(_handleLaunchesChanged));
  }

  bool isShowing() => _showing;

  void show() {
    _element.element.style.display = 'inline-block';
    _showing = true;
  }

  void hide() {
    _element.element.style.display = 'none';
    _showing = false;
  }

  void dispose() {
    if (statusTile != null) statusTile.destroy();
    subs.cancel();
  }

  void _init(StatusBar statusBar) {
    _element = div(c: 'dartlang process-status-bar')..inlineBlock()..add([
      _badgeSpan = span(c: 'badge')
    ]);

    _element.click(parent._toggleView);

    statusTile = statusBar.addLeftTile(item: _element.element, priority: -99);

    if (!isShowing()) {
      _element.element.style.display = 'none';
    }

    _handleLaunchesChanged();
  }

  void _handleLaunchesChanged([Launch _]) {
    if (_element == null) return;

    List<Launch> launches = launchManager.launches;
    int count = launches.length;

    if (count > 0) {
      if (!isShowing()) show();
      _badgeSpan.text = '${count} ${pluralize('process', count)}';
    } else {
      hide();
      _badgeSpan.text = 'no processes';
    }
  }
}
