import 'package:google_generative_ai/google_generative_ai.dart';
import '../constants/ai_constants.dart';

class AiService {
  late final GenerativeModel _model;

  AiService() {
    final key = AiConstants.geminiApiKey.trim();
    // ignore: avoid_print
    print(
      'DEBUG: AiService initialized. Key length: ${key.length}. Masked: ${key.substring(0, 5)}...${key.substring(key.length - 4)}',
    );
    _model = GenerativeModel(model: AiConstants.modelName, apiKey: key);
  }

  /// Làm sạch và tối ưu hóa văn bản mô tả công việc
  Future<String> polishText({
    required String text,
    required String title,
    List<String>? checklistItems,
  }) async {
    if (text.trim().isEmpty) return text;

    final checklistContext = checklistItems != null && checklistItems.isNotEmpty
        ? 'Có danh sách các công việc con như sau: ${checklistItems.join(", ")}'
        : '';

    final prompt =
        '''
Bạn là một trợ lý quản lý dự án chuyên nghiệp. 
Hãy viết lại đoạn mô tả công việc cho task: "$title".
$checklistContext
Dựa trên các thông tin trên, hãy tối ưu hóa nội dung mô tả dưới đây để nó trở nên chuyên nghiệp, rõ ràng và súc tích hơn. 
**YÊU CẦU QUAN TRỌNG:** 
- Trình bày rõ ràng, đi thẳng vào vấn đề. 
- Không viết lời dẫn rườm rà (ví dụ: "Chào bạn...", "Dưới đây là phương án...").
- Sử dụng định dạng Markdown hiệu quả.
Giữ nguyên ý nghĩa gốc và ngôn ngữ gốc (Tiếng Việt).

Nội dung mô tả cần viết lại:
"$text"
''';

    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      return response.text ?? text;
    } catch (e) {
      print('AI Service Error (polishText): $e');
      return text;
    }
  }

  /// Phân tích mô tả và tạo danh sách checklist các công việc cần làm
  Future<List<String>> generateChecklist(String description) async {
    if (description.trim().isEmpty) return [];

    final prompt =
        '''
Dựa trên mô tả công việc sau đây, hãy trích xuất hoặc gợi ý một danh sách các bước thực hiện (checklist).
Chỉ trả về danh sách các đầu mục công việc, mỗi mục trên một dòng. 
Không thêm lời dẫn hay số thứ tự.
Ngôn ngữ: Tiếng Việt.
Mô tả:
"$description"
''';

    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      final text = response.text;
      if (text == null) return [];

      return text
          .split('\n')
          .map((e) => e.replaceAll(RegExp(r'^[-*•]\s*'), '').trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } catch (e) {
      print('AI Service Error (generateChecklist): $e');
      return [];
    }
  }
}
