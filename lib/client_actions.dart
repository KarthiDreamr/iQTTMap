// import 'dart:async';
// import 'dart:io';
//
// import 'package:connectivity_plus/connectivity_plus.dart';
// import 'package:flutter/material.dart';
// import 'package:mqtt_client/mqtt_client.dart';
// import 'package:mqtt_client/mqtt_server_client.dart';
//
// import 'mapbox_view.dart';
//
// class ClientActions extends StatefulWidget {
//   const ClientActions({Key? key}) : super(key: key);
//
//   @override
//   State<ClientActions> createState() => _ClientActionsState();
// }
//
// class _ClientActionsState extends State<ClientActions> {
//
//   @override
//   Widget build(BuildContext context) {
//
//       return FutureBuilder(
//         future: connectClient(),
//         builder: (context, snapshot) {
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return const Center(
//               child: CircularProgressIndicator(),
//             );
//           }
//           if (snapshot.hasError) {
//             return MapboxView(client: client, isConnected: isConnected);
//           }
//           return MapboxView( client: client, isConnected: isConnected );
//         }
//       );
//
//   }
// }
