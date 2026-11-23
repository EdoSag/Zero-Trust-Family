import 'dart:math' as math;

import 'drive.dart';
import 'family_event.dart';
import 'location_update.dart';

/// Approximate sharing (L-5): a member can show a circle only roughly where
/// they are, about the size of a neighbourhood or small town, instead of the
/// exact spot.
///
/// Positions are snapped to the centre of a fixed grid cell about [cellM]
/// across, so the shown point only moves when the person moves to another
/// cell, and repeated updates can't be averaged into the real spot. SOS,
/// a missed safety timer and a crash always send the exact position.
abstract final class Approximate {
  /// Grid cell size in metres (north to south; east to west is kept about
  /// the same by widening cells away from the equator).
  static const cellM = 3000.0;

  /// The accuracy circle shown for an approximate position.
  static const radiusM = 2000.0;

  static const _metersPerDegree = 111320.0;
  static const _latStep = cellM / _metersPerDegree;

  /// The centre of the grid cell [lat], [lng] falls in.
  static (double, double) snap(double lat, double lng) {
    final row = (lat / _latStep).floor();
    final centerLat = ((row + 0.5) * _latStep).clamp(-89.9, 89.9);
    final cos = math.max(0.05, math.cos(centerLat * math.pi / 180));
    final lngStep = _latStep / cos;
    final col = ((lng + 180) / lngStep).floor();
    var centerLng = (col + 0.5) * lngStep - 180;
    if (centerLng > 180) centerLng -= 360;
    return (_round(centerLat), _round(centerLng));
  }

  static double _round(double v) => (v * 1e5).roundToDouble() / 1e5;

  /// [update] as an approximate member shows it: the cell, no speed or
  /// heading.
  static LocationUpdate update(LocationUpdate update) {
    if (!update.hasLocation) return update.copyWith(approximate: true);
    final (lat, lng) = snap(update.lat!, update.lng!);
    return LocationUpdate(
      at: update.at,
      lat: lat,
      lng: lng,
      accuracyM: radiusM,
      battery: update.battery,
      charging: update.charging,
      powerSave: update.powerSave,
      mode: update.mode,
      pausedUntil: update.pausedUntil,
      pausedOpenEnded: update.pausedOpenEnded,
      approximate: true,
    );
  }

  /// Kinds that always carry the exact position: someone may need help.
  static bool exactKind(FamilyEventKind kind) =>
      kind == FamilyEventKind.sos || kind == FamilyEventKind.overdue;

  /// [event] with its positions snapped (unless it's an SOS or alarm).
  static FamilyEvent event(FamilyEvent event) {
    if (exactKind(event.kind)) return event;
    double? la, lo;
    if (event.hasLocation) (la, lo) = snap(event.lat!, event.lng!);
    final d = event.drive;
    DriveSummary? drive;
    if (d != null) {
      double? sla, slo, ela, elo;
      if (d.startLat != null && d.startLng != null) {
        (sla, slo) = snap(d.startLat!, d.startLng!);
      }
      if (d.endLat != null && d.endLng != null) {
        (ela, elo) = snap(d.endLat!, d.endLng!);
      }
      drive = DriveSummary(
        id: d.id,
        start: d.start,
        end: d.end,
        distanceM: d.distanceM,
        topSpeedMps: d.topSpeedMps,
        hardBrakes: d.hardBrakes,
        rapidStarts: d.rapidStarts,
        phoneUseSeconds: d.phoneUseSeconds,
        startLat: sla,
        startLng: slo,
        endLat: ela,
        endLng: elo,
      );
    }
    return FamilyEvent(
      id: event.id,
      kind: event.kind,
      at: event.at,
      placeId: event.placeId,
      lat: la,
      lng: lo,
      battery: event.battery,
      note: event.note,
      to: event.to,
      until: event.until,
      accuracyM: event.hasLocation ? radiusM : null,
      drive: drive,
      crash: event.crash,
      approximate: true,
      ref: event.ref,
      onLeave: event.onLeave,
    );
  }
}
