enum AssignmentStatus { none, assigned, accepted, rejected, confirmed }
enum UserRole { student, admin, owner, warden }

class Student {
  String studentId;
  String name;
  String email;
  String phoneNumber;
  int age;
  String gender; // Male / Female
  String department;
  String password;
  UserRole role;
  /// Warden accounts created by owner — only their owner's hostels are visible.
  String? managedByOwnerId;
  /// Owner accounts created by platform admin (not self-signup).
  bool createdByAdmin;
  List<String> skills;
  List<String> learningSkills;
  String otherSkills;

  // PRD Room Preferences
  double budget;
  String preferredLocation;
  bool requiresAC;
  bool requiresAttachedBath;
  bool requiresWifi;
  bool requiresFurnished;
  bool requiresKitchen;
  bool requiresLaundry;
  String preferredSharing; // "Single", "Double", "Any"

  // PRD Lifestyle & Habits
  String occupation; // "Student", "Working Professional", "Other"
  String foodPreference; // "Vegetarian", "Non-Vegetarian", "Any"
  String introvertExtrovert; // "Introvert", "Extrovert", "Ambivert"
  String studyEnvironment; // "Quiet", "Social", "Music"
  String genderPreference; // "Same Gender", "Any"
  String guestPreference; // "Rarely", "Sometimes", "Often"

  // The UI (`UserDetailsScreen`) expects these values.
  // Keep them in the model to avoid compile-time failures.
  double studyHoursPerDay;
  int noiseTolerance; // 1-10 scale
  String guestPolicy; // free-form / or derived from guestPreference
  bool drinker;

  bool smoker;
  int cleanlinessLevel; // 1-10 scale
  String sleepSchedule; // "Early Sleeper", "Night Owl", "Flexible"


  // Favorites & Blocking
  List<String> favoriteStudentIds;
  List<String> blockedStudentIds;

  // Real-time status
  bool isOnline;

  // Room assignment
  String? assignedRoomId;
  String? requestedRoomId;
  String? roommateId;

  // Account status
  bool profileCompleted;
  bool quizCompleted;
  bool paymentVerified;
  AssignmentStatus assignmentStatus;
  bool isAccountBlocked;
  String? blockReason;
  DateTime? blockedAt;
  String? lastLeftRoomId;

  Student({
    this.studentId = '',
    this.name = '',
    this.email = '',
    this.phoneNumber = '',
    this.age = 0,
    this.gender = '',
    this.department = '',
    this.password = '',
    this.role = UserRole.student,
    this.managedByOwnerId,
    this.createdByAdmin = false,
    this.skills = const [],
    this.learningSkills = const [],
    this.otherSkills = '',
    this.budget = 10000.0,
    this.preferredLocation = 'Main Campus',
    this.requiresAC = false,
    this.requiresAttachedBath = false,
    this.requiresWifi = false,
    this.requiresFurnished = false,
    this.requiresKitchen = false,
    this.requiresLaundry = false,
    this.preferredSharing = 'Double',
    this.occupation = 'Student',
    this.foodPreference = 'Any',
    this.introvertExtrovert = 'Ambivert',
    this.studyEnvironment = 'Social',
    this.genderPreference = 'Any',
    this.guestPreference = 'Sometimes',

    // Defaults required by UserDetailsScreen
    this.studyHoursPerDay = 2.0,
    this.noiseTolerance = 5,
    this.guestPolicy = 'Sometimes',
    this.drinker = false,

    this.smoker = false,
    this.cleanlinessLevel = 5,
    this.sleepSchedule = 'Flexible',

    this.favoriteStudentIds = const [],
    this.blockedStudentIds = const [],
    this.isOnline = false,
    this.assignedRoomId,
    this.requestedRoomId,
    this.roommateId,
    this.profileCompleted = false,
    this.quizCompleted = false,
    this.paymentVerified = false,
    this.assignmentStatus = AssignmentStatus.none,
    this.isAccountBlocked = false,
    this.blockReason,
    this.blockedAt,
    this.lastLeftRoomId,
  });

  void updateFrom(Student other) {
    studentId = other.studentId;
    name = other.name;
    email = other.email;
    phoneNumber = other.phoneNumber;
    age = other.age;
    gender = other.gender;
    department = other.department;
    password = other.password;
    role = other.role;
    managedByOwnerId = other.managedByOwnerId;
    createdByAdmin = other.createdByAdmin;
    skills = List.from(other.skills);
    learningSkills = List.from(other.learningSkills);
    otherSkills = other.otherSkills;
    budget = other.budget;
    preferredLocation = other.preferredLocation;
    requiresAC = other.requiresAC;
    requiresAttachedBath = other.requiresAttachedBath;
    requiresWifi = other.requiresWifi;
    requiresFurnished = other.requiresFurnished;
    requiresKitchen = other.requiresKitchen;
    requiresLaundry = other.requiresLaundry;
    preferredSharing = other.preferredSharing;
    occupation = other.occupation;
    foodPreference = other.foodPreference;
    introvertExtrovert = other.introvertExtrovert;
    studyEnvironment = other.studyEnvironment;
    genderPreference = other.genderPreference;
    guestPreference = other.guestPreference;
    smoker = other.smoker;
    cleanlinessLevel = other.cleanlinessLevel;
    sleepSchedule = other.sleepSchedule;
    favoriteStudentIds = List.from(other.favoriteStudentIds);
    blockedStudentIds = List.from(other.blockedStudentIds);
    isOnline = other.isOnline;
    profileCompleted = other.profileCompleted;
    quizCompleted = other.quizCompleted;
    paymentVerified = other.paymentVerified;
    assignmentStatus = other.assignmentStatus;
    assignedRoomId = other.assignedRoomId;
    requestedRoomId = other.requestedRoomId;
    roommateId = other.roommateId;
    isAccountBlocked = other.isAccountBlocked;
    blockReason = other.blockReason;
    blockedAt = other.blockedAt;
    lastLeftRoomId = other.lastLeftRoomId;
  }

  @override
  String toString() {
    return 'Student{studentId: $studentId, name: $name, budget: $budget, assignedRoomId: $assignedRoomId}';
  }
}
