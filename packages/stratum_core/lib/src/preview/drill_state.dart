import 'drill_id.dart';
import 'drill_part.dart';
import '../reactive_graph.dart';

/// Where one drill stands on its three tracks.
class DrillState {
  DrillState(this.id);

  final DrillId id;

  final Signal<int> radius = Signal(0, name: 'drill radius');
  final Signal<int> drive = Signal(0, name: 'drill drive');
  final Signal<int> calibration = Signal(0, name: 'drill calibration');

  Signal<int> levelOf(DrillPart part) => switch (part) {
    DrillPart.radius => radius,
    DrillPart.drive => drive,
    DrillPart.calibration => calibration,
  };
}
