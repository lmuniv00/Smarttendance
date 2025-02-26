import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final CollectionReference professors =
      FirebaseFirestore.instance.collection('Professors');
  final CollectionReference students =
      FirebaseFirestore.instance.collection('Students');

  Future<bool> getProfessors(String email) async {
    final querySnapshot =
        await professors.where('Email', isEqualTo: email).get();
    return querySnapshot.docs.isNotEmpty;
  }

  Future<bool> getStudents(String email) async {
    final querySnapshot = await students.where('Email', isEqualTo: email).get();
    return querySnapshot.docs.isNotEmpty;
  }
}
