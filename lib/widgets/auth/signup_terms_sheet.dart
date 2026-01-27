import 'package:flutter/material.dart';

class SignupTermsSheet extends StatefulWidget {
  final VoidCallback onAgreed;

  const SignupTermsSheet({
    super.key,
    required this.onAgreed,
  });

  @override
  State<SignupTermsSheet> createState() => _SignupTermsSheetState();
}

class _SignupTermsSheetState extends State<SignupTermsSheet> {
  bool all = false;

  bool age14 = false;     // (필수) 만 14세 이상
  bool terms = false;     // (필수) 서비스 이용약관
  bool privacy = false;   // (필수) 개인정보 수집/이용(필수)
  bool privacyOpt = false;// (선택) 개인정보 수집/이용(선택)
  bool marketing = false; // (선택) 이벤트/혜택 수신

  bool get requiredOk => age14 && terms && privacy;

  void _syncAllFromItems() {
    final nextAll = age14 && terms && privacy && privacyOpt && marketing;
    if (all != nextAll) all = nextAll;
  }

  void _toggleAll(bool value) {
    setState(() {
      all = value;
      age14 = value;
      terms = value;
      privacy = value;
      privacyOpt = value;
      marketing = value;
    });
  }

  void _toggleItem(String key, bool value) {
    setState(() {
      switch (key) {
        case 'age14':
          age14 = value;
          break;
        case 'terms':
          terms = value;
          break;
        case 'privacy':
          privacy = value;
          break;
        case 'privacyOpt':
          privacyOpt = value;
          break;
        case 'marketing':
          marketing = value;
          break;
      }
      _syncAllFromItems();
      // 필수 3개가 모두 체크되면 all은 “부분 체크” 상태가 아니라면 false 유지가 자연스럽습니다.
      // 여기서는 “모두 동의”는 5개 전체가 true일 때만 true로 유지합니다.
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 드래그 핸들
              Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),

              // 모두 동의
              _AllAgreeTile(
                value: all,
                onChanged: _toggleAll,
              ),

              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFE5E7EB)),
              const SizedBox(height: 12),

              _AgreeRow(
                value: age14,
                label: '(필수) 만 14세 이상입니다',
                onChanged: (v) => _toggleItem('age14', v),
                onTapDetail: null,
              ),
              _AgreeRow(
                value: terms,
                label: '(필수) 서비스 이용약관',
                onChanged: (v) => _toggleItem('terms', v),
                onTapDetail: () {
                  // TODO: 약관 상세 페이지/다이얼로그
                },
              ),
              _AgreeRow(
                value: privacy,
                label: '(필수) 개인정보 수집 및 이용에 대한 안내',
                onChanged: (v) => _toggleItem('privacy', v),
                onTapDetail: () {
                  // TODO: 개인정보(필수) 상세
                },
              ),
              _AgreeRow(
                value: privacyOpt,
                label: '(선택) 개인정보 수집 및 이용에 대한 안내',
                onChanged: (v) => _toggleItem('privacyOpt', v),
                onTapDetail: () {
                  // TODO: 개인정보(선택) 상세
                },
              ),
              _AgreeRow(
                value: marketing,
                label: '(선택) 이벤트 등 맞춤 혜택/정보 수신',
                onChanged: (v) => _toggleItem('marketing', v),
                onTapDetail: () {
                  // TODO: 마케팅 수신 상세
                },
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: requiredOk
                      ? () {
                    widget.onAgreed(); // ✅ 부모(OnboardingFlowScreen)에서 정의한 이동 로직 실행
                  }
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1C1C22),
                    disabledBackgroundColor: const Color(0xFFE5E7EB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    '다음',
                    style: TextStyle(
                      color: requiredOk ? Colors.white : const Color(0xFF9CA3AF),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AllAgreeTile extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _AllAgreeTile({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          _CircleCheck(
            value: value,
            onTap: () => onChanged(!value),
            size: 24,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              '모두 동의합니다',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AgreeRow extends StatelessWidget {
  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onTapDetail;

  const _AgreeRow({
    required this.value,
    required this.label,
    required this.onChanged,
    required this.onTapDetail,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            _CircleCheck(
              value: value,
              onTap: () => onChanged(!value),
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                ),
              ),
            ),
            if (onTapDetail != null)
              IconButton(
                onPressed: onTapDetail,
                icon: const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
              ),
          ],
        ),
      ),
    );
  }
}

class _CircleCheck extends StatelessWidget {
  final bool value;
  final VoidCallback onTap;
  final double size;

  const _CircleCheck({
    required this.value,
    required this.onTap,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final Color border = value ? const Color(0xFF1C1C22) : const Color(0xFFD1D5DB);
    final Color fill = value ? const Color(0xFF1C1C22) : Colors.white;
    final Color icon = value ? Colors.white : const Color(0xFFD1D5DB);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: fill,
          border: Border.all(color: border, width: 1.4),
        ),
        child: Icon(Icons.check, size: size * 0.65, color: icon),
      ),
    );
  }
}
