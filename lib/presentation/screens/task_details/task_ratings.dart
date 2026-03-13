import 'package:flutter/material.dart';
import '../../../domain/entities/task_rating.dart';
import '../../../app_preferences.dart';
import 'task_details_utils.dart';

class TaskRatings extends StatelessWidget {
  final TaskRating? myRating;
  final bool loading;
  final bool saving;
  final double avgRating;
  final int ratingCount;
  final Function(int) onRate;

  const TaskRatings({
    super.key,
    this.myRating,
    required this.loading,
    required this.saving,
    required this.avgRating,
    required this.ratingCount,
    required this.onRate,
  });

  @override
  Widget build(BuildContext context) {
    final myScore = myRating?.rating ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TaskDetailsUtils.buildSectionTitle(AppPreferences.tr('ĐÁNH GIÁ TASK', 'TASK RATING')),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: loading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(),
                  ),
                )
              : Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final star = index + 1;
                        final active = star <= myScore;
                        return IconButton(
                          onPressed: saving ? null : () => onRate(star),
                          iconSize: 32,
                          icon: Icon(
                            active
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: active
                                ? Colors.amber[600]
                                : const Color(0xFFCBD5E1),
                          ),
                          tooltip: '$star ${AppPreferences.tr('sao', 'stars')}',
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ratingCount == 0
                          ? AppPreferences.tr(
                              'Chưa có đánh giá',
                              'No ratings yet',
                            )
                          : '${AppPreferences.tr('Trung bình', 'Average')}: ${avgRating.toStringAsFixed(1)}/5 ($ratingCount ${AppPreferences.tr('đánh giá', 'ratings')})',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
