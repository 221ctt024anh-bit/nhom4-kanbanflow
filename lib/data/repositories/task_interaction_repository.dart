import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/task_attachment.dart';
import '../../domain/entities/task_comment.dart';
import '../../domain/entities/task_rating.dart';

class TaskInteractionRepository {
  static const String attachmentsBucket = 'task-attachments';
  final SupabaseClient _client;

  TaskInteractionRepository({
    SupabaseClient? client,
  }) : _client = client ?? Supabase.instance.client;

  Future<List<TaskComment>> getComments(String taskId) async {
    final response = await _client
        .from('task_comments')
        .select()
        .eq('task_id', taskId)
        .order('created_at', ascending: true);

    return (response as List).map((item) {
      final map = item as Map<String, dynamic>;
      return TaskComment(
        id: map['id'] as String,
        taskId: map['task_id'] as String,
        userId: (map['user_id'] as String?) ?? '',
        content: (map['content'] as String?) ?? '',
        createdAt: (map['created_at'] as String?) ?? '',
      );
    }).toList();
  }

  Future<TaskComment> addComment({
    required String taskId,
    required String userId,
    required String content,
  }) async {
    final response = await _client
        .from('task_comments')
        .insert({'task_id': taskId, 'user_id': userId, 'content': content})
        .select()
        .single();

    return TaskComment(
      id: response['id'] as String,
      taskId: response['task_id'] as String,
      userId: (response['user_id'] as String?) ?? '',
      content: (response['content'] as String?) ?? '',
      createdAt: (response['created_at'] as String?) ?? '',
    );
  }

  Future<void> deleteComment(String commentId) async {
    await _client.from('task_comments').delete().eq('id', commentId);
  }

  Future<List<TaskAttachment>> getAttachments(String taskId) async {
    final response = await _client
        .from('task_attachments')
        .select()
        .eq('task_id', taskId)
        .order('created_at', ascending: false);

    return (response as List).map((item) {
      final map = item as Map<String, dynamic>;
      return TaskAttachment(
        id: map['id'] as String,
        taskId: map['task_id'] as String,
        fileName: (map['file_name'] as String?) ?? 'unknown',
        filePath: (map['file_path'] as String?) ?? '',
        publicUrl: (map['public_url'] as String?) ?? '',
        uploaderId: (map['uploader_id'] as String?) ?? '',
        createdAt: (map['created_at'] as String?) ?? '',
      );
    }).toList();
  }

  Future<TaskAttachment> uploadAttachment({
    required String boardId,
    required String taskId,
    required String fileName,
    required Uint8List bytes,
    required String uploaderId,
    String? contentType,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final filePath = '$boardId/$taskId/${timestamp}_$safeName';

    await _client.storage
        .from(attachmentsBucket)
        .uploadBinary(
          filePath,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );

    final publicUrl = _client.storage
        .from(attachmentsBucket)
        .getPublicUrl(filePath);
    final inserted = await _client
        .from('task_attachments')
        .insert({
          'task_id': taskId,
          'file_name': fileName,
          'file_path': filePath,
          'public_url': publicUrl,
          'uploader_id': uploaderId,
        })
        .select()
        .single();

    return TaskAttachment(
      id: inserted['id'] as String,
      taskId: inserted['task_id'] as String,
      fileName: (inserted['file_name'] as String?) ?? fileName,
      filePath: (inserted['file_path'] as String?) ?? filePath,
      publicUrl: (inserted['public_url'] as String?) ?? publicUrl,
      uploaderId: (inserted['uploader_id'] as String?) ?? uploaderId,
      createdAt: (inserted['created_at'] as String?) ?? '',
    );
  }

  Future<void> deleteAttachment(TaskAttachment attachment) async {
    if (attachment.filePath.isNotEmpty) {
      await _client.storage.from(attachmentsBucket).remove([
        attachment.filePath,
      ]);
    }
    await _client.from('task_attachments').delete().eq('id', attachment.id);
  }

  Future<Uint8List> downloadAttachment(String filePath) async {
    return await _client.storage.from(attachmentsBucket).download(filePath);
  }

  Future<(double average, int count)> getRatingStats(String taskId) async {
    final response = await _client
        .from('task_ratings')
        .select('rating')
        .eq('task_id', taskId);
    final rows = response as List;
    if (rows.isEmpty) return (0.0, 0);

    var sum = 0;
    for (final row in rows) {
      final map = row as Map<String, dynamic>;
      sum += (map['rating'] as num).toInt();
    }
    return (sum / rows.length, rows.length);
  }

  Future<TaskRating?> getMyRating({
    required String taskId,
    required String userId,
  }) async {
    final response = await _client
        .from('task_ratings')
        .select()
        .eq('task_id', taskId)
        .eq('user_id', userId)
        .maybeSingle();
    if (response == null) return null;

    return TaskRating(
      id: response['id'] as String,
      taskId: response['task_id'] as String,
      userId: response['user_id'] as String,
      rating: (response['rating'] as num).toInt(),
      createdAt: (response['created_at'] as String?) ?? '',
      updatedAt: (response['updated_at'] as String?) ?? '',
    );
  }

  Future<void> upsertRating({
    required String taskId,
    required String userId,
    required int rating,
  }) async {
    await _client.from('task_ratings').upsert({
      'task_id': taskId,
      'user_id': userId,
      'rating': rating,
    }, onConflict: 'task_id,user_id');
  }
}
