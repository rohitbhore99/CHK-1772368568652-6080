import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class ClassroomLocationPicker extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  final double? initialRadius;

  const ClassroomLocationPicker({
    super.key,
    this.initialLat,
    this.initialLng,
    this.initialRadius = 100.0,
  });

  @override
  State<ClassroomLocationPicker> createState() =>
      _ClassroomLocationPickerState();
}

class _ClassroomLocationPickerState extends State<ClassroomLocationPicker> {
  late TextEditingController _latController;
  late TextEditingController _lngController;
  late TextEditingController _radiusController;

  bool _isLoadingLocation = false;
  String _locationStatus = 'Set manually or capture current location';

  @override
  void initState() {
    super.initState();
    _latController =
        TextEditingController(text: (widget.initialLat ?? 0.0).toString());
    _lngController =
        TextEditingController(text: (widget.initialLng ?? 0.0).toString());
    _radiusController = TextEditingController(
        text: (widget.initialRadius ?? 100.0).toStringAsFixed(1));
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  Future<void> _captureCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationStatus = 'Capturing location...';
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Location services are disabled';
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'Location permission denied permanently';
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _latController.text = position.latitude.toStringAsFixed(6);
        _lngController.text = position.longitude.toStringAsFixed(6);
        _locationStatus =
            'Location captured! Lat: ${position.latitude.toStringAsFixed(4)}, Lng: ${position.longitude.toStringAsFixed(4)}';
      });
    } catch (e) {
      setState(() {
        _locationStatus = 'Error: $e';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error capturing location: $e')),
        );
      }
    } finally {
      setState(() => _isLoadingLocation = false);
    }
  }

  void _submitLocation() {
    try {
      final lat = double.parse(_latController.text);
      final lng = double.parse(_lngController.text);
      final radius = double.parse(_radiusController.text);

      if (radius <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Radius must be greater than 0')),
        );
        return;
      }

      Navigator.pop(
        context,
        {
          'lat': lat,
          'lng': lng,
          'radius': radius,
        },
      );
    } on FormatException {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid numbers')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Classroom Location'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Card
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'GPS Geofencing Setup',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Students will only be able to mark attendance if they are within the specified radius of this location.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

             Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _locationStatus,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 24),

             TextFormField(
              controller: _latController,
              decoration: InputDecoration(
                labelText: 'Latitude',
                hintText: 'e.g., 40.712776',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                helperText: 'Classroom latitude',
                prefixIcon: const Icon(Icons.location_on),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

             TextFormField(
              controller: _lngController,
              decoration: InputDecoration(
                labelText: 'Longitude',
                hintText: 'e.g., -74.005974',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                helperText: 'Classroom longitude',
                prefixIcon: const Icon(Icons.location_on),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

             TextFormField(
              controller: _radiusController,
              decoration: InputDecoration(
                labelText: 'Radius (meters)',
                hintText: 'e.g., 100',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                helperText: 'Allowed distance from classroom location',
                prefixIcon: const Icon(Icons.straighten),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),

             SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoadingLocation ? null : _captureCurrentLocation,
                icon: _isLoadingLocation
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.gps_fixed),
                label: Text(
                  _isLoadingLocation
                      ? 'Capturing...'
                      : 'Capture Current Location',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),

             SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submitLocation,
                icon: const Icon(Icons.check_circle),
                label: const Text('Save Location'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 24),
 
          ],
        ),
      ),
    );
  }
} 
