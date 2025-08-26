import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import 'package:tcp_socket_connection/tcp_socket_connection.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ball Blaster Pro',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        //useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff00C1D4),
          primary: const Color(0xff00C1D4),
        ),
        fontFamily: 'Poppins',
      ),
      home: const MyHomePage(title: 'Ball Blaster Pro'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  TcpSocketConnection socketConnection = TcpSocketConnection("192.168.4.1", 80);

  MotorPairConfig shootMotor = MotorPairConfig();
  MotorPairConfig intakeMotor = MotorPairConfig();
  MotorPairConfig driveMotor = MotorPairConfig();

  void calculateMotorSpeed(StickDragDetails details) {
    setState(() {
      driveMotor.leftSpeed = ((details.y - details.x) * 1447); // 1447 = (2^11-1) * 2^0.5
      driveMotor.rightSpeed = ((details.y + details.x) * 1447);
    });
  }

  Uint8List tcpMessage = Uint8List(16);

  String message = "";

  //receiving and sending back a custom message
  void messageReceived(String msg) {
    setState(() {
      message = msg;
    });
    //socketConnection.sendMessage("MessageIsReceived :D ");
  }

  //starting the connection and listening to the socket asynchronously
  void startConnection() async {
    socketConnection.enableConsolePrint(
        true); //use this to see in the console what's happening
    if (await socketConnection.canConnect(5000, attempts: 3)) {
      //check if it's possible to connect to the endpoint
      await socketConnection.connect(5000, messageReceived, attempts: 3);
    }
  }

  @override
  void initState() {
    super.initState();
    shootMotor.name = "Shooting Motor";
    shootMotor.min = -50;
    shootMotor.max = 64 ; // 127;
    intakeMotor.name = "Intake Motor";
    intakeMotor.min = -2048;
    intakeMotor.max = 2047;
    startConnection();
  }

  @override
  Widget build(BuildContext context) {
    tcpMessage.buffer.asByteData().setInt8(0, 0x64); // s
    tcpMessage.buffer.asByteData().setInt8(1, shootMotor.enabled ? shootMotor.leftSpeed.toInt() : 0);
    tcpMessage.buffer.asByteData().setInt8(2, shootMotor.enabled ? shootMotor.leftSpeed.toInt() : 0);
    tcpMessage.buffer
        .asByteData()
        .setInt16(3, driveMotor.leftSpeed.toInt(), Endian.little);
    tcpMessage.buffer
        .asByteData()
        .setInt16(5, driveMotor.rightSpeed.toInt(), Endian.little);
    tcpMessage.buffer
        .asByteData()
        .setInt16(7, intakeMotor.enabled ? intakeMotor.leftSpeed.toInt() : 0, Endian.little);
    tcpMessage.buffer
        .asByteData()
        .setInt16(9, intakeMotor.enabled ? intakeMotor.leftSpeed.toInt() : 0, Endian.little);
    tcpMessage.buffer.asByteData().setInt8(11, 0);
    tcpMessage.buffer.asByteData().setInt8(12, 0);
    tcpMessage.buffer.asByteData().setInt8(13, 0);
    tcpMessage.buffer.asByteData().setInt8(14, 0);
    tcpMessage.buffer.asByteData().setInt8(15, 0);

    socketConnection.server?.add(tcpMessage);

    // if (socketConnection.isConnected()) {
    //   socketConnection.sendMessage(String.fromCharCodes(tcpMessage));
    // }
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          MotorPair(shootMotor, setState),
          MotorPair(intakeMotor, setState),
          FittedBox(
            fit: BoxFit.fitWidth,
            child: Card(
              child: Column(children: [
                const Text("Driving Motors"),
                Joystick(listener: calculateMotorSpeed)
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class MotorPairConfig {
  String name = "";
  double leftSpeed = 0;
  double rightSpeed = 0;
  bool enabled = false;
  bool synchronos = true;
  double min = 0;
  double max = 1;
}

class MotorPair extends StatelessWidget {
  final MotorPairConfig config;
  final Function _state;

  const MotorPair(this.config, this._state);

  @override
  Widget build(BuildContext context) {
    return Card(
        child: Column(
      children: [
        Text(config.name),
        Row(children: [
          const Text("Enable:"),
          Checkbox(
              value: config.enabled,
              onChanged: (checked) => _state(() => config.enabled = checked!)),
          const Text("Sync Motors:"),
          Checkbox(
              value: config.synchronos,
              onChanged: (checked) =>
                  _state(() => config.synchronos = checked!)),
        ]),
        Slider(
          value: config.leftSpeed,
          min: config.min,
          max: config.max,
          label: config.leftSpeed.toString(),
          onChanged: ((value) {
            _state(() {
              config.leftSpeed = value;
            });
          }),
        ),
      ],
    ));
  }
}
