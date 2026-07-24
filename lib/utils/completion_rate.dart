import 'dart:math';
import '../models/program_model.dart';

/// Computes the effective completion rate for a program.
///
/// Uses the "worst deficit" formula: takes the larger of
/// (total credit deficit, external credit deficit) and subtracts
/// it from total required credits, then divides by total required.
double computeEffectiveCompletionRate(EligibilityResult result) {
  if (result.totalCreditsRequired == 0) return 0.0;
  
  int groupDeficitsSum = 0;
  for (final g in result.groups) {
    groupDeficitsSum += (g.creditsRequired - g.creditsEarned).clamp(0, 999999);
  }
  final overallDeficit = (result.totalCreditsRequired - result.totalCreditsEarned).clamp(0, 999999);
  final totalDeficit = max(overallDeficit, groupDeficitsSum);

  final extDeficit =
      (result.externalCreditsRequired - result.externalCreditsEarned).clamp(0, 999999);
  final effectiveDeficit = max(totalDeficit, extDeficit);
  return ((result.totalCreditsRequired - effectiveDeficit) /
          result.totalCreditsRequired)
      .clamp(0.0, 1.0);
}

/// Computes the minimum completion rate (used for range display).
/// Uses the result's completionRange.minRate if available,
/// otherwise falls back to the standard calculation.
double computeMinCompletionRate(EligibilityResult result) {
  if (result.completionRange.hasRange) {
    return result.completionRange.minRate;
  }
  return computeEffectiveCompletionRate(result);
}