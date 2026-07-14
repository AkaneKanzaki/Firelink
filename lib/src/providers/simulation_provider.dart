import 'dart:async';
import 'package:flutter/material.dart';
import '../models/device.dart';
import '../models/connection.dart';
import '../core/enums/acl_enums.dart';
import '../services/network_engine.dart';

/// Manages simulation state: running packets, console output, and animation.
class SimulationProvider extends ChangeNotifier {
  final List<String> _consoleOutput = [];
  final List<List<SimulationStep>> _groupedSteps = [];

  bool _isSimulating = false;
  PingResult? _lastResult;

  int _currentStepIndex = -1;
  Timer? _playbackTimer;

  // To progressively reveal console output
  List<String> _pendingConsoleOutput = [];

  // ─── Getters ──────────────────────────────────────────────────

  List<String> get consoleOutput => List.unmodifiable(_consoleOutput);
  List<List<SimulationStep>> get groupedSteps =>
      List.unmodifiable(_groupedSteps);
  bool get isSimulating => _isSimulating;
  PingResult? get lastResult => _lastResult;
  int get currentStepIndex => _currentStepIndex;

  // ─── Actions ──────────────────────────────────────────────────

  /// Simulates a ping from one device to a destination IP.
  PingResult runPing({
    required String sourceDeviceId,
    required String destIp,
    required List<NetworkDevice> devices,
    required List<Connection> connections,
  }) {
    // Cancel any existing animation
    _playbackTimer?.cancel();

    _isSimulating = true;
    _groupedSteps.clear();
    _consoleOutput.clear();
    _currentStepIndex = -1;
    notifyListeners();

    final engine = NetworkEngine(devices: devices, connections: connections);

    late PingResult result;
    try {
      result = engine.simulatePing(sourceDeviceId, destIp);
    } catch (_) {
      result = PingResult(
        success: false,
        sourceIp: '',
        destIp: destIp,
        steps: [],
        consoleOutput: [],
      );
    }
    _lastResult = result;

    // Group steps by tick
    final Map<int, List<SimulationStep>> tickMap = {};
    for (var step in result.steps) {
      tickMap.putIfAbsent(step.tick, () => []).add(step);
    }
    final sortedTicks = tickMap.keys.toList()..sort();
    for (var tick in sortedTicks) {
      _groupedSteps.add(tickMap[tick]!);
    }

    _pendingConsoleOutput = List.from(result.consoleOutput);
    _pendingConsoleOutput.add(''); // Blank line separator

    // Add initial setup lines immediately (before the first step)
    // The first 2 lines are usually "Pinging X from Y:" and an empty line
    if (_pendingConsoleOutput.isNotEmpty) {
      _consoleOutput.add(_pendingConsoleOutput.removeAt(0));
      if (_pendingConsoleOutput.isNotEmpty &&
          _pendingConsoleOutput.first.isEmpty) {
        _consoleOutput.add(_pendingConsoleOutput.removeAt(0));
      }
    }

    notifyListeners();

    // Start playback
    if (_groupedSteps.isNotEmpty || _pendingConsoleOutput.isNotEmpty) {
      _playbackTimer = Timer.periodic(const Duration(milliseconds: 800), (
        timer,
      ) {
        bool updated = false;

        if (_currentStepIndex < _groupedSteps.length - 1) {
          _currentStepIndex++;
          updated = true;

          if (_pendingConsoleOutput.isNotEmpty) {
            int remainingSteps = _groupedSteps.length - _currentStepIndex;
            int linesToTake = remainingSteps > 0 ? (_pendingConsoleOutput.length / remainingSteps).ceil() : _pendingConsoleOutput.length;
            for (int i = 0; i < linesToTake && _pendingConsoleOutput.isNotEmpty; i++) {
              _consoleOutput.add(_pendingConsoleOutput.removeAt(0));
            }
          }
        } else {
          if (_pendingConsoleOutput.isNotEmpty) {
            _consoleOutput.addAll(_pendingConsoleOutput);
            _pendingConsoleOutput.clear();
          }
          if (_currentStepIndex < _groupedSteps.length) {
            _currentStepIndex++;
          }
          _isSimulating = false;
          timer.cancel();
          _playbackTimer?.cancel();
          updated = true;
        }

        if (updated) {
          notifyListeners();
        }
      });
    } else {
      _isSimulating = false;
      notifyListeners();
    }

    return result;
  }

  /// Runs a custom PDU simulation.
  PingResult runCustomPdu({
    required String sourceDeviceId,
    required String destIp,
    required AclProtocol protocol,
    required List<NetworkDevice> devices,
    required List<Connection> connections,
  }) {
    _playbackTimer?.cancel();

    _isSimulating = true;
    _groupedSteps.clear();
    _consoleOutput.clear();
    _currentStepIndex = -1;
    notifyListeners();

    final engine = NetworkEngine(devices: devices, connections: connections);

    final result = engine.simulateCustomPdu(sourceDeviceId, destIp, protocol);
    _lastResult = result;

    final Map<int, List<SimulationStep>> tickMap = {};
    for (var step in result.steps) {
      tickMap.putIfAbsent(step.tick, () => []).add(step);
    }
    final sortedTicks = tickMap.keys.toList()..sort();
    for (var tick in sortedTicks) {
      _groupedSteps.add(tickMap[tick]!);
    }

    _pendingConsoleOutput = List.from(result.consoleOutput);
    _pendingConsoleOutput.add('');

    if (_pendingConsoleOutput.isNotEmpty) {
      _consoleOutput.add(_pendingConsoleOutput.removeAt(0));
      if (_pendingConsoleOutput.isNotEmpty) {
        _consoleOutput.add(_pendingConsoleOutput.removeAt(0));
      }
    }

    notifyListeners();

    // Start playback
    if (_groupedSteps.isNotEmpty || _pendingConsoleOutput.isNotEmpty) {
      _playbackTimer = Timer.periodic(const Duration(milliseconds: 800), (
        timer,
      ) {
        bool updated = false;

        if (_currentStepIndex < _groupedSteps.length - 1) {
          _currentStepIndex++;
          updated = true;

          if (_pendingConsoleOutput.isNotEmpty) {
            int remainingSteps = _groupedSteps.length - _currentStepIndex;
            int linesToTake = remainingSteps > 0 ? (_pendingConsoleOutput.length / remainingSteps).ceil() : _pendingConsoleOutput.length;
            for (int i = 0; i < linesToTake && _pendingConsoleOutput.isNotEmpty; i++) {
              _consoleOutput.add(_pendingConsoleOutput.removeAt(0));
            }
          }
        } else {
          if (_pendingConsoleOutput.isNotEmpty) {
            _consoleOutput.addAll(_pendingConsoleOutput);
            _pendingConsoleOutput.clear();
          }
          if (_currentStepIndex < _groupedSteps.length) {
            _currentStepIndex++;
          }
          _isSimulating = false;
          timer.cancel();
          _playbackTimer?.cancel();
          updated = true;
        }

        if (updated) {
          notifyListeners();
        }
      });
    } else {
      _isSimulating = false;
      notifyListeners();
    }

    return result;
  }

  /// Runs a DHCP request simulation.
  /// Returns a Future that resolves when the animation finishes,
  /// yielding the DhcpResult.
  Future<DhcpResult> startDhcpRequest({
    required String sourceDeviceId,
    required String interfaceName,
    required List<NetworkDevice> devices,
    required List<Connection> connections,
  }) {
    final completer = Completer<DhcpResult>();

    // Cancel any existing animation
    _playbackTimer?.cancel();

    _isSimulating = true;
    _groupedSteps.clear();
    _consoleOutput.clear();
    _currentStepIndex = -1;
    notifyListeners();

    final engine = NetworkEngine(devices: devices, connections: connections);

    final result = engine.simulateDhcpRequest(sourceDeviceId, interfaceName);

    // Group steps by tick
    final Map<int, List<SimulationStep>> tickMap = {};
    for (var step in result.steps) {
      tickMap.putIfAbsent(step.tick, () => []).add(step);
    }
    final sortedTicks = tickMap.keys.toList()..sort();
    for (var tick in sortedTicks) {
      _groupedSteps.add(tickMap[tick]!);
    }

    _pendingConsoleOutput = List.from(result.consoleOutput);

    if (_pendingConsoleOutput.isNotEmpty) {
      _consoleOutput.add(_pendingConsoleOutput.removeAt(0));
    }

    notifyListeners();

    if (_groupedSteps.isNotEmpty || _pendingConsoleOutput.isNotEmpty) {
      _playbackTimer = Timer.periodic(const Duration(milliseconds: 800), (
        timer,
      ) {
        bool updated = false;

        if (_currentStepIndex < _groupedSteps.length - 1) {
          _currentStepIndex++;
          updated = true;

          if (_pendingConsoleOutput.isNotEmpty) {
            int remainingSteps = _groupedSteps.length - _currentStepIndex;
            int linesToTake = remainingSteps > 0 ? (_pendingConsoleOutput.length / remainingSteps).ceil() : _pendingConsoleOutput.length;
            for (int i = 0; i < linesToTake && _pendingConsoleOutput.isNotEmpty; i++) {
              _consoleOutput.add(_pendingConsoleOutput.removeAt(0));
            }
          }
        } else {
          if (_pendingConsoleOutput.isNotEmpty) {
            _consoleOutput.addAll(_pendingConsoleOutput);
            _pendingConsoleOutput.clear();
          }
          if (_currentStepIndex < _groupedSteps.length) {
            _currentStepIndex++;
          }
          _isSimulating = false;
          timer.cancel();
          _playbackTimer?.cancel();
          updated = true;
          if (!completer.isCompleted) completer.complete(result);
        }

        if (updated) {
          notifyListeners();
        }
      });
    } else {
      _isSimulating = false;
      notifyListeners();
      if (!completer.isCompleted) completer.complete(result);
    }

    return completer.future;
  }

  /// Adds a raw line to the console output immediately.
  void addConsoleOutput(String line) {
    _consoleOutput.add(line);
    notifyListeners();
  }

  /// Clears the console output and stops any running simulation.
  void clearConsole() {
    _playbackTimer?.cancel();
    _isSimulating = false;
    _consoleOutput.clear();
    _groupedSteps.clear();
    _currentStepIndex = -1;
    _pendingConsoleOutput.clear();
    _lastResult = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }
}
