/// Ported from `CarProfile` in `Models.swift`.
class CarProfile {
  const CarProfile({
    required this.model,
    required this.color,
    required this.plateNumber,
    required this.seats,
  });

  final String model;
  final String color;
  final String plateNumber;

  /// Stored as a string in the Swift app (free-form profile field).
  final String seats;

  /// Whether the mandatory vehicle fields are filled in. Used to block ride
  /// publishing for drivers who haven't set up their car yet.
  bool get isComplete =>
      model.trim().isNotEmpty &&
      color.trim().isNotEmpty &&
      plateNumber.trim().isNotEmpty;

  CarProfile copyWith({
    String? model,
    String? color,
    String? plateNumber,
    String? seats,
  }) {
    return CarProfile(
      model: model ?? this.model,
      color: color ?? this.color,
      plateNumber: plateNumber ?? this.plateNumber,
      seats: seats ?? this.seats,
    );
  }
}
