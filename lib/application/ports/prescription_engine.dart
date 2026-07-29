import '../../planning/prescription/models/prescription_models.dart';

/// PrescriptionEngine — semantic plan + blueprint → prescribed session.
abstract interface class PrescriptionEngine {
  PrescriptionResult prescribe(PrescriptionRequest request);
}
