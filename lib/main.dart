// For performing some operations asynchronously
import 'dart:async';
import 'dart:convert';

// For using PlatformException
import 'package:flutter/services.dart';
// import 'package:nice_button/nice_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:custom_switch/custom_switch.dart';

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
          title: Text("My Home"),
          backgroundColor: Colors.black,
          actions: <Widget>[
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
        body: Container(
          constraints: BoxConstraints.expand(),
          decoration: BoxDecoration(
            image: DecorationImage(
              image: NetworkImage(
                  'data:image/jpeg;base64,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'),
              fit: BoxFit.cover,
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
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    // ),
                    CustomSwitch(
                      activeColor: Colors.black,
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
                                fontWeight: FontWeight.bold,
                                // fontFamily:
                              ),
                            ),
                            DropdownButton(
                              dropdownColor: Colors.orangeAccent,
                              items: _getDeviceItems(),
                              onChanged: (value) =>
                                  setState(() => _device = value),
                              value: _devicesList.isNotEmpty ? _device : null,
                            ),
                            RaisedButton(
                              color: Colors.black,
                              textColor: Colors.white,
                              onPressed: _isButtonUnavailable
                                  ? null
                                  : _connected
                                      ? _disconnect
                                      : _connect,
                              child:
                                  Text(_connected ? 'Disconnect' : 'Connect'),
                              elevation: 10,
                              hoverColor: Colors.blue,
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
                          shadowColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            side: new BorderSide(
                              color: _deviceState == 0
                                  ? colors['neutralBorderColor']
                                  : _deviceState == 1
                                      ? colors['onBorderColor']
                                      : colors['offBorderColor'],
                              width: 3,
                            ),
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          elevation: _deviceState == 0 ? 4 : 0,
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
                                              : colors['offTextColor'],
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
                          shadowColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            side: new BorderSide(
                              color: _deviceState == 0
                                  ? colors['neutralBorderColor']
                                  : _deviceState == 1
                                      ? colors['onBorderColor']
                                      : colors['offBorderColor'],
                              width: 3,
                            ),
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          elevation: _deviceState == 0 ? 4 : 0,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    "Fans",
                                    style: TextStyle(
                                      fontSize: 20,
                                      color: _deviceState == 0
                                          ? colors['neutralTextColor']
                                          : _deviceState == 1
                                              ? colors['onTextColor']
                                              : colors['offTextColor'],
                                    ),
                                  ),
                                ),
                                FlatButton(
                                  onPressed: _connected
                                      ? _sendOnMessageToBluetooth
                                      : null,
                                  child: Text("Spin"),
                                ),
                                FlatButton(
                                  onPressed: _connected
                                      ? _sendOffMessageToBluetooth
                                      : null,
                                  child: Text("Dont Spin"),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Card(
                          shadowColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            side: new BorderSide(
                              color: _deviceState == 0
                                  ? colors['neutralBorderColor']
                                  : _deviceState == 1
                                      ? colors['onBorderColor']
                                      : colors['offBorderColor'],
                              width: 3,
                            ),
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          elevation: _deviceState == 0 ? 4 : 0,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    "AC",
                                    style: TextStyle(
                                      fontSize: 20,
                                      color: _deviceState == 0
                                          ? colors['neutralTextColor']
                                          : _deviceState == 1
                                              ? colors['onTextColor']
                                              : colors['offTextColor'],
                                    ),
                                  ),
                                ),
                                FlatButton(
                                  onPressed: _connected
                                      ? _sendOnMessageToBluetooth
                                      : null,
                                  child: Text("Cool"),
                                ),
                                FlatButton(
                                  onPressed: _connected
                                      ? _sendOffMessageToBluetooth
                                      : null,
                                  child: Text("Hot"),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Card(
                          shadowColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            side: new BorderSide(
                              color: _deviceState == 0
                                  ? colors['neutralBorderColor']
                                  : _deviceState == 1
                                      ? colors['onBorderColor']
                                      : colors['offBorderColor'],
                              width: 3,
                            ),
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          elevation: _deviceState == 0 ? 4 : 0,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    "Music",
                                    style: TextStyle(
                                      fontSize: 20,
                                      color: _deviceState == 0
                                          ? colors['neutralTextColor']
                                          : _deviceState == 1
                                              ? colors['onTextColor']
                                              : colors['offTextColor'],
                                    ),
                                  ),
                                ),
                                FlatButton(
                                  onPressed: _connected
                                      ? _sendOnMessageToBluetooth
                                      : null,
                                  child: Text("Rock"),
                                ),
                                FlatButton(
                                  onPressed: _connected
                                      ? _sendOffMessageToBluetooth
                                      : null,
                                  child: Text("Roll"),
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
                          alignment: Alignment.bottomCenter,
                          child: RaisedButton(
                            color: Colors.black,
                            textColor: Colors.white,
                            elevation: 10,
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(10.0))),
                            child: Text("BT Settings"),
                            onPressed: () {
                              FlutterBluetoothSerial.instance.openSettings();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
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

  // void _onDataReceived(Uint8List data) {
  //   // Allocate buffer for parsed data
  //   int backspacesCounter = 0;
  //   data.forEach((byte) {
  //     if (byte == 8 || byte == 127) {
  //       backspacesCounter++;
  //     }
  //   });
  //   Uint8List buffer = Uint8List(data.length - backspacesCounter);
  //   int bufferIndex = buffer.length;

  //   // Apply backspace control character
  //   backspacesCounter = 0;
  //   for (int i = data.length - 1; i >= 0; i--) {
  //     if (data[i] == 8 || data[i] == 127) {
  //       backspacesCounter++;
  //     } else {
  //       if (backspacesCounter > 0) {
  //         backspacesCounter--;
  //       } else {
  //         buffer[--bufferIndex] = data[i];
  //       }
  //     }
  //   }
  // }

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
    connection.output.add(utf8.encode("1" + "\r\n"));
    await connection.output.allSent;
    show('Device Turned On');
    setState(() {
      _deviceState = 1; // device on
    });
  }

  // Method to send message,
  // for turning the Bluetooth device off
  void _sendOffMessageToBluetooth() async {
    connection.output.add(utf8.encode("0" + "\r\n"));
    await connection.output.allSent;
    show('Device Turned Off');
    setState(() {
      _deviceState = -1; // device off
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
