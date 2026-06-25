import 'dart:math';
import '../models/student.dart';

class StudentMatch {
  final Student student;
  final double compatibilityScore;
  final Map<String, double> attributeScores;
  /// Per-field match % shown in roommate match charts.
  final Map<String, double> fieldScores;

  StudentMatch(
    this.student,
    this.compatibilityScore,
    this.attributeScores, [
    Map<String, double>? fieldScores,
  ]) : fieldScores = fieldScores ?? const {};

  @override
  String toString() {
    return '${student.name} - ${compatibilityScore.toStringAsFixed(2)}% compatible';
  }
}

class RoommateMatchingEngine {
  static const double lifestyleWeight = 0.35; // Sleep, Food, Introvert/Extrovert, Study Env
  static const double budgetWeight = 0.25;    // Budget similarity
  static const double habitsWeight = 0.20;    // Smoking, Drinking, Cleanliness
  static const double skillsWeight = 0.20;    // Skill teaching/learning overlap

  StudentMatch calculateDetailedCompatibility(Student target, Student candidate) {
    final fieldScores = <String, double>{
      'Sleep Schedule': _scoreSleep(target, candidate),
      'Social Style': _scoreSocial(target, candidate),
      'Study Environment': _scoreStudy(target, candidate),
      'Guest Preference': _scoreGuest(target, candidate),
      'Budget': _calculateBudgetCompatibility(target, candidate),
      'Smoking': _scoreSmoking(target, candidate),
      'Cleanliness': _scoreCleanliness(target, candidate),
      'Skills Match': _calculateSkillsCompatibility(target, candidate),
    };

    double lifestyleScore = _average([
      fieldScores['Sleep Schedule']!,
      fieldScores['Social Style']!,
      fieldScores['Study Environment']!,
      fieldScores['Guest Preference']!,
    ]);
    double budgetScore = fieldScores['Budget']!;
    double habitsScore = _average([
      fieldScores['Smoking']!,
      fieldScores['Cleanliness']!,
    ]);
    double skillsScore = fieldScores['Skills Match']!;

    double totalScore = (lifestyleScore * lifestyleWeight) +
        (budgetScore * budgetWeight) +
        (habitsScore * habitsWeight) +
        (skillsScore * skillsWeight);

    Map<String, double> attributeScores = {
      'Lifestyle': lifestyleScore,
      'Budget': budgetScore,
      'Habits': habitsScore,
      'Skills/Interests': skillsScore,
    };

    return StudentMatch(
      candidate,
      double.parse(totalScore.toStringAsFixed(2)),
      attributeScores,
      fieldScores,
    );
  }

  double _average(List<double> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  double _scoreSleep(Student s1, Student s2) {
    if (s1.sleepSchedule == s2.sleepSchedule) return 100;
    if (s1.sleepSchedule == 'Flexible' || s2.sleepSchedule == 'Flexible') return 70;
    return 20;
  }

  double _scoreSocial(Student s1, Student s2) {
    if (s1.introvertExtrovert == s2.introvertExtrovert) return 100;
    if (s1.introvertExtrovert == 'Ambivert' || s2.introvertExtrovert == 'Ambivert') return 80;
    return 40;
  }

  double _scoreStudy(Student s1, Student s2) {
    if (s1.studyEnvironment == s2.studyEnvironment) return 100;
    return 40;
  }

  double _scoreGuest(Student s1, Student s2) {
    if (s1.guestPreference == s2.guestPreference) return 100;
    return 50;
  }

  double _scoreSmoking(Student s1, Student s2) {
    return s1.smoker == s2.smoker ? 100 : 60;
  }

  double _scoreCleanliness(Student s1, Student s2) {
    final diff = (s1.cleanlinessLevel - s2.cleanlinessLevel).abs();
    return max(0, 100 - (diff * 10)).toDouble();
  }

  double _calculateBudgetCompatibility(Student s1, Student s2) {
    double maxBudget = max(s1.budget, s2.budget);
    if (maxBudget == 0) return 100.0;
    double diff = (s1.budget - s2.budget).abs();
    double percentageDiff = (diff / maxBudget) * 100;
    return max(0, 100 - percentageDiff);
  }

  double _calculateSkillsCompatibility(Student s1, Student s2) {
    Set<String> s1Skills = s1.skills.toSet();
    Set<String> s2Skills = s2.skills.toSet();
    Set<String> s1Learning = s1.learningSkills.toSet();
    Set<String> s2Learning = s2.learningSkills.toSet();

    // Mutual skill teaching/learning score
    double score = 0;
    
    // s1 can teach s2
    var s1CanTeachS2 = s1Skills.intersection(s2Learning);
    if (s1CanTeachS2.isNotEmpty) score += 50;

    // s2 can teach s1
    var s2CanTeachS1 = s2Skills.intersection(s1Learning);
    if (s2CanTeachS1.isNotEmpty) score += 50;

    // Common interests
    var commonSkills = s1Skills.intersection(s2Skills);
    if (commonSkills.isNotEmpty) score += 20;

    return min(100.0, score);
  }

  List<StudentMatch> findBestMatches(Student targetStudent, List<Student> candidates, int topN) {
    List<StudentMatch> matches = [];

    for (var candidate in candidates) {
      if (candidate.studentId == targetStudent.studentId ||
          candidate.assignedRoomId != null) {
        continue;
      }
      
      // STRICT Gender Filter: Female matches with Female, Male matches with Male
      if (targetStudent.gender != candidate.gender) {
        continue;
      }

      matches.add(calculateDetailedCompatibility(targetStudent, candidate));
    }

    matches.sort((a, b) => b.compatibilityScore.compareTo(a.compatibilityScore));
    return matches.take(topN).toList();
  }
}
