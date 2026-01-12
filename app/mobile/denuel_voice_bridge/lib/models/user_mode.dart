/// User mode enum for separating Adult and Child experiences
enum UserMode {
  child,
  adult,
}

/// Extension methods for UserMode
extension UserModeExtension on UserMode {
  String get displayName {
    switch (this) {
      case UserMode.child:
        return 'Child Mode';
      case UserMode.adult:
        return 'Adult Mode';
    }
  }

  String get description {
    switch (this) {
      case UserMode.child:
        return 'Fun, game-based speech practice with friendly avatar';
      case UserMode.adult:
        return 'Professional speech training with detailed analytics';
    }
  }
}
