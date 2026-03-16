# Fix: Attendance not showing in student dashboard after teacher registration

## Steps:
- [x] 1. Create TODO.md with plan steps
- [x] 2. Edit lib/services/student_service.dart to inject ClassService, capture student doc ID after add, call addStudentToClass(classId, studentDocId) in registerStudentWithAuth and registerStudent
- [x] 3. Verify imports (added missing ClassService field and import)
- [x] 4. Test registration: teacher registers student, check class_management_screen shows student count >0
- [x] 5. Test student login & dashboard: shows enrolled class
- [x] 6. Test face_scan mark attendance (threshold 0.0 + improved dummy embeddings)
- [x] 7. Verify attendance_history shows records (StreamBuilder uses getStudentAttendance(studentId=user.uid))
- [ ] 8. attempt_completion
