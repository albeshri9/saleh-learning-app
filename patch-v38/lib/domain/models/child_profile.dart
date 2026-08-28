enum ChildGender { male, female }

/// ملف الطفل — الاسم والجنس بيانات ديناميكية يعتمد عليها نظام مخاطبة صالح.
class ChildProfile {
  const ChildProfile(
      {required this.name,
      required this.gender,
      this.id = 'legacy',
      this.avatar = '🦁',
      this.age = 5,
      this.level = 'beginner'});

  final String name;
  final ChildGender gender;
  final String id;
  final String avatar;
  final int age;
  final String level;

  bool get isMale => gender == ChildGender.male;

  Map<String, dynamic> toJson() => {
        'name': name,
        'gender': gender.name,
        'id': id,
        'avatar': avatar,
        'age': age,
        'level': level,
      };

  factory ChildProfile.fromJson(Map<String, dynamic> json) => ChildProfile(
        name: json['name'] as String,
        gender: ChildGender.values.byName(json['gender'] as String),
        id: json['id'] as String? ?? 'legacy',
        avatar: json['avatar'] as String? ?? '🦁',
        age: json['age'] as int? ?? 5,
        level: json['level'] as String? ?? 'beginner',
      );
}
