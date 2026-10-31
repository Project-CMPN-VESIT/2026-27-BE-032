import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String fullName;
  final String email;
  final String? phone;
  final String? photoUrl;
  final dynamic createdAt;

  UserModel({
    required this.uid,
    required this.fullName,
    required this.email,
    this.phone,
    this.photoUrl,
    this.createdAt,
  });

  // Getter for backwards compatibility with existing UI code referencing user.name
  String get name => fullName;

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      uid: id,
      fullName: map['fullName'] ?? map['name'] ?? 'User',
      email: map['email'] ?? '',
      phone: map['phone'],
      photoUrl: map['photoUrl'],
      createdAt: map['createdAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'fullName': fullName,
      'email': email,
      if (phone != null) 'phone': phone,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }
}
