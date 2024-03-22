import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MapboxView extends StatefulWidget {
  const MapboxView({Key? key}) : super(key: key);

  @override
  State createState() => MapboxViewState();
}

class MapboxViewState extends State<MapboxView> {
  MapboxMap? mapboxMap;
  PointAnnotationManager? pointAnnotationManager;
  PointAnnotation? pointAnnotation;
  late SharedPreferences prefs;

  String lat = "11.077512";
  String lon = "76.989741";
  bool isBatteryOptimizationDisabled = true;
  var isMqttConnected = false;

  late StreamSubscription subscription;
  bool isConnected = false;

  @override
  void initState() {
    super.initState();

    if (client.connectionStatus!.state == MqttConnectionState.connected ||
        client.connectionStatus!.state == MqttConnectionState.connecting) {
      return;
    }

    loadLatLng();
  }

  Future<void> checkConnectivity() async {
    StreamSubscription<List<ConnectivityResult>> subscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> connectivityResult) async {
      if (connectivityResult.contains(ConnectivityResult.none)) {
        if (client.connectionStatus!.state == MqttConnectionState.connected) {
          disconnectClient();
        }

        setState(() {
          isConnected = false;
        });
      } else {
        if (client.connectionStatus!.state == MqttConnectionState.connected ||
            client.connectionStatus!.state == MqttConnectionState.connecting) {
          return;
        }

        isMqttConnected = await connectClient();

        if (isMqttConnected) {
          subscribeClient();
          listernClient();
        }

        setState(() {
          isConnected = true;
        });
      }
    });

    // Add a periodic timer to check the MQTT connection status
    Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (client.connectionStatus!.state == MqttConnectionState.disconnected) {

        if (isConnected) {
          isMqttConnected = await connectClient();
          if (isMqttConnected) {
            subscribeClient();
            listernClient();
          }
        }
      }
    });
  }

  final client = MqttServerClient('broker.mqtt.cool', 'flutter_client');

  Future<bool> connectClient() async {
    client.logging(on: false);
    client.keepAlivePeriod = 65535;

    try {
      await client.connect();
      if (client.connectionStatus!.state == MqttConnectionState.connected) {
        print('MQTT client connected');
        return true;
      } else {
        return false;
        print(
            'MQTT client connection failed - disconnecting, status is ${client.connectionStatus}');
      }
    } on SocketException catch (e) {
      print('SocketExeption: $e');
      disconnectClient();
      return false;
    } catch (e) {
      print('Exception: $e');
      disconnectClient();
      return false;
    }
  }

  void disconnectClient() {
    try {
      client.disconnect();
      setState(() {
        isMqttConnected = false;
      });
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
    disconnectClient();
  }

  Future<void> loadLatLng() async {
    prefs = await SharedPreferences.getInstance();

    setState(() {
      lat = prefs.getString('lat') ?? "11.077512";
      lon = prefs.getString('lon') ?? "76.989741";
    });
  }

  Future<void> listernClient() async {

    print('listernClient called');
    try {
      // Wait until the client is connected
      while (client.connectionStatus!.state != MqttConnectionState.connected) {
        print('Waiting for connection');
        await Future.delayed(const Duration(seconds: 1));
        setState(() {
          isMqttConnected = false;
        });
      }

      client.updates!.listen(
        (List<MqttReceivedMessage<MqttMessage>> c) async {
          print("message received");

          final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
          final String pt =
              MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

          // Parse the message
          List<dynamic> messages = jsonDecode(pt);
          if (messages.isNotEmpty) {
            Map<String, dynamic> message = messages[0];
            lat = message['lat'];
            lon = message['lon'];

            await prefs.setString('lat', lat);
            await prefs.setString('lon', lon);

            print('Lat: $lat, Lon: $lon');

            // Update the map
            mapboxMap?.flyTo(
                CameraOptions(
                    center: Point(
                            coordinates:
                                Position(double.parse(lon), double.parse(lat)))
                        .toJson(),
                    zoom: 18,
                    bearing: 180,
                    pitch: 30),
                MapAnimationOptions(duration: 2000, startDelay: 0));

            // Move the pin
            if (pointAnnotation != null && pointAnnotationManager != null) {
              final ByteData bytes = await rootBundle.load('assets/pin.png');
              final Uint8List list = bytes.buffer.asUint8List();

              var options = PointAnnotationOptions(
                  geometry: Point(
                          coordinates:
                              Position(double.parse(lon), double.parse(lat)))
                      .toJson(),
                  image: list);

              print('PointAnnotation updated');

              pointAnnotationManager?.delete(pointAnnotation!);
              pointAnnotation = await pointAnnotationManager?.create(options);
            } else {
              mapboxMap?.annotations
                  .createPointAnnotationManager()
                  .then((pointAnnotationManager) async {
                final ByteData bytes = await rootBundle.load('assets/pin.png');
                final Uint8List list = bytes.buffer.asUint8List();
                var options = PointAnnotationOptions(
                    geometry: Point(
                            coordinates:
                                Position(double.parse(lon), double.parse(lat)))
                        .toJson(),
                    image: list);

                pointAnnotation = await pointAnnotationManager.create(options);
                this.pointAnnotationManager = pointAnnotationManager;
              });
            }
          }
        },
      );
    } on SocketException catch (e) {
      print('SocketExeption: $e');
      disconnectClient();
    } catch (e) {
      print('Error: $e');
    }
  }

  // {"lat":"11.02740","lon":"	77.03070"}

  _onMapCreated(MapboxMap mapboxMap) {
    this.mapboxMap = mapboxMap;

    mapboxMap.annotations.createPointAnnotationManager().then(
      (pointAnnotationManager) async {
        this.pointAnnotationManager = pointAnnotationManager;
        final ByteData bytes = await rootBundle.load('assets/pin.png');
        final Uint8List list = bytes.buffer.asUint8List();

        var options = PointAnnotationOptions(
            geometry: Point(
                    coordinates: Position(double.parse(lon), double.parse(lat)))
                .toJson(),
            image: list);

        pointAnnotation = await pointAnnotationManager.create(options);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: checkConnectivity(),
        builder: (context, snapshot) {
          return Scaffold(
            appBar: AppBar(
              title: const Text("Vehicle Tracking"),
              actions: [
                (isConnected)
                    ? const Icon(CupertinoIcons.wifi, color: Colors.green)
                    : const Icon(CupertinoIcons.wifi_slash, color: Colors.red),
                const SizedBox(
                  width: 20,
                ),
                (client.connectionStatus!.state ==
                        MqttConnectionState.connected)
                    ? const Icon(CupertinoIcons.power, color: Colors.green)
                    : const Icon(
                        CupertinoIcons.power,
                        color: Colors.red,
                      ),
                const SizedBox(
                  width: 15,
                )
              ],
            ),
            body: MapWidget(
              key: const ValueKey("mapWidget"),
              cameraOptions: CameraOptions(
                  center: Point(
                          coordinates:
                              Position(double.parse(lon), double.parse(lat)))
                      .toJson(),
                  zoom: 15.0),
              resourceOptions: ResourceOptions(
                  accessToken:
                      "pk.eyJ1Ijoia2FydGhpZHJlYW1yIiwiYSI6ImNsc29lMzFpbTBiM2cya29hYm03NTNxMnoifQ.AkoJMx3gGQtFiEwxPQk4Vw"),
              onMapCreated: _onMapCreated,
            ),
          );
        });
  }
}
