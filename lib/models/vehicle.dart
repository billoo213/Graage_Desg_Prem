class Vehicle {
  final int? id;
  final String nickname;
  final String make;
  final String model;
  final int? year;
  final String fuel;
  final String engine;
  final String engineCode;
  final String vin;
  final int mileage;

  const Vehicle({
    this.id,
    this.nickname = '',
    required this.make,
    required this.model,
    this.year,
    required this.fuel,
    this.engine = '',
    this.engineCode = '',
    this.vin = '',
    required this.mileage,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'nickname': nickname,
        'make': make,
        'model': model,
        'year': year,
        'fuel': fuel,
        'engine': engine,
        'engine_code': engineCode,
        'vin': vin,
        'mileage': mileage,
      };

  factory Vehicle.fromMap(Map<String, Object?> map) => Vehicle(
        id: map['id'] as int?,
        nickname: (map['nickname'] as String?) ?? '',
        make: map['make'] as String,
        model: map['model'] as String,
        year: map['year'] as int?,
        fuel: map['fuel'] as String,
        engine: (map['engine'] as String?) ?? '',
        engineCode: (map['engine_code'] as String?) ?? '',
        vin: (map['vin'] as String?) ?? '',
        mileage: (map['mileage'] as int?) ?? 0,
      );
}
