import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/auth/token_storage.dart';
import '../../models/dna_models.dart';
import 'DnaResultPage.dart';

class DnaTestPage extends StatefulWidget {
  const DnaTestPage({super.key});

  @override
  State<DnaTestPage> createState() => _DnaTestPageState();
}

class _DnaTestPageState extends State<DnaTestPage> {
  bool isLoading = true;
  bool isNextLoading = false;
  String? errorMessage;

  List<DnaQuestion> questions = [];
  int currentIndex = 0;
  DnaOption? _selectedOption;

  String? trackCode;
  List<int> selectedOptionIds = [];

  final List<String> _trackCodes = [
    'COMFORT', 'HABIT', 'CAREER', 'INSIGHT', 'FOCUS'
  ];

  final Color primaryOrange = const Color(0xFFFF6A00);
  final Color greyColor = const Color(0xFFE0E0E0);

  @override
  void initState() {
    super.initState();
    _fetchRootQuestion();
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await TokenStorage.getAccessToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  // [API 1] Q1 로드
  Future<void> _fetchRootQuestion() async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('http://43.201.122.162/api/dna/questions/root');

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final result = data['result'];

        setState(() {
          // Q1 데이터를 리스트에 안전하게 넣기
          if (result is List) {
            if (result.isNotEmpty) {
              questions = [DnaQuestion.fromJson(result[0])];
            }
          } else {
            questions = [DnaQuestion.fromJson(result)];
          }
          isLoading = false;
        });
      } else {
        throw Exception('Q1 로드 실패: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = "질문 로드 중 오류가 발생했습니다.\n$e";
      });
    }
  }

  // [API 2] 트랙 질문 로드
  Future<void> _fetchTrackQuestions(String code) async {
    setState(() => isNextLoading = true);

    try {
      final headers = await _getHeaders();
      final url = Uri.parse('http://43.201.122.162/api/dna/questions?trackCode=$code');

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final resultData = data['result'];

        // result 안에 questions 리스트가 있는지 확인
        final questionsList = resultData['questions'];

        setState(() {
          if (questionsList is List) {
            questions.addAll(questionsList.map((e) => DnaQuestion.fromJson(e)).toList());
          }

          _selectedOption = null;
          currentIndex++;
          isNextLoading = false;
        });
      } else {
        throw Exception('트랙 질문 로드 실패: ${response.statusCode}');
      }
    } catch (e) {
      _showError('다음 질문 로드 실패: $e');
      setState(() => isNextLoading = false);
    }
  }

  // [API 3] 결과 제출
  Future<void> _submitResult() async {
    setState(() => isNextLoading = true);
    if (_selectedOption != null) {
      selectedOptionIds.add(_selectedOption!.id);
    }

    try {
      final headers = await _getHeaders();
      final url = Uri.parse('http://43.201.122.162/api/dna/results');

      final body = jsonEncode({
        "track_code": trackCode,
        "selected_option_ids": selectedOptionIds,
      });

      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final resultData = DnaResult.fromJson(data['result']);

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => DnaResultPage(result: resultData)),
        );
      } else {
        throw Exception('결과 제출 실패: ${response.statusCode}');
      }
    } catch (e) {
      _showError('결과 분석 중 오류가 발생했습니다.');
      setState(() => isNextLoading = false);
    }
  }

  void _onNextPressed() {
    if (_selectedOption == null) return;

    if (currentIndex == 0) {
      // Q1 처리
      if (_selectedOption!.code != null && _selectedOption!.code!.isNotEmpty) {
        trackCode = _selectedOption!.code;
      } else {
        // 하드코딩 매핑
        final int index = questions[0].options.indexOf(_selectedOption!);
        if (index >= 0 && index < _trackCodes.length) {
          trackCode = _trackCodes[index];
        }
      }

      if (trackCode != null) {
        _fetchTrackQuestions(trackCode!);
      } else {
        _showError("트랙 정보를 찾을 수 없습니다.");
      }
    }
    else if (currentIndex < questions.length - 1) {
      // Q2~Q4 처리
      selectedOptionIds.add(_selectedOption!.id);
      setState(() {
        _selectedOption = null;
        currentIndex++;
      });
    }
    else {
      // Q5 처리
      _submitResult();
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: Color(0xFFFF6A00))),
      );
    }

    if (errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: Text(errorMessage!)),
      );
    }

    if (questions.isEmpty || currentIndex >= questions.length) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: Text("표시할 질문이 없습니다.")),
      );
    }

    final currentQuestion = questions[currentIndex];
    final bool isButtonEnabled = _selectedOption != null;

    // [핵심 수정] step이 있으면 step을 쓰고, 없으면(null) currentIndex + 1을 사용
    final int displayStep = currentQuestion.step ?? (currentIndex + 1);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Center(
              child: Text(
                '$displayStep/5', // 수정된 step 표시 로직 적용
                style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          )
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    // 질문 번호
                    Text(
                      'Q$displayStep.', // 수정된 step 표시 로직 적용
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primaryOrange),
                    ),
                    const SizedBox(height: 8),
                    // 질문 내용
                    Text(
                      currentQuestion.content,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 1.4, color: Colors.black),
                    ),
                    const SizedBox(height: 40),

                    // 답변 리스트
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: currentQuestion.options.length,
                      separatorBuilder: (ctx, idx) => const SizedBox(height: 12),
                      itemBuilder: (ctx, idx) {
                        final option = currentQuestion.options[idx];
                        final isSelected = _selectedOption?.id == option.id;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedOption = option;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? primaryOrange : greyColor,
                                width: isSelected ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected ? Icons.check_circle : Icons.check_circle_outline,
                                  color: isSelected ? primaryOrange : greyColor,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    option.content,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // 하단 버튼
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: (isButtonEnabled && !isNextLoading) ? _onNextPressed : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1C1C22),
                    disabledBackgroundColor: const Color(0xFFDDDDDD),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: isNextLoading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('다음', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}