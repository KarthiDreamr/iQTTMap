import 'dart:convert';

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

  String lat = "0.000000";
  String lon = "0.000000";

  @override
  void initState() {
    super.initState();
    loadLatLng();
    connectAndSubscribe();
  }

  Future<void> loadLatLng() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    lat = prefs.getString('lat') ?? "0.000000";
    lon = prefs.getString('lon') ?? "0.000000";

    // if (lat.isNotEmpty && lon.isNotEmpty) {
    //   // Update the map and move the pin here
    // }
  }

  Future<void> connectAndSubscribe() async {
    final client = MqttServerClient('broker.hivemq.com', 'flutter_client');
    client.logging(on: false);
    client.keepAlivePeriod = 65535;

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
        if (message.isNotEmpty) {
          // setState(() {
          lat = message['lat'];
          lon = message['lon'];

          SharedPreferences prefs = await SharedPreferences.getInstance();
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
                  zoom: 20,
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
    return Scaffold(
      body: MapWidget(
        key: const ValueKey("mapWidget"),
        cameraOptions: CameraOptions(
            center: Point(
                coordinates: Position(double.parse(lon), double.parse(lat)))
                .toJson(),
            zoom: 15.0),
        resourceOptions: ResourceOptions(
            accessToken:
            "pk.eyJ1Ijoia2FydGhpZHJlYW1yIiwiYSI6ImNsc29lMzFpbTBiM2cya29hYm03NTNxMnoifQ.AkoJMx3gGQtFiEwxPQk4Vw"),
        onMapCreated: _onMapCreated,
      ),
    );
  }
}
