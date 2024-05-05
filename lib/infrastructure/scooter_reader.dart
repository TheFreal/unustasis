import 'dart:developer';

import 'package:rxdart/rxdart.dart';
import 'package:unustasis/infrastructure/characteristic_repository.dart';
import 'package:unustasis/infrastructure/state_of_charge_reader.dart';
import 'package:unustasis/infrastructure/string_reader.dart';

import '../domain/scooter_power_state.dart';
import '../domain/scooter_state.dart';
import 'battery_reader.dart';

class ScooterReader {
  final CharacteristicRepository _characteristicRepository;
  String? _state, _powerState;

  final BehaviorSubject<ScooterState?> _stateController;
  final BehaviorSubject<bool?> _seatClosedController;
  final BehaviorSubject<bool?> _handlebarController;
  final BehaviorSubject<DateTime?> _lastPingController;
  final BehaviorSubject<int?> _auxSOCController;
  final BehaviorSubject<int?> _cbbSOCController;
  final BehaviorSubject<bool?> _cbbChargingController;
  final BehaviorSubject<int?> _primarySOCController;
  final BehaviorSubject<int?> _secondarySOCController;
  final BehaviorSubject<int?> _primaryCyclesController;
  final BehaviorSubject<int?> _secondaryCyclesController;

  ScooterReader(
      {required CharacteristicRepository characteristicRepository,
      required BehaviorSubject<ScooterState?> stateController,
      required BehaviorSubject<bool?> seatClosedController,
      required BehaviorSubject<bool?> handlebarController,
      required BehaviorSubject<DateTime?> lastPingController,
      required BehaviorSubject<int?> auxSOCController,
      required BehaviorSubject<int?> cbbSOCController,
      required BehaviorSubject<bool?> cbbChargingController,
      required BehaviorSubject<int?> primarySOCController,
      required BehaviorSubject<int?> secondarySOCController,
      required BehaviorSubject<int?> primaryCyclesController,
      required BehaviorSubject<int?> secondaryCyclesController})
      : _characteristicRepository = characteristicRepository,
        _stateController = stateController,
        _seatClosedController = seatClosedController,
        _handlebarController = handlebarController,
        _lastPingController = lastPingController,
        _auxSOCController = auxSOCController,
        _cbbSOCController = cbbSOCController,
        _cbbChargingController = cbbChargingController,
        _primarySOCController = primarySOCController,
        _secondarySOCController = secondarySOCController,
        _primaryCyclesController = primaryCyclesController,
        _secondaryCyclesController = secondaryCyclesController;

  readAndSubscribe() {
    // subscribe to a bunch of values
    StringReader("State", _characteristicRepository.stateCharacteristic!)
        .readAndSubscribe((String value) {
      _state = value;
      _updateScooterState();
    });

    // Subscribe to power state for correct hibernation
    StringReader(
            "Power State", _characteristicRepository.powerStateCharacteristic!)
        .readAndSubscribe((String value) {
      _powerState = value;
      _updateScooterState();
    });

    StringReader("Seat", _characteristicRepository.seatCharacteristic!)
        .readAndSubscribe((String seatState) {
      _seatClosedController.add(seatState != "open");
    });

    StringReader(
            "Handlebars", _characteristicRepository.handlebarCharacteristic!)
        .readAndSubscribe((String handlebarState) {
      _handlebarController.add(handlebarState != "unlocked");
    });

    StateOfChargeReader("aux", _characteristicRepository.auxSOCCharacteristic,
            _auxSOCController, _lastPingController)
        .readAndSubscribe();

    StateOfChargeReader("cbb", _characteristicRepository.cbbSOCCharacteristic,
            _cbbSOCController, _lastPingController)
        .readAndSubscribe();

    StringReader("CBB charging",
            _characteristicRepository.cbbChargingCharacteristic!)
        .readAndSubscribe((String chargingState) {
      if (chargingState == "charging") {
        _cbbChargingController.add(true);
      } else if (chargingState == "not-charging") {
        _cbbChargingController.add(false);
      }
    });

    var primaryBatterReader = BatteryReader(
        "primary",
        _characteristicRepository.primaryCyclesCharacteristic,
        _characteristicRepository.primarySOCCharacteristic,
        _lastPingController);
    primaryBatterReader.readAndSubscribe(
        _primarySOCController, _primaryCyclesController);

    var secondaryBatteryReader = BatteryReader(
        "secondary",
        _characteristicRepository.secondaryCyclesCharacteristic,
        _characteristicRepository.secondarySOCCharacteristic,
        _lastPingController);
    secondaryBatteryReader.readAndSubscribe(
        _secondarySOCController, _secondaryCyclesController);
  }

  Future<void> _updateScooterState() async {
    log("Update scooter state from state: '$_state' and power state: '$_powerState'");
    if (_state != null && _powerState != null) {
      ScooterPowerState powerState = ScooterPowerState.fromString(_powerState);
      ScooterState newState =
          ScooterState.fromStateAndPowerState(_state!, powerState);
      _stateController.add(newState);
    }
  }
}