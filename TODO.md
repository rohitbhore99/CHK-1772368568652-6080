# Fix: Attendance not showing in student dashboard after teacher registration

## Steps:
- [x] 1. Create TODO.md with plan steps
- [x] 2. Edit lib/services/student_service.dart to inject ClassService, capture student doc ID after add, call addStudentToClass(classId, studentDocId) in registerStudentWithAuth and registerStudent
- [ ] 3. Verify imports
- [ ] 4. Test registration: teacher registers student, check class_management_screen shows student count >0
- [ ] 5. Test student login & dashboard: shows enrolled class
- [ ] 6. Test face_scan mark attendance
- [ ] 7. Verify attendance_history shows records
- [ ] 8. attempt_completion
