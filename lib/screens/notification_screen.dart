// lib/screens/notification_page.dart

import 'package:flutter/material.dart';
import 'package:whoreads/core/router/app_router.dart';
import 'package:whoreads/services/notification/notification_service.dart';
import 'package:whoreads/widgets/notification_widget.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  late final NotificationService _notificationService;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _notificationService = NotificationService();
    _loadData();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadData() async {
    await _notificationService.refresh();
    if (mounted) setState(() {});
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_notificationService.isLoading && _notificationService.hasNext) {
        _notificationService.fetchMore().then((_) {
          if (mounted) setState(() {});
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(context),
      // 바디 부분을 함수로 호출
      body: _buildBody(),
    );
  }

  /// 앱바 영역 분리
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        '알림',
        style: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildBody() {
    final list = _notificationService.notifications;

    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFFFF7043),
      child: _buildListContent(list),
    );
  }

  /// 데이터 상태에 따른 실제 리스트/메시지 렌더링
  Widget _buildListContent(List<dynamic> list) {
    if (list.isEmpty && !_notificationService.isLoading) {
      return const Center(
        child: Text(
          "새로운 알림이 없습니다.",
          style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 14),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: list.length + (_notificationService.hasNext ? 1 : 0),
      itemBuilder: (context, index) {
        // 리스트의 마지막 아이템이 로딩바인 경우
        if (index == list.length) {
          return _buildLoadingIndicator();
        }

        final item = list[index];
        return _buildNotificationItem(item);
      },
    );
  }

  Widget _buildNotificationItem(dynamic item) {
    return NotificationWidget(
      type: NotificationType.fromString(item['type']),
      body: item['title'] + item['body'] ?? '',
      time: item['time'] ?? '',
      isRead: item['is_read'] ?? false,
      onTap: () async {
        // 읽음 처리

        if (item['is_read'] == false) {
          await _notificationService.markAsRead(item['id']);
          if (mounted) setState(() {});
        }

        debugPrint("딥링크 데이터 : ${item.toString()}");
        // 딥링크 이동 로직
        _handleDeepLink(item['type'], item['link'] ?? {});

        if (item['type'] == 'ROUTINE') {
          _notificationService.removeNotification(item['id']);
          await _notificationService.refresh();
          if (mounted) setState(() {});
        }
      },
    );
  }

  /// 추가 데이터 로딩 시 하단에 보여줄 인디케이터
  Widget _buildLoadingIndicator() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: CircularProgressIndicator(
          color: Color(0xFFFF7043),
          strokeWidth: 2,
        ),
      ),
    );
  }

  /// 딥링크 라우팅 로직 분리
  void _handleDeepLink(String type, dynamic linkData) {
    final String? celebrityId = linkData['celebrity_id']?.toString();

    debugPrint("딥링크 데이터: type=$type, celebrityId=$celebrityId");

    if (type == 'ROUTINE') {
      AppRouter.navigateTo('/timer');
    } else if (type == 'FOLLOW' && celebrityId != null) {
      AppRouter.navigateTo('/celebrity/book', arguments: celebrityId);
    }
  }
}
