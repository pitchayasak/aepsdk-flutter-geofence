import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/poi_model.dart';

class AddPoiDialog extends StatefulWidget {
  final LatLng defaultLocation;
  final void Function(PoiModel) onAdd;

  const AddPoiDialog({
    super.key,
    required this.defaultLocation,
    required this.onAdd,
  });

  @override
  State<AddPoiDialog> createState() => _AddPoiDialogState();
}

class _AddPoiDialogState extends State<AddPoiDialog> {
  final _nameCtrl = TextEditingController(text: 'Test POI');
  late final TextEditingController _latCtrl;
  late final TextEditingController _lngCtrl;
  final _radiusCtrl = TextEditingController(text: '200');

  @override
  void initState() {
    super.initState();
    _latCtrl = TextEditingController(
      text: widget.defaultLocation.latitude.toStringAsFixed(6),
    );
    _lngCtrl = TextEditingController(
      text: widget.defaultLocation.longitude.toStringAsFixed(6),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _radiusCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(children: [
        Icon(Icons.add_location_alt, color: Colors.teal),
        SizedBox(width: 8),
        Text('Add POI'),
      ]),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field(_nameCtrl, 'POI Name', Icons.label),
            const SizedBox(height: 10),
            _field(_latCtrl, 'Latitude', Icons.north,
                type: const TextInputType.numberWithOptions(decimal: true, signed: true)),
            const SizedBox(height: 10),
            _field(_lngCtrl, 'Longitude', Icons.east,
                type: const TextInputType.numberWithOptions(decimal: true, signed: true)),
            const SizedBox(height: 10),
            _field(_radiusCtrl, 'Radius (m)', Icons.radio_button_unchecked,
                type: TextInputType.number),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.teal[700]),
          onPressed: () {
            final lat = double.tryParse(_latCtrl.text);
            final lng = double.tryParse(_lngCtrl.text);
            final radius = int.tryParse(_radiusCtrl.text);
            final name = _nameCtrl.text.trim();
            if (lat == null || lng == null || radius == null || name.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('กรุณากรอกข้อมูลให้ครบถ้วน')),
              );
              return;
            }
            widget.onAdd(PoiModel(
              identifier: 'manual_${DateTime.now().millisecondsSinceEpoch}',
              name: name,
              latitude: lat,
              longitude: lng,
              radius: radius,
            ));
          },
          child: const Text('Add'),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType type = TextInputType.text,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}
