// For performing some operations asynchronously
import 'dart:async';
import 'dart:convert';

// For using PlatformException
import 'package:flutter/services.dart';
// import 'package:nice_button/nice_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:wifi_iot/wifi_iot.dart';
// import 'package:animated_splash/animated_splash.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WellBaked Tech',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: BluetoothApp(),
    );
  }
}

class BluetoothApp extends StatefulWidget {
  @override
  _BluetoothAppState createState() => _BluetoothAppState();
}

class _BluetoothAppState extends State<BluetoothApp> {
  // Initializing the Bluetooth connection state to be unknown
  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;
  // Initializing a global key, as it would help us in showing a SnackBar later
  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();
  // Get the instance of the Bluetooth
  FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;
  // Track the Bluetooth connection with the remote device
  BluetoothConnection connection;

  int _deviceState;

  bool isDisconnecting = false;

  Map<String, Color> colors = {
    'onBorderColor': Colors.green,
    'offBorderColor': Colors.red,
    'neutralBorderColor': Colors.transparent,
    'onTextColor': Colors.green[700],
    'offTextColor': Colors.red[700],
    'neutralTextColor': Colors.orangeAccent,
  };

  // To track whether the device is still connected to Bluetooth
  bool get isConnected => connection != null && connection.isConnected;

  // Define some variables, which will be required later
  List<BluetoothDevice> _devicesList = [];
  BluetoothDevice _device;
  bool _connected = false;
  bool _isButtonUnavailable = false;

  @override
  void initState() {
    super.initState();

    // Get current state
    FlutterBluetoothSerial.instance.state.then((state) {
      setState(() {
        _bluetoothState = state;
      });
    });

    _deviceState = 0; // neutral

    // If the bluetooth of the device is not enabled,
    // then request permission to turn on bluetooth
    // as the app starts up
    enableBluetooth();

    // Listen for further state changes
    FlutterBluetoothSerial.instance
        .onStateChanged()
        .listen((BluetoothState state) {
      setState(() {
        _bluetoothState = state;
        if (_bluetoothState == BluetoothState.STATE_OFF) {
          _isButtonUnavailable = true;
        }
        getPairedDevices();
      });
    });
  }

  @override
  void dispose() {
    // Avoid memory leak and disconnect
    if (isConnected) {
      isDisconnecting = true;
      connection.dispose();
      connection = null;
    }

    super.dispose();
  }

  // Request Bluetooth permission from the user
  Future<void> enableBluetooth() async {
    // Retrieving the current Bluetooth state
    _bluetoothState = await FlutterBluetoothSerial.instance.state;

    // If the bluetooth is off, then turn it on first
    // and then retrieve the devices that are paired.
    if (_bluetoothState == BluetoothState.STATE_OFF) {
      await FlutterBluetoothSerial.instance.requestEnable();
      await getPairedDevices();
      return true;
    } else {
      await getPairedDevices();
    }
    return false;
  }

  // For retrieving and storing the paired devices
  // in a list.
  Future<void> getPairedDevices() async {
    List<BluetoothDevice> devices = [];

    // To get the list of paired devices
    try {
      devices = await _bluetooth.getBondedDevices();
    } on PlatformException {
      print("Error");
    }

    // It is an error to call [setState] unless [mounted] is true.
    if (!mounted) {
      return;
    }

    // Store the [devices] list in the [_devicesList] for accessing
    // the list outside this class
    setState(() {
      _devicesList = devices;
    });
  }

  // Now, its time to build the UI
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              IconButton(
                icon: Image.asset('assets/images/home.png'),
                onPressed: () => {},
              ),
              Text("WBT Future-Home       "),
              FlatButton.icon(
                icon: Icon(
                  Icons.refresh,
                  color: Colors.white,
                ),
                label: Text(
                  "Refresh",
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                splashColor: Colors.deepPurple,
                onPressed: () async {
                  // So, that when new devices are paired
                  // while the app is running, user can refresh
                  // the paired devices list.
                  await getPairedDevices().then((_) {
                    show('Device list refreshed');
                  });
                },
              ),
            ],
          ),
        ),
        body: Container(
          constraints: BoxConstraints.expand(),
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/bg.gif'),
              fit: BoxFit.fitHeight,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: <Widget>[
              Visibility(
                visible: _isButtonUnavailable &&
                    _bluetoothState == BluetoothState.STATE_ON,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.yellow,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    // Flexible(
                    //   fit: FlexFit.tight,
                    Text(
                      'Bluetooth',
                      style: TextStyle(
                        color: Colors.orangeAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    // ),
                    Switch(
                      activeColor: Colors.orangeAccent,
                      value: _bluetoothState.isEnabled,
                      onChanged: (bool value) {
                        future() async {
                          if (value) {
                            await FlutterBluetoothSerial.instance
                                .requestEnable();
                          } else {
                            await FlutterBluetoothSerial.instance
                                .requestDisable();
                          }

                          await getPairedDevices();
                          _isButtonUnavailable = false;

                          if (_connected) {
                            _disconnect();
                          }
                        }

                        future().then((_) {
                          setState(() {});
                        });
                      },
                    )
                  ],
                ),
              ),
              Stack(
                children: <Widget>[
                  Column(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text(
                              'Device:',
                              style: TextStyle(
                                color: Colors.orangeAccent,
                                fontWeight: FontWeight.bold,
                                // fontFamily:
                              ),
                            ),
                            DropdownButton(
                              style: TextStyle(
                                color: Colors.white,
                              ),
                              dropdownColor: Colors.orangeAccent,
                              items: _getDeviceItems(),
                              onChanged: (value) =>
                                  setState(() => _device = value),
                              value: _devicesList.isNotEmpty ? _device : null,
                            ),
                            RaisedButton(
                              color: Color.fromRGBO(128, 128, 128, 0.5),

                              textColor: Colors.orangeAccent,
                              onPressed: _isButtonUnavailable
                                  ? null
                                  : _connected
                                      ? _disconnect
                                      : _connect,
                              child:
                                  Text(_connected ? 'Disconnect' : 'Connect'),
                              elevation: 10,
                              // hoverColor: Colors.,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(10.0))),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Card(
                          color: Colors.transparent,
                          shadowColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            side: new BorderSide(
                              color: _deviceState == 0
                                  ? colors['neutralBorderColor']
                                  : _deviceState == 1
                                      ? colors['onBorderColor']
                                      : colors['neutralBorderColor'],
                              width: 3,
                            ),
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          elevation: _deviceState == 0 ? 4 : 5,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    "Lights",
                                    style: TextStyle(
                                      fontSize: 20,
                                      color: _deviceState == 0
                                          ? colors['neutralTextColor']
                                          : _deviceState == 1
                                              ? colors['onTextColor']
                                              : colors['neutralTextColor'],
                                    ),
                                  ),
                                ),
                                FlatButton(
                                  onPressed: _connected
                                      ? _sendOnMessageToBluetooth
                                      : null,
                                  child: Text("IN"),
                                ),
                                FlatButton(
                                  onPressed: _connected
                                      ? _sendOffMessageToBluetooth
                                      : null,
                                  child: Text("OUT"),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Card(
                          color: Colors.transparent,
                          shadowColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            side: new BorderSide(
                              color: _deviceState == 2
                                  ? colors['neutralBorderColor']
                                  : _deviceState == 3
                                      ? colors['onBorderColor']
                                      : colors['neutralBorderColor'],
                              width: 3,
                            ),
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          elevation: _deviceState == 2 ? 4 : 5,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    "Fans",
                                    style: TextStyle(
                                      fontSize: 20,
                                      color: _deviceState == 2
                                          ? colors['neutralTextColor']
                                          : _deviceState == 3
                                              ? colors['onTextColor']
                                              : colors['neutralTextColor'],
                                    ),
                                  ),
                                ),
                                FlatButton(
                                  onPressed: _connected
                                      ? _sendOnMessageToBluetooth1
                                      : null,
                                  child: Text("Spin"),
                                ),
                                FlatButton(
                                  onPressed: _connected
                                      ? _sendOffMessageToBluetooth1
                                      : null,
                                  child: Text("Stop"),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Card(
                          color: Colors.transparent,
                          shadowColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            side: new BorderSide(
                              color: _deviceState == 4
                                  ? colors['neutralBorderColor']
                                  : _deviceState == 5
                                      ? colors['onBorderColor']
                                      : colors['neutralBorderColor'],
                              width: 3,
                            ),
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          elevation: _deviceState == 4 ? 4 : 5,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    "Disco",
                                    style: TextStyle(
                                      fontSize: 20,
                                      color: _deviceState == 4
                                          ? colors['neutralTextColor']
                                          : _deviceState == 5
                                              ? colors['onTextColor']
                                              : colors['neutralTextColor'],
                                    ),
                                  ),
                                ),
                                FlatButton(
                                  onPressed: _connected
                                      ? _sendOnMessageToBluetooth2
                                      : null,
                                  child: Text("Night"),
                                ),
                                FlatButton(
                                  onPressed: _connected
                                      ? _sendOffMessageToBluetooth2
                                      : null,
                                  child: Text("Day"),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Card(
                          color: Colors.transparent,
                          shadowColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            side: new BorderSide(
                              color: _deviceState == 6
                                  ? colors['neutralBorderColor']
                                  : _deviceState == 7
                                      ? colors['onBorderColor']
                                      : colors['neutralBorderColor'],
                              width: 3,
                            ),
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          elevation: _deviceState == 6 ? 4 : 5,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    "Bar-Mode",
                                    style: TextStyle(
                                      fontSize: 20,
                                      color: _deviceState == 6
                                          ? colors['neutralTextColor']
                                          : _deviceState == 7
                                              ? colors['onTextColor']
                                              : colors['neutralTextColor'],
                                    ),
                                  ),
                                ),
                                FlatButton(
                                  onPressed: _connected
                                      ? _sendOnMessageToBluetooth3
                                      : null,
                                  child: Text("IN"),
                                ),
                                FlatButton(
                                  onPressed: _connected
                                      ? _sendOffMessageToBluetooth3
                                      : null,
                                  child: Text("OUT"),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        // SizedBox(height: 80),
                        Align(
                          alignment: Alignment.center,
                          child: RaisedButton(
                            color: Color.fromRGBO(128, 128, 128, 0.8),
                            textColor: Colors.orangeAccent,
                            elevation: 10,
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(10.0))),
                            child: Text("Lights Out"),
                            onPressed: _sendOffMessageToBluetooth4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Create the List of devices to be shown in Dropdown Menu
  List<DropdownMenuItem<BluetoothDevice>> _getDeviceItems() {
    List<DropdownMenuItem<BluetoothDevice>> items = [];
    if (_devicesList.isEmpty) {
      items.add(DropdownMenuItem(
        child: Text('NONE'),
      ));
    } else {
      _devicesList.forEach((device) {
        items.add(DropdownMenuItem(
          child: Text(device.name),
          value: device,
        ));
      });
    }
    return items;
  }

  // Method to connect to bluetooth
  void _connect() async {
    setState(() {
      _isButtonUnavailable = true;
    });
    if (_device == null) {
      show('No device selected');
    } else {
      if (!isConnected) {
        await BluetoothConnection.toAddress(_device.address)
            .then((_connection) {
          print('Connected to the device');
          connection = _connection;
          setState(() {
            _connected = true;
          });

          connection.input.listen(null).onDone(() {
            if (isDisconnecting) {
              print('Disconnecting locally!');
            } else {
              print('Disconnected remotely!');
            }
            if (this.mounted) {
              setState(() {});
            }
          });
        }).catchError((error) {
          print('Cannot connect, exception occurred');
          print(error);
        });
        show('Device connected');

        setState(() => _isButtonUnavailable = false);
      }
    }
  }

  // Method to disconnect bluetooth
  void _disconnect() async {
    setState(() {
      _isButtonUnavailable = true;
      _deviceState = 0;
    });

    await connection.close();
    show('Device disconnected');
    if (!connection.isConnected) {
      setState(() {
        _connected = false;
        _isButtonUnavailable = false;
      });
    }
  }

  // Method to send message,
  // for turning the Bluetooth device on
  void _sendOnMessageToBluetooth() async {
    connection.output.add(utf8.encode("1"));
    await connection.output.allSent;
    // show('Device Turned On');
    setState(() {
      _deviceState = 1; // device on
    });
  }

  // Method to send message,
  // for turning the Bluetooth device off
  void _sendOffMessageToBluetooth() async {
    connection.output.add(utf8.encode("0"));
    await connection.output.allSent;
    // show('Device Turned Off');
    setState(() {
      _deviceState = 0; // device off
    });
  }

  void _sendOnMessageToBluetooth1() async {
    connection.output.add(utf8.encode("3"));
    await connection.output.allSent;
    // show('Device Turned On');
    setState(() {
      _deviceState = 3; // device on
    });
  }

  // Method to send message,
  // for turning the Bluetooth device off
  void _sendOffMessageToBluetooth1() async {
    connection.output.add(utf8.encode("2"));
    await connection.output.allSent;
    // show('Device Turned Off');
    setState(() {
      _deviceState = 2; // device off
    });
  }

  void _sendOnMessageToBluetooth2() async {
    connection.output.add(utf8.encode("5"));
    await connection.output.allSent;
    // show('Device Turned On');
    setState(() {
      _deviceState = 5; // device on
    });
  }

  // Method to send message,
  // for turning the Bluetooth device off
  void _sendOffMessageToBluetooth2() async {
    connection.output.add(utf8.encode("4"));
    await connection.output.allSent;
    // show('Device Turned Off');
    setState(() {
      _deviceState = 4; // device off
    });
  }

  void _sendOnMessageToBluetooth3() async {
    connection.output.add(utf8.encode("7"));
    await connection.output.allSent;
    // show('Device Turned On');
    setState(() {
      _deviceState = 7; // device on
    });
  }

  // Method to send message,
  // for turning the Bluetooth device off
  void _sendOffMessageToBluetooth3() async {
    connection.output.add(utf8.encode("6" + "\r\n"));
    await connection.output.allSent;
    // show('Device Turned Off');
    setState(() {
      _deviceState = 6; // device off
    });
  }

  void _sendOffMessageToBluetooth4() async {
    connection.output.add(utf8.encode("8" + "\r\n"));
    await connection.output.allSent;
    // show('Device Turned Off');
    setState(() {
      _deviceState = 8; // device off
    });
  }

  // Method to show a Snackbar,
  // taking message as the text
  Future show(
    String message, {
    Duration duration: const Duration(seconds: 3),
  }) async {
    await new Future.delayed(new Duration(milliseconds: 100));
    _scaffoldKey.currentState.showSnackBar(
      new SnackBar(
        content: new Text(
          message,
        ),
        duration: duration,
      ),
    );
  }
}
