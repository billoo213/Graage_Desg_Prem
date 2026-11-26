class UserProfile {
  final int? id;
  final String firstName;
  final String lastName;
  final String country;
  final String email;

  const UserProfile({
    this.id,
    required this.firstName,
    this.lastName = '',
    this.country = 'Algérie',
    this.email = '',
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'first_name': firstName,
        'last_name': lastName,
        'country': country,
        'email': email,
      };

  factory UserProfile.fromMap(Map<String, Object?> map) => UserProfile(
        id: map['id'] as int?,
        firstName: map['first_name'] as String,
        lastName: (map['last_name'] as String?) ?? '',
        country: (map['country'] as String?) ?? 'Algérie',
        email: (map['email'] as String?) ?? '',
      );
}
