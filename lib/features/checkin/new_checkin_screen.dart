import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/supabase_constants.dart';
import '../../core/storage/image_compression_service.dart';
import '../../core/storage/offline_queue_service.dart';
import '../../data/repositories/geotrace_repository.dart';
import '../../data/models/trip_model.dart';
import '../map/location_picker_screen.dart';

class NewCheckInScreen extends StatefulWidget {
  final VoidCallback? onCheckInSuccess;

  const NewCheckInScreen({super.key, this.onCheckInSuccess});

  @override
  State<NewCheckInScreen> createState() => _NewCheckInScreenState();
}

class _NewCheckInScreenState extends State<NewCheckInScreen> {
  final _repository = GeoTraceRepository();
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();
  final _locationNameController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  final List<File> _selectedFiles = [];
  final List<CompressedImageResult> _compressedResults = [];

  double? _selectedLatitude;
  double? _selectedLongitude;
  String _locationSource = 'Not detected yet';
  bool _isGettingLocation = false;
  bool _isCompressing = false;
  bool _isSubmitting = false;

  List<TripModel> _trips = [];
  String? _selectedTripId;

  @override
  void initState() {
    super.initState();
    _loadTrips();
    _detectCurrentLocation();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    _locationNameController.dispose();
    super.dispose();
  }

  Future<void> _loadTrips() async {
    try {
      final list = await _repository.fetchTrips();
      if (mounted) setState(() => _trips = list);
    } catch (_) {}
  }

  Future<void> _detectCurrentLocation() async {
    setState(() => _isGettingLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
        if (mounted) {
          setState(() {
            _selectedLatitude = pos.latitude;
            _selectedLongitude = pos.longitude;
            _locationSource = 'Auto GPS';
            if (_locationNameController.text.isEmpty) {
              _locationNameController.text =
                  '${pos.latitude.toStringAsFixed(4)}, ${_selectedLongitude!.toStringAsFixed(4)}';
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            content: Text('Failed to detect GPS location: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  Future<void> _pickLocationFromMap() async {
    final initial = (_selectedLatitude != null && _selectedLongitude != null)
        ? LatLng(_selectedLatitude!, _selectedLongitude!)
        : null;

    final picked = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(initialLocation: initial),
      ),
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedLatitude = picked.latitude;
        _selectedLongitude = picked.longitude;
        _locationSource = 'Picked from Map';
        if (_locationNameController.text.isEmpty ||
            _locationNameController.text.contains(',')) {
          _locationNameController.text =
              '${picked.latitude.toStringAsFixed(4)}, ${picked.longitude.toStringAsFixed(4)}';
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: const Text('Location selected from map!'),
        ),
      );
    }
  }

  Future<void> _openCreateTripDialog() async {
    final newTrip = await showDialog<TripModel>(
      context: context,
      builder: (_) => _CreateTripDialog(
        onCreateTrip: (title, description) => _repository.createTrip(
          title: title,
          description: description,
        ),
      ),
    );

    if (newTrip != null && mounted) {
      setState(() {
        _trips.insert(0, newTrip);
        _selectedTripId = newTrip.id;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Text('Trip "${newTrip.title}" created successfully!'),
        ),
      );
    }
  }

  Future<void> _pickImages() async {
    final remainingSlots = SupabaseConstants.maxPhotosPerCheckIn - _selectedFiles.length;
    if (remainingSlots <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: const Text('Maximum 5 photos per check-in to preserve quota.'),
        ),
      );
      return;
    }

    final pickedXFiles = await _picker.pickMultiImage(limit: remainingSlots);
    if (pickedXFiles.isEmpty) return;

    setState(() => _isCompressing = true);

    for (final xFile in pickedXFiles.take(remainingSlots)) {
      final file = File(xFile.path);
      try {
        final result = await ImageCompressionService.compressImage(file);
        final finalResult = result ??
            CompressedImageResult(
              file: file,
              originalSizeKb: (await file.length() / 1024).round(),
              compressedSizeKb: (await file.length() / 1024).round(),
              width: 0,
              height: 0,
            );
        _compressedResults.add(finalResult);
        _selectedFiles.add(finalResult.file);
      } catch (e) {
        debugPrint('Failed to compress image: $e');
        final fallback = CompressedImageResult(
          file: file,
          originalSizeKb: 0,
          compressedSizeKb: 0,
          width: 0,
          height: 0,
        );
        _compressedResults.add(fallback);
        _selectedFiles.add(file);
      }
    }

    if (mounted) setState(() => _isCompressing = false);
  }

  void _removePhoto(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
      if (index < _compressedResults.length) {
        _compressedResults.removeAt(index);
      }
    });
  }

  Future<void> _submitCheckIn() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: const Text('Title cannot be empty!'),
        ),
      );
      return;
    }

    if (_selectedLatitude == null || _selectedLongitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: const Text('Please determine location coordinates (GPS or Map) first!'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _repository.createCheckIn(
        title: title,
        latitude: _selectedLatitude!,
        longitude: _selectedLongitude!,
        locationName: _locationNameController.text.trim().isEmpty
            ? null
            : _locationNameController.text.trim(),
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        tripId: _selectedTripId,
        rawPhotoFiles: _selectedFiles,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            content: const Text('Check-in posted successfully!'),
          ),
        );
        widget.onCheckInSuccess?.call();
        Navigator.pop(context, true);
      }
    } catch (e) {
      final isOffline = e.toString().contains('SocketException') ||
          e.toString().contains('Failed host lookup') ||
          e.toString().contains('Network is unreachable') ||
          e.toString().contains('ClientException');

      if (mounted) {
        if (!isOffline) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              content: Text('Failed to check in: $e'),
              backgroundColor: Colors.red,
            ),
          );
        } else {
          final draft = OfflineDraft(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: title,
            latitude: _selectedLatitude!,
            longitude: _selectedLongitude!,
            locationName: _locationNameController.text.trim().isEmpty
                ? null
                : _locationNameController.text.trim(),
            note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
            tripId: _selectedTripId,
            photoPaths: _selectedFiles.map((f) => f.path).toList(),
            checkedInAt: DateTime.now(),
          );
          await OfflineQueueService.saveDraft(draft);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                content: const Text('Connection lost. Saved to device offline queue!'),
              ),
            );
            widget.onCheckInSuccess?.call();
            Navigator.pop(context, true);
          }
        }
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0F766E);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'New Check-in',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Lokasi GPS & Map Picker Card Modern
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: const Color(0xFFE6F4F1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF99F6E4), width: 1),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _selectedLatitude != null ? Icons.location_on_rounded : Icons.location_off_rounded,
                          color: primaryColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isGettingLocation
                                  ? 'Detecting GPS coordinates...'
                                  : (_selectedLatitude != null && _selectedLongitude != null)
                                      ? '${_selectedLatitude!.toStringAsFixed(5)}, ${_selectedLongitude!.toStringAsFixed(5)}'
                                      : 'Location not set',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Source: $_locationSource',
                              style: TextStyle(fontSize: 12, color: Colors.teal.shade800),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryColor,
                            backgroundColor: Colors.white.withOpacity(0.8),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            side: const BorderSide(color: primaryColor, width: 1.2),
                          ),
                          icon: _isGettingLocation
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.my_location_rounded, size: 16),
                          label: const Text('Auto GPS', style: TextStyle(fontSize: 12)),
                          onPressed: _isGettingLocation ? null : _detectCurrentLocation,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.map_rounded, size: 16),
                          label: const Text('Pick on Map', style: TextStyle(fontSize: 12)),
                          onPressed: _pickLocationFromMap,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Form Input Modern
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Place / Moment Title *',
                hintText: 'E.g., Sunset at Venice Beach',
                prefixIcon: Icon(Icons.title_rounded),
              ),
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _locationNameController,
              decoration: const InputDecoration(
                labelText: 'Location / City Name',
                hintText: 'E.g., Los Angeles, CA',
                prefixIcon: Icon(Icons.place_outlined),
              ),
            ),
            const SizedBox(height: 14),

            // Trip Selection & Create Trip Button
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedTripId,
                    decoration: const InputDecoration(
                      labelText: 'Select Trip (Category)',
                      prefixIcon: Icon(Icons.card_travel_rounded),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('No Specific Trip')),
                      ..._trips.map(
                        (t) => DropdownMenuItem(
                          value: t.id,
                          child: Text(t.title, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (val) => setState(() => _selectedTripId = val),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.all(14),
                  ),
                  icon: const Icon(Icons.add_rounded),
                  tooltip: 'Create New Trip',
                  onPressed: _openCreateTripDialog,
                ),
              ],
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Travel Notes (Short story)',
                hintText: 'Share your story and memories from this moment with friends...',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 22),

            // Bagian Foto & Kompresi
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Photos (${_selectedFiles.length}/${SupabaseConstants.maxPhotosPerCheckIn})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                ),
                TextButton.icon(
                  onPressed: _selectedFiles.length < SupabaseConstants.maxPhotosPerCheckIn && !_isCompressing
                      ? _pickImages
                      : null,
                  icon: const Icon(Icons.add_photo_alternate_rounded, size: 18),
                  label: const Text('Add Photos'),
                ),
              ],
            ),
            Text(
              'Photos are automatically compressed to 1080px (100–250 KB) to save cloud storage.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),

            if (_isCompressing)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F4F1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  children: [
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 12),
                    Text('Compressing photos on device...', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                  ],
                ),
              ),

            // Preview List Foto yang sudah dikompresi
            if (_compressedResults.isNotEmpty)
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _compressedResults.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final result = _compressedResults[index];
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            result.file,
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Photo ${index + 1}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${result.originalSizeKb} KB  ➔  ${result.compressedSizeKb} KB',
                                style: const TextStyle(
                                  color: Color(0xFF0F766E),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                ),
                              ),
                              Text(
                                'Saved ${result.compressionRatioPercent.toStringAsFixed(0)}% cloud storage',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                          onPressed: () => _removePhoto(index),
                        ),
                      ],
                    ),
                  );
                },
              ),

            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submitCheckIn,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_rounded),
              label: Text(_isSubmitting ? 'Uploading & Saving...' : 'Post Check-in Now'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _CreateTripDialog extends StatefulWidget {
  final Future<TripModel> Function(String title, String? description) onCreateTrip;

  const _CreateTripDialog({required this.onCreateTrip});

  @override
  State<_CreateTripDialog> createState() => _CreateTripDialogState();
}

class _CreateTripDialogState extends State<_CreateTripDialog> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _errorMessage = 'Trip Name cannot be empty.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final desc = _descController.text.trim();
      final trip = await widget.onCreateTrip(title, desc.isEmpty ? null : desc);
      if (mounted) {
        Navigator.of(context).pop(trip);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Failed to create trip: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Create New Trip'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Trip Name *',
                hintText: 'E.g., Bali Holiday 2025',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _descController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Short Description (Optional)',
                hintText: 'E.g., Road trip with close friends',
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F766E),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _isSaving ? null : _handleSave,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Save Trip'),
        ),
      ],
    );
  }
}
