import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: FullMap(),
    );
  }
}

class FullMap extends StatefulWidget {
  const FullMap({Key? key}) : super(key: key);

  @override
  State createState() => FullMapState();
}

class FullMapState extends State<FullMap> {
  MapboxMap? mapboxMap;
  PointAnnotationManager? pointAnnotationManager;
  PointAnnotation? pointAnnotation;

  String lat = "";
  String lon = "";

  @override
  void initState() {
    super.initState();
  }

  Future<void> connectAndSubscribe() async {
    final client = MqttServerClient('broker.hivemq.com', 'flutter_client');
    client.logging(on: false);
    client.keepAlivePeriod = 60;

    try {
      await client.connect();
    } catch (e) {
      print('Exception: $e');
      client.disconnect();
    }

    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      print('Client connected');
      client.subscribe('valtrack', MqttQos.atLeastOnce);
    } else {
      print('ERROR: MQTT client connection failed - '
          'disconnecting, state is ${client.connectionStatus}');
      client.disconnect();
    }

    client.updates!.listen(
      (List<MqttReceivedMessage<MqttMessage>> c) async {
        final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
        final String pt =
            MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

        // Parse the message
        Map<String, dynamic> message = jsonDecode(pt);
        List<dynamic> resource = message['resource'];
        if (resource.isNotEmpty) {
          setState(() {
            lat = resource[0]['lat'];
            lon = resource[0]['lon'];
          });

          print('Lat: $lat, Lon: $lon');

          // Update the map
          mapboxMap?.flyTo(
              CameraOptions(
                  center: Point(
                          coordinates:
                              Position(double.parse(lon), double.parse(lat)))
                      .toJson(),
                  zoom: 17,
                  bearing: 180,
                  pitch: 30),
              MapAnimationOptions(duration: 2000, startDelay: 0));

          // Move the pin
          if (pointAnnotation != null) {
            final ByteData bytes = await rootBundle.load('assets/pin.png');
            final Uint8List list = bytes.buffer.asUint8List();
            var options = PointAnnotationOptions(
                geometry: Point(
                        coordinates:
                            Position(double.parse(lon), double.parse(lat)))
                    .toJson(),
                image: list);

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
  }

  _onMapCreated(MapboxMap mapboxMap) {
    this.mapboxMap = mapboxMap;

    mapboxMap.annotations.createPointAnnotationManager().then(
      (pointAnnotationManager) async {
        final ByteData bytes = await rootBundle.load('assets/pin.png');
        final Uint8List list = bytes.buffer.asUint8List();
        var options = <PointAnnotationOptions>[];

        options.add(PointAnnotationOptions(
            geometry: Point(
                    coordinates: Position(double.parse(lon), double.parse(lat)))
                .toJson(),
            image: list));

        pointAnnotationManager.createMulti(options);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: connectAndSubscribe(),
      builder: (BuildContext context, AsyncSnapshot snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting || lat == "") {
          return const Center(
              child:
                  CircularProgressIndicator()); // Show a loading spinner while waiting for the future to complete
        } else if (snapshot.hasError) {
          return Text(
              'Error: ${snapshot.error}'); // Show an error message if the future completes with an error
        } else {
          return Scaffold(
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
        }
      },
    );
  }
}
