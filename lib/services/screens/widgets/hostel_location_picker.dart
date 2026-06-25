import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../osm_location_service.dart';

/// Map search + tap, or type location manually — both update [locationController].
class HostelLocationPicker extends StatefulWidget {
  final TextEditingController locationController;
  final LatLng? initialPoint;
  final String manualFieldLabel;
  final String mapSectionTitle;

  const HostelLocationPicker({
    super.key,
    required this.locationController,
    this.initialPoint,
    this.manualFieldLabel = 'Or type location manually',
    this.mapSectionTitle = 'Pick on map (search or tap)',
  });

  @override
  State<HostelLocationPicker> createState() => _HostelLocationPickerState();
}

class _HostelLocationPickerState extends State<HostelLocationPicker> {
  static const _defaultCenter = LatLng(24.8607, 67.0011);

  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  late final TextEditingController _manualController;

  late LatLng _markerPoint;
  String _selectedLabel = '';
  List<OsmPlace> _searchResults = [];
  bool _searching = false;
  bool _resolvingAddress = false;

  @override
  void initState() {
    super.initState();
    _manualController = TextEditingController(text: widget.locationController.text);
    _markerPoint = widget.initialPoint ?? _defaultCenter;
    _selectedLabel = widget.locationController.text;
    _searchController.text = _selectedLabel;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _manualController.dispose();
    super.dispose();
  }

  void _applyManualLocation(String value) {
    final trimmed = value.trim();
    widget.locationController.text = trimmed;
    setState(() {
      _selectedLabel = trimmed;
      _searchResults = [];
    });
  }

  Future<void> _runSearch() async {
    final query = _searchController.text.trim();
    if (query.length < 2) return;

    setState(() {
      _searching = true;
      _searchResults = [];
    });

    try {
      final results = await OsmLocationService.searchPlaces(query);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _searching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _searching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not search location. Check internet connection.')),
      );
    }
  }

  Future<void> _selectPoint(LatLng point, {String? address}) async {
    setState(() {
      _markerPoint = point;
      _resolvingAddress = address == null;
      _searchResults = [];
    });
    _mapController.move(point, _mapController.camera.zoom);

    String? label = address;
    if (label == null) {
      try {
        label = await OsmLocationService.reverseGeocode(point);
      } catch (_) {
        label = null;
      }
    }

    if (!mounted) return;
    final resolved = label ?? '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
    widget.locationController.text = resolved;
    _manualController.text = resolved;
    setState(() {
      _resolvingAddress = false;
      _selectedLabel = resolved;
      _searchController.text = resolved;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _manualController,
          decoration: InputDecoration(
            labelText: widget.manualFieldLabel,
            hintText: 'e.g. Karachi — Gulshan, Block 5',
            prefixIcon: const Icon(Icons.edit_location_alt),
            suffixIcon: IconButton(
              icon: const Icon(Icons.check_circle_outline),
              onPressed: () => _applyManualLocation(_manualController.text),
            ),
          ),
          onChanged: _applyManualLocation,
          onFieldSubmitted: _applyManualLocation,
        ),
        const SizedBox(height: 16),
        Text(
          widget.mapSectionTitle,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            labelText: 'Search on map',
            hintText: 'City, area, street...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : IconButton(icon: const Icon(Icons.travel_explore), onPressed: _runSearch),
          ),
          onSubmitted: (_) => _runSearch(),
        ),
        if (_searchResults.isNotEmpty)
          Card(
            margin: const EdgeInsets.only(top: 8),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _searchResults.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final place = _searchResults[index];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.place, color: Color(0xFF6C63FF)),
                  title: Text(place.displayName, maxLines: 2, overflow: TextOverflow.ellipsis),
                  onTap: () => _selectPoint(place.point, address: place.displayName),
                );
              },
            ),
          ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 220,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _markerPoint,
                initialZoom: 13,
                onTap: (_, point) => _selectPoint(point),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.pbl_flutter',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _markerPoint,
                      width: 48,
                      height: 48,
                      child: const Icon(Icons.location_pin, color: Color(0xFF6C63FF), size: 48),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _resolvingAddress
              ? 'Resolving address...'
              : 'Use manual text above or map search/tap — whichever you prefer.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        if (_selectedLabel.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Selected: $_selectedLabel',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}
