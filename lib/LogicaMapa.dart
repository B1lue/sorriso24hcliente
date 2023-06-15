import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapScreen extends StatefulWidget {
  final LatLng userLocation;
  final LatLng dentistLocation;
  final Set<Marker> markers;

  const MapScreen({super.key,
    required this.userLocation,
    required this.dentistLocation,
    required this.markers,
  });

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController mapController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa'),
      ),
      body: GoogleMap(
        onMapCreated: (GoogleMapController controller) {
          mapController = controller;
        },
        initialCameraPosition: CameraPosition(
          target: widget.userLocation,
          zoom: 14.0,
        ),
        markers: widget.markers,
      ),
    );
  }
}