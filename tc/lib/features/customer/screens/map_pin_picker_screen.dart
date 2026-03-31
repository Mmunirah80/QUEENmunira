import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// OSM map: tap or long-press to place a pin, confirm returns [LatLng].
///
/// The marker uses [IgnorePointer] so it does not steal taps from the map
/// (a common issue with [MarkerLayer] hit targets).
class MapPinPickerScreen extends StatefulWidget {
  final LatLng initial;

  const MapPinPickerScreen({super.key, required this.initial});

  @override
  State<MapPinPickerScreen> createState() => _MapPinPickerScreenState();
}

class _MapPinPickerScreenState extends State<MapPinPickerScreen> {
  late LatLng _point;

  @override
  void initState() {
    super.initState();
    _point = widget.initial;
  }

  void _movePin(LatLng latlng) => setState(() => _point = latlng);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick pickup point'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_point),
            child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Tap or long-press the map to move the pin.\n'
              'Lat ${_point.latitude.toStringAsFixed(5)}, Lng ${_point.longitude.toStringAsFixed(5)}',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ),
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: _point,
                initialZoom: 14,
                onTap: (_, latlng) => _movePin(latlng),
                onLongPress: (_, latlng) => _movePin(latlng),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.naham.cook_app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _point,
                      width: 48,
                      height: 48,
                      alignment: Alignment.bottomCenter,
                      child: IgnorePointer(
                        child: Icon(Icons.location_pin, color: Colors.red.shade700, size: 48),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(_point),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Use this location'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
