import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/tutorial_service.dart';

/// Provides a [TutorialService] instance for dependency injection via Riverpod.
final tutorialServiceProvider = Provider<TutorialService>((_) => TutorialService());
