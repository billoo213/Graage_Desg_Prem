class MaintenanceRecord {
  final int? id;
  final int vehicleId;
  final String title;
  final String category;
  final String date;
  final int mileage;
  final double cost;
  final String notes;

  const MaintenanceRecord({this.id, required this.vehicleId, required this.title,
    required this.category, required this.date, required this.mileage,
    this.cost = 0, this.notes = ''});

  Map<String, Object?> toMap() => {
    'id': id, 'vehicle_id': vehicleId, 'title': title, 'category': category,
    'date': date, 'mileage': mileage, 'cost': cost, 'notes': notes,
  };

  factory MaintenanceRecord.fromMap(Map<String, Object?> m) => MaintenanceRecord(
    id: m['id'] as int?, vehicleId: m['vehicle_id'] as int,
    title: m['title'] as String, category: m['category'] as String,
    date: m['date'] as String, mileage: m['mileage'] as int,
    cost: (m['cost'] as num?)?.toDouble() ?? 0,
    notes: (m['notes'] as String?) ?? '',
  );
}

class MaintenanceReminder {
  final int? id;
  final int vehicleId;
  final String title;
  final String? dueDate;
  final int? dueMileage;
  final String notes;
  final bool completed;
  const MaintenanceReminder({this.id, required this.vehicleId, required this.title,
    this.dueDate, this.dueMileage, this.notes = '', this.completed = false});

  Map<String, Object?> toMap() => {
    'id': id, 'vehicle_id': vehicleId, 'title': title, 'due_date': dueDate,
    'due_mileage': dueMileage, 'notes': notes, 'completed': completed ? 1 : 0,
  };

  factory MaintenanceReminder.fromMap(Map<String, Object?> m) => MaintenanceReminder(
    id: m['id'] as int?, vehicleId: m['vehicle_id'] as int,
    title: m['title'] as String, dueDate: m['due_date'] as String?,
    dueMileage: m['due_mileage'] as int?, notes: (m['notes'] as String?) ?? '',
    completed: (m['completed'] as int? ?? 0) == 1,
  );
}
