import 'dart:async';
import 'dart:collection';

typedef SchedulerTask<R> = FutureOr<R?> Function(SchedulerController c);

class Scheduler {
  final Queue<SchedulerTask> _queue = Queue();
  final Map<int, _Result<dynamic>> _resultMap = {};
  final SchedulerController _controller = SchedulerController();

  late final Duration _gap;

  bool _looping = false;
  Completer<void> _loopCompleter = Completer<void>()..complete();

  Scheduler(int n, Duration per) {
    if (n > 0 && per.inMilliseconds > 0) {
      Duration gap = Duration(milliseconds: (per.inMilliseconds / n).ceil());
      _gap = gap < Duration.zero ? Duration.zero : gap;
    } else {
      _gap = Duration.zero;
    }
  }

  Scheduler.unlimited() : this(0, Duration.zero);

  Future<R> run<R>(SchedulerTask<R> task) async {
    final result = _Result<R>();
    _queue.add(task);
    _resultMap[task.hashCode] = result;
    _loop();
    return result.future;
  }

  void _loop() async {
    if (_looping) return;
    await _loopCompleter.future;
    _loopCompleter = Completer();
    _looping = true;

    while (_queue.isNotEmpty) {
      if (_controller._pause) {
        await Future.delayed(const Duration(milliseconds: 50));
        continue;
      }

      SchedulerTask<dynamic> task = _queue.removeFirst();
      _Result<dynamic> result = _resultMap[task.hashCode]!;

      try {
        final value = await task.call(_controller);
        result._complete(value);
      } catch (e) {
        result._error(e);
      }

      await Future.delayed(_gap);
    }

    _loopCompleter.complete();
    _looping = false;
  }

  Future<void> wait() async {
    final results = List<_Result>.from(_resultMap.values);
    for (final r in results) {
      await r.future;
    }
  }
}

class _Result<R> {
  final Completer<R> _completer = Completer<R>();

  Future<R> get future => _completer.future;

  void _complete(R value) {
    _completer.complete(value);
  }

  void _error(Object error) {
    _completer.completeError(error);
  }
}

class SchedulerController {
  bool _pause = false;

  void pause() {
    _pause = true;
  }

  void resume() {
    _pause = false;
  }
}
