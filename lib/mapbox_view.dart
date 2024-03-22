import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MapboxView extends StatefulWidget {
  const MapboxView({Key? key, required this.client}) : super(key: key);

  final MqttServerClient client;

  @override
  State createState() => MapboxViewState();
}

class MapboxViewState extends State<MapboxView> {
  MapboxMap? mapboxMap;
  PointAnnotationManager? pointAnnotationManager;
  PointAnnotation? pointAnnotation;

  String lat = "11.077512";
  String lon = "76.989741";
  bool isBatteryOptimizationDisabled = true;

  @override
  void initState() {
    super.initState();
    print('initState called');
    print('Client connection status: ${widget.client.connectionStatus!.state}');

    loadLatLng();
    listernClient();
    // checkBatteryOptimization();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> loadLatLng() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    lat = prefs.getString('lat') ?? "11.077512";
    lon = prefs.getString('lon') ?? "76.989741";
  }

  var isMqttConnected ;

  Future<void> listernClient() async {
    print('listernClient called');
    try {
      // Wait until the client is connected
      while (widget.client.connectionStatus!.state !=
          MqttConnectionState.connected) {
        print('Waiting for connection');
        await Future.delayed(const Duration(seconds: 1));
      }

      widget.client.updates!.listen(
        (List<MqttReceivedMessage<MqttMessage>> c) async {

          isMqttConnected = ( widget.client.connectionStatus!.state !=
          MqttConnectionState.disconnected );

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
      // disconnectClient();
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

    return Scaffold(
      appBar: AppBar(
        title: const Text("Vehicle Tracking"),
        actions: [
          (isMqttConnected)
              ? const Icon(CupertinoIcons.power, color: Colors.green)
              : const Icon(CupertinoIcons.power, color: Colors.red),
          const SizedBox(
            width: 5,
          )
        ],
      ),
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
