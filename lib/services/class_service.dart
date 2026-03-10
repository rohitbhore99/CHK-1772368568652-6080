import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/class.dart';

class ClassService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<String> createClass(Class classData) async {
    final docRef = await _db.collection('classes').add(classData.toMap());
    return docRef.id;
  }

  Stream<List<Class>> getClassesByTeacher(String teacherId) {
    return _db
        .collection('classes')
        .where('teacherId', isEqualTo: teacherId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Class.fromFirestore(doc))
            .toList());
  }

  Stream<List<Class>> getAllClasses() {
    return _db
        .collection('classes')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Class.fromFirestore(doc))
            .toList());
  }

  Future<Class?> getClassById(String classId) async {
    final doc = await _db.collection('classes').doc(classId).get();
    if (doc.exists) {
      return Class.fromFirestore(doc);
    }
    return null;
  }

  Future<void> updateClass(String classId, Map<String, dynamic> updates) async {
    await _db.collection('classes').doc(classId).update(updates);
  }

  Future<void> addStudentToClass(String classId, String studentId) async {
    await _db.collection('classes').doc(classId).update({
      'students': FieldValue.arrayUnion([studentId]),
    });
  }

  Future<void> removeStudentFromClass(String classId, String studentId) async {
    await _db.collection('classes').doc(classId).update({
      'students': FieldValue.arrayRemove([studentId]),
    });
  }

  Future<void> deleteClass(String classId) async {
     final students = await _db.collection('students')
        .where('classId', isEqualTo: classId)
        .get();

    for (final student in students.docs) {
      await student.reference.delete();
    }

     final attendance = await _db.collection('attendance')
        .where('classId', isEqualTo: classId)
        .get();

    for (final record in attendance.docs) {
      await record.reference.delete();
    }

     await _db.collection('classes').doc(classId).delete();
  }
}
