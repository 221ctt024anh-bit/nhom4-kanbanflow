import 'package:flutter/material.dart';
import 'package:mime/mime.dart';
import '../../../domain/entities/task_attachment.dart';
import '../../../app_preferences.dart';
import 'task_details_utils.dart';

class TaskAttachments extends StatelessWidget {
  final List<TaskAttachment> attachments;
  final String? role;
  final bool loading;
  final bool uploading;
  final VoidCallback onPickAndUpload;
  final Function(TaskAttachment) onOpen;
  final Function(TaskAttachment) onDelete;

  const TaskAttachments({
    super.key,
    required this.attachments,
    required this.role,
    required this.loading,
    required this.uploading,
    required this.onPickAndUpload,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TaskDetailsUtils.buildSectionTitle(
          AppPreferences.tr('TỆP ĐÍNH KÈM', 'ATTACHMENTS'),
          trailing: role == 'viewer'
              ? const SizedBox.shrink()
              : TextButton.icon(
                  onPressed: uploading ? null : onPickAndUpload,
                  icon: uploading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_circle_outline, size: 16),
                  label: Text(AppPreferences.tr('Thêm tệp', 'Add file')),
                ),
        ),
        const SizedBox(height: 12),
        if (loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          )
        else if (attachments.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
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
            child: Center(
              child: Text(
                AppPreferences.tr('Chưa có tệp đính kèm', 'No attachments yet'),
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontStyle: FontStyle.italic,
                  fontSize: 14,
                ),
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.4,
            ),
            itemCount: attachments.length,
            itemBuilder: (context, index) {
              final item = attachments[index];
              final isImage =
                  lookupMimeType(item.fileName)?.startsWith('image/') == true;
              final isAudio =
                  lookupMimeType(item.fileName)?.startsWith('audio/') == true;

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => onOpen(item),
                  child: Stack(
                    children: [
                      if (isImage)
                        Positioned.fill(
                          child: Image.network(
                            item.publicUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: const Color(0xFFF1F5F9),
                              child: const Icon(
                                Icons.broken_image,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        )
                      else
                        Positioned.fill(
                          child: Container(
                            color: const Color(0xFFF1F5F9),
                            child: Icon(
                              isAudio
                                  ? Icons.mic_rounded
                                  : Icons.insert_drive_file_outlined,
                              size: 32,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withOpacity(0.7),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.fileName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                onPressed: role == 'viewer'
                                    ? null
                                    : () => onDelete(item),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class PriorityPreview extends StatelessWidget {
  final List<TaskAttachment> attachments;
  final bool loading;
  final Function(TaskAttachment) onOpen;

  const PriorityPreview({
    super.key,
    required this.attachments,
    required this.loading,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const SizedBox.shrink();
    if (attachments.isEmpty) return const SizedBox.shrink();

    final imageIndex = attachments.indexWhere(
      (e) => lookupMimeType(e.fileName)?.startsWith('image/') == true,
    );

    if (imageIndex != -1) {
      final image = attachments[imageIndex];
      return Container(
        width: double.infinity,
        height: 280,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => onOpen(image),
                child: Image.network(
                  image.publicUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(
                      Icons.broken_image,
                      size: 64,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton.small(
                onPressed: () => onOpen(image),
                backgroundColor: Colors.white,
                child: const Icon(
                  Icons.fullscreen_rounded,
                  color: Colors.blueAccent,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
