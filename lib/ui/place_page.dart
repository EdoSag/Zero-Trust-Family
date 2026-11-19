import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zt_places/zt_places.dart';

import '../data/places.dart';
import '../l10n/l10n.dart';
import '../model/circle.dart';
import 'common.dart';

/// Adds or changes one of a circle's places: a name, where (this phone's
/// position, or coordinates or a map link pasted in) and how big. No map
/// search and no address lookup, since both would tell a server the place.
class PlacePage extends ConsumerStatefulWidget {
  const PlacePage({super.key, required this.spaceId, this.place});

  final String spaceId;

  /// Null for a new place.
  final ZtPlace? place;

  static Future<void> open(
    BuildContext context, {
    required String spaceId,
    ZtPlace? place,
  }) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PlacePage(spaceId: spaceId, place: place),
    ),
  );

  @override
  ConsumerState<PlacePage> createState() => _PlacePageState();
}

class _PlacePageState extends ConsumerState<PlacePage> {
  late final _name = TextEditingController(text: widget.place?.name ?? '');
  final _paste = TextEditingController();
  late ZtLatLng? _position = widget.place?.position;
  late double _radius = widget.place?.radiusMeters ?? ZtPlace.defaultRadius;
  bool _locating = false;
  bool _saving = false;
  String? _nameError;
  String? _positionError;

  @override
  void dispose() {
    _name.dispose();
    _paste.dispose();
    super.dispose();
  }

  Future<void> _here() async {
    final l = context.l;
    setState(() {
      _locating = true;
      _positionError = null;
    });
    ZtLatLng? here;
    try {
      here = await ref.read(placeLocatorProvider).currentLocation();
    } on Object {
      here = null;
    }
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (here == null) {
        _positionError = l.placeNoLocation;
      } else {
        _position = here;
      }
    });
  }

  void _pasted(String text) {
    final ll = ZtLatLng.tryParse(text);
    setState(() {
      if (ll != null) {
        _position = ll;
        _positionError = null;
      } else if (text.trim().isNotEmpty) {
        _positionError = context.l.placeBadPaste;
      }
    });
  }

  Future<void> _save() async {
    final l = context.l;
    final name = Circle.cleanName(_name.text);
    setState(() {
      _nameError = name == null ? l.placeNameRequired : null;
      _positionError = _position == null ? l.placeNeedsPosition : null;
    });
    if (name == null || _position == null) return;
    setState(() => _saving = true);
    try {
      final ok = await ref
          .read(placeActionsProvider)
          .save(
            widget.spaceId,
            ZtPlace(
              id: widget.place?.id ?? PlaceActions.newId(),
              name: name,
              latitude: _position!.latitude,
              longitude: _position!.longitude,
              radiusMeters: _radius,
            ),
          );
      if (!mounted) return;
      if (!ok) {
        showSnack(context, l.tooManyPlaces);
        setState(() => _saving = false);
        return;
      }
      Navigator.of(context).pop();
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      showSnack(context, l.couldNotSave);
    }
  }

  Future<void> _remove() async {
    final l = context.l;
    final place = widget.place!;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.removePlaceTitle(place.name)),
        content: Text(l.removePlaceBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            key: const Key('remove-place-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.removePlace),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref.read(placeActionsProvider).remove(widget.spaceId, place.id);
      if (mounted) Navigator.of(context).pop();
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      showSnack(context, l.couldNotSave);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final theme = Theme.of(context);
    final position = _position;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.place == null ? l.addPlace : l.editPlace),
        actions: [
          if (widget.place != null)
            IconButton(
              key: const Key('remove-place'),
              tooltip: l.removePlace,
              icon: const Icon(Icons.delete_outline),
              onPressed: _saving ? null : _remove,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            key: const Key('place-name'),
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            maxLength: Circle.maxNameLength,
            decoration: InputDecoration(
              labelText: l.placeName,
              hintText: l.placeNameHint,
              errorText: _nameError,
            ),
          ),
          const SizedBox(height: 8),
          Text(l.placeWhere, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Text(
            position == null ? l.placeNoPositionYet : position.format(),
            key: const Key('place-position'),
            style: position == null
                ? theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  )
                : theme.textTheme.bodyLarge,
          ),
          if (_positionError != null) ...[
            const SizedBox(height: 4),
            Text(
              _positionError!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('place-here'),
            onPressed: _locating ? null : _here,
            icon: _locating
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
            label: Text(l.placeUseHere),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('place-paste'),
            controller: _paste,
            onChanged: _pasted,
            decoration: InputDecoration(
              labelText: l.placePaste,
              hintText: '32.0853, 34.7818',
            ),
          ),
          const SizedBox(height: 20),
          Text(l.placeSize, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in ZtPlace.radiusChoices)
                ChoiceChip(
                  key: Key('radius-${r.round()}'),
                  label: Text(l.meters(r.round())),
                  selected: _radius == r,
                  onSelected: (_) => setState(() => _radius = r),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(l.placeSizeHint, style: theme.textTheme.bodySmall),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('place-save'),
            onPressed: _saving ? null : _save,
            child: Text(l.save),
          ),
        ],
      ),
    );
  }
}
