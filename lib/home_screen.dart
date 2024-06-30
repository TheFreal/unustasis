import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unustasis/control_screen.dart';
import 'package:unustasis/interfaces/components/icomoon.dart';
import 'package:unustasis/driving_screen.dart';
import 'package:unustasis/interfaces/phone/scooter_action_button.dart';
import 'package:unustasis/interfaces/phone/scooter_connect_button.dart';
import 'package:unustasis/interfaces/phone/scooter_control_button.dart';
import 'package:unustasis/interfaces/phone/scooter_power_button.dart';
import 'package:unustasis/interfaces/phone/scooter_seat_button.dart';
import 'package:unustasis/onboarding_screen.dart';
import 'package:unustasis/scooter_service.dart';
import 'package:unustasis/domain/scooter_state.dart';
import 'package:unustasis/scooter_visual.dart';
import 'package:unustasis/stats/stats_screen.dart';

class HomeScreen extends StatefulWidget {
  final ScooterService scooterService;
  final bool? forceOpen;
  const HomeScreen({
    required this.scooterService,
    this.forceOpen,
    super.key,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  ScooterState? _scooterState = ScooterState.disconnected;
  bool _connected = false;
  bool _scanning = false;
  bool? _seatClosed;
  bool? _handlebarsLocked;
  int? _primarySOC;
  int? _secondarySOC;
  int? color;

  @override
  void initState() {
    super.initState();
    setupColor();
    if (widget.forceOpen != true) {
      log("Redirecting or starting");
      redirectOrStart();
    }
    widget.scooterService.state.listen((state) {
      setState(() {
        _scooterState = state;
      });
    });
    widget.scooterService.connected.listen((isConnected) {
      setState(() {
        _connected = isConnected;
      });
    });
    widget.scooterService.scanning.listen((isScanning) {
      setState(() {
        _scanning = isScanning;
      });
      log("Scanning: $isScanning");
    });
    widget.scooterService.seatClosed.listen((isClosed) {
      setState(() {
        _seatClosed = isClosed;
      });
    });
    widget.scooterService.handlebarsLocked.listen((isLocked) {
      setState(() {
        _handlebarsLocked = isLocked;
      });
    });
    widget.scooterService.primarySOC.listen((soc) {
      setState(() {
        _primarySOC = soc;
      });
    });
    widget.scooterService.secondarySOC.listen((soc) {
      setState(() {
        _secondarySOC = soc;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.3,
            colors: [
              _scooterState?.isOn == true
                  ? HSLColor.fromColor(Theme.of(context).colorScheme.primary)
                      .withLightness(0.3)
                      .toColor()
                  : _connected
                      ? HSLColor.fromColor(
                              Theme.of(context).colorScheme.primary)
                          .withLightness(0.1)
                          .withSaturation(0.5)
                          .toColor()
                      : Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.onTertiary,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 40,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              children: [
                InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StatsScreen(
                        service: widget.scooterService,
                      ),
                    ),
                  ),
                  onLongPress: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DrivingScreen(
                        service: widget.scooterService,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(width: _connected ? 32 : 0),
                      StreamBuilder<String?>(
                          stream: widget.scooterService.scooterName,
                          builder: (context, name) {
                            return Text(
                              name.data ??
                                  FlutterI18n.translate(
                                      context, "stats_no_name"),
                              style: Theme.of(context).textTheme.headlineLarge,
                            );
                          }),
                      const SizedBox(width: 16),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                      ),
                    ],
                  ),
                ),
                Text(
                  _scanning &&
                          (_scooterState == null ||
                              _scooterState! == ScooterState.disconnected)
                      ? (widget.scooterService.savedScooters.isNotEmpty
                          ? FlutterI18n.translate(
                              context, "home_scanning_known")
                          : FlutterI18n.translate(context, "home_scanning"))
                      : ((_scooterState != null
                              ? _scooterState!.name(context)
                              : FlutterI18n.translate(
                                  context, "home_loading_state")) +
                          (_connected && _handlebarsLocked == false
                              ? FlutterI18n.translate(context, "home_unlocked")
                              : "")),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                if (_primarySOC != null)
                  StreamBuilder<DateTime?>(
                      stream: widget.scooterService.lastPing,
                      builder: (context, lastPing) {
                        bool dataIsOld = !lastPing.hasData ||
                            lastPing.hasData &&
                                lastPing.data!
                                        .difference(DateTime.now())
                                        .inMinutes
                                        .abs() >
                                    5;
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                                width: MediaQuery.of(context).size.width / 6,
                                child: LinearProgressIndicator(
                                  minHeight: 8,
                                  borderRadius: BorderRadius.circular(8),
                                  value: _primarySOC! / 100.0,
                                  color: dataIsOld
                                      ? Colors.grey
                                      : _primarySOC! < 15
                                          ? Colors.red
                                          : Theme.of(context)
                                              .colorScheme
                                              .primary,
                                )),
                            const SizedBox(width: 8),
                            Text("$_primarySOC%"),
                            if (_secondarySOC != null && _secondarySOC! > 0)
                              const VerticalDivider(),
                            if (_secondarySOC != null && _secondarySOC! > 0)
                              SizedBox(
                                  width: MediaQuery.of(context).size.width / 6,
                                  child: LinearProgressIndicator(
                                    minHeight: 8,
                                    borderRadius: BorderRadius.circular(8),
                                    value: _secondarySOC! / 100.0,
                                    color: dataIsOld
                                        ? Colors.grey
                                        : _secondarySOC! < 15
                                            ? Colors.red
                                            : Theme.of(context)
                                                .colorScheme
                                                .primary,
                                  )),
                            if (_secondarySOC != null && _secondarySOC! > 0)
                              const SizedBox(width: 8),
                            if (_secondarySOC != null && _secondarySOC! > 0)
                              Text("$_secondarySOC%"),
                          ],
                        );
                      }),
                const SizedBox(height: 16),
                Expanded(
                    child: ScooterVisual(
                        color: color,
                        state: _scooterState,
                        scanning: _scanning,
                        blinkerLeft: false, // TODO: extract ScooterBlinkerState
                        blinkerRight: false)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Expanded(
                      child: ScooterSeatButton(
                        scooterService: widget.scooterService,
                        connected: _connected,
                        scooterState: _scooterState,
                        seatClosed: _seatClosed,
                        scanning: _scanning,
                      ),
                    ),
                    ScooterPowerButtonContainer(
                        _scooterState, widget.scooterService),
                    Expanded(
                        child: _connected ? ScooterControlButton(widget.scooterService) :
                            ScooterConnectButton(widget.scooterService, _scanning)
                    )
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  void setupColor() {
    SharedPreferences.getInstance().then((prefs) {
      setState(() {
        color = prefs.getInt("color");
      });
    });
  }

  void showSeatWarning() {
    showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(FlutterI18n.translate(context, "seat_alert_title")),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(FlutterI18n.translate(context, "seat_alert_body")),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void redirectOrStart() async {
    List<String> ids = await widget.scooterService.getSavedScooterIds();
    log("Saved scooters: $ids");
    if ((await widget.scooterService.getSavedScooterIds()).isEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => OnboardingScreen(
            service: widget.scooterService,
          ),
        ),
      );
    } else {
      // check if we're not coming from onboarding
      if (widget.scooterService.myScooter == null) {
        widget.scooterService.start();
      }
    }
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (prefs.getBool("biometrics") ?? false) {
      widget.scooterService.optionalAuth = false;
      final LocalAuthentication auth = LocalAuthentication();
      try {
        final bool didAuthenticate = await auth.authenticate(
          localizedReason: FlutterI18n.translate(context, "biometrics_message"),
        );
        if (!didAuthenticate) {
          Fluttertoast.showToast(
              msg: FlutterI18n.translate(context, "biometrics_failed"));
          Navigator.of(context).pop();
          SystemNavigator.pop();
        } else {
          widget.scooterService.optionalAuth = true;
        }
      } catch (e) {
        Fluttertoast.showToast(
            msg: FlutterI18n.translate(context, "biometrics_failed"));
        Navigator.of(context).pop();
        SystemNavigator.pop();
      }
    } else {
      widget.scooterService.optionalAuth = true;
    }
  }
}