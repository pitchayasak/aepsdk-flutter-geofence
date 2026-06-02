import 'package:flutter/material.dart';
import '../models/poi_model.dart';
import '../services/places_service.dart';

class PoiBottomSheet extends StatelessWidget {
  final PoiModel poi;

  const PoiBottomSheet({super.key, required this.poi});

  void _handleEvent(BuildContext context, bool isEntry) async {
    try {
      if (isEntry) {
        await PlacesService.processEntry(poi);
      } else {
        await PlacesService.processExit(poi);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${isEntry ? "Entry" : "Exit"} event sent to Adobe Places for "${poi.name}"',
            ),
            backgroundColor: isEntry ? Colors.green[700] : Colors.orange[700],
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.place, color: Colors.red, size: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            poi.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    _InfoRow(Icons.my_location, 'Lat / Lng',
                        '${poi.latitude.toStringAsFixed(5)},  ${poi.longitude.toStringAsFixed(5)}'),
                    _InfoRow(Icons.radio_button_unchecked, 'Radius', '${poi.radius} m'),
                    if (poi.category != null)
                      _InfoRow(Icons.label, 'Category', poi.category!),
                    _InfoRow(Icons.fingerprint, 'ID', poi.identifier),
                    if (poi.metadata.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Metadata',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          children: poi.metadata.entries
                              .map((e) => Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 2),
                                    child: Row(
                                      children: [
                                        Text(
                                          '${e.key}:',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w500),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(child: Text(e.value)),
                                      ],
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _handleEvent(context, true),
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('ENTRY'),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.green[700],
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _handleEvent(context, false),
                            icon: const Icon(Icons.logout),
                            label: const Text('EXIT'),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.orange[700],
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 10),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
