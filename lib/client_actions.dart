import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import 'mapbox_view.dart';

class ClientActions extends StatefulWidget {
  const ClientActions({Key? key}) : super(key: key);

  @override
  State<ClientActions> createState() => _ClientActionsState();
}

class _ClientActionsState extends State<ClientActions> {
  late StreamSubscription subscription;
  bool isConnected = false;

  @override
  void initState() {
    super.initState();
    checkConnectivity();
  }

  void checkConnectivity() {
    StreamSubscription<List<ConnectivityResult>> subscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> connectivityResult) {
      if (connectivityResult.contains(ConnectivityResult.none)) {
        disconnectClient();
        setState(() {
          isConnected = false;
        });
      } else {

        if(client.connectionStatus!.state == MqttConnectionState.connected || client.connectionStatus!.state == MqttConnectionState.connecting ){
          return;
        }
        connectClient().then((value) => subscribeClient());

        setState(() {
          isConnected = true;
        });
      }
    });
  }

  final client = MqttServerClient('broker.mqtt.cool', 'flutter_client');

  Future<void> connectClient() async {
    client.logging(on: false);
    client.keepAlivePeriod = 65535;

    try {
      await client.connect();
      if (client.connectionStatus!.state == MqttConnectionState.connected) {
        print('MQTT client connected');
      } else {
        print(
            'MQTT client connection failed - disconnecting, status is ${client.connectionStatus}');
      }
    } on SocketException catch (e) {
      print('SocketExeption: $e');
      disconnectClient();
    } catch (e) {
      print('Exception: $e');
      disconnectClient();
    }
  }

  void disconnectClient() {
    try {
      client.disconnect();
    } catch (e) {
      print('Exception: $e');
    }
  }

  void subscribeClient() {
    try {
      client.subscribe('valtrack', MqttQos.atLeastOnce);

      print("subcription success");
    } catch (e) {
      print(client.connectionStatus!.state);
      print('Subscrition Problem - Client not connected');
    }
  }

  @override
  void dispose() {
    super.dispose();
    subscription.cancel();
  }

  @override
  Widget build(BuildContext context) {
    if (isConnected) {
      return MapboxView(client: client);
    } else {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Padding(
                padding: EdgeInsets.only(
                  top: 20,
                  bottom: 60,
                  left: 20,
                  right: 20,
                ),
                child: Text(
                  "Please check your Internet connection",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F1D83),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Image.asset(
                "assets/no_internet.png",
                width: 300,
              )
            ],
          ),
        ),
      );
    }
  }
}
