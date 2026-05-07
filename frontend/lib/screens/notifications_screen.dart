/// SmartDoz - Bildirim Ekranı
///
/// İlaç alınmadığında gelen bildirimleri ve caregiver
/// tarafından gelen uyarıları görüntülemek için.
library;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import '../models/notification.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';

const _kPrimary = Color(0xFF1565C0);
const _kSuccess = Color(0xFF2E7D32);
const _kWarning = Color(0xFFF57F17);
const _kDanger = Color(0xFFC62828);
const _kBg = Color(0xFFF0F4FF);
const _kTextDark = Color(0xFF0D1B2A);
const _kTextMid = Color(0xFF455A64);

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  NotificationList? _notificationList;
  bool _isLoading = false;
  int _currentPage = 0;
  static const int _pageSize = 20;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    // Her 30 saniyede bir bildirimleri yenile
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _loadNotifications(page: _currentPage);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadNotifications({int page = 0}) async {
    setState(() => _isLoading = true);
    try {
      final notifList = await context.read<ApiService>().getNotifications(
            skip: page * _pageSize,
            limit: _pageSize,
          );
      if (mounted) {
        setState(() {
          _notificationList = notifList;
          _currentPage = page;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: _kDanger,
          ),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _markAsRead(MissedDoseNotification notification) async {
    if (notification.isRead) return;

    try {
      await context
          .read<ApiService>()
          .markNotificationsAsRead([notification.id]);
      if (mounted) {
        _loadNotifications(page: _currentPage);
        // Sistem bildiriminde kaldır (push notification)
        await NotificationService.cancelNotification(notification.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: _kDanger,
          ),
        );
      }
    }
  }

  Future<void> _markAllAsRead() async {
    if (_notificationList == null || _notificationList!.notifications.isEmpty) {
      return;
    }

    final unreadIds = _notificationList!.notifications
        .where((n) => !n.isRead)
        .map((n) => n.id)
        .toList();

    if (unreadIds.isEmpty) return;

    try {
      await context.read<ApiService>().markNotificationsAsRead(unreadIds);
      if (mounted) {
        // Tüm sistem bildirimlerini kaldır
        for (final id in unreadIds) {
          await NotificationService.cancelNotification(id);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Tüm bildirimler okundu işaretlendi'),
            backgroundColor: _kSuccess,
          ),
        );
        _loadNotifications(page: _currentPage);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: _kDanger,
          ),
        );
      }
    }
  }

  String _getNotificationIcon(String type) {
    switch (type) {
      case 'MISSED_DOSE':
        return '⚠️';
      case 'OVERDOSE':
        return '🚨';
      case 'EXPIRY':
        return '⏰';
      default:
        return 'ℹ️';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.notifications_rounded, size: 22),
            SizedBox(width: 8),
            Text(
              'Bildirimler',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        actions: [
          if (_notificationList != null && _notificationList!.unreadCount > 0)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: IconButton(
                icon: const Icon(Icons.done_all),
                onPressed: _markAllAsRead,
                tooltip: 'Tümünü okundu işaretle',
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notificationList == null || _notificationList!.notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_none_rounded,
                        size: 64,
                        color: _kTextMid.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Bildirim yok',
                        style: TextStyle(
                          fontSize: 16,
                          color: _kTextMid,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // ── Bildirim Başlığı ──────────────────
                    if (_notificationList!.unreadCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _kWarning.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _kWarning.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_rounded,
                                color: _kWarning,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${_notificationList!.unreadCount} okunmamış bildiriminiz var',
                                  style: const TextStyle(
                                    color: _kWarning,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // ── Bildirim Listesi ───────────────────
                    ..._notificationList!.notifications
                        .asMap()
                        .entries
                        .map((entry) {
                      final notif = entry.value;
                      return _NotificationCard(
                        notification: notif,
                        icon: _getNotificationIcon(notif.notificationType),
                        onTap: () => _markAsRead(notif),
                      );
                    }),

                    // ── Sayfalama ──────────────────────────
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_currentPage > 0)
                          ElevatedButton.icon(
                            onPressed: () =>
                                _loadNotifications(page: _currentPage - 1),
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Önceki'),
                          ),
                        const SizedBox(width: 12),
                        Text(
                          'Sayfa ${_currentPage + 1}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _kTextDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        if ((_currentPage + 1) * _pageSize < _notificationList!.total)
                          ElevatedButton.icon(
                            onPressed: () =>
                                _loadNotifications(page: _currentPage + 1),
                            icon: const Icon(Icons.arrow_forward),
                            label: const Text('Sonraki'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
    );
  }
}

/// Bildirim kartı widget'ı
class _NotificationCard extends StatelessWidget {
  final MissedDoseNotification notification;
  final String icon;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.notification,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: notification.isRead ? 1 : 2,
        color: notification.isRead
            ? Colors.white
            : _kWarning.withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    icon,
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: notification.isRead
                                ? FontWeight.w500
                                : FontWeight.w700,
                            color: _kTextDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${notification.userName} için',
                          style: const TextStyle(
                            fontSize: 12,
                            color: _kTextMid,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!notification.isRead)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: _kWarning,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                notification.message,
                style: const TextStyle(
                  fontSize: 14,
                  color: _kTextMid,
                  height: 1.5,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    notification.createdAt.toString().split('.')[0],
                    style: TextStyle(
                      fontSize: 12,
                      color: _kTextMid.withOpacity(0.7),
                    ),
                  ),
                  if (!notification.isRead)
                    TextButton.icon(
                      onPressed: () {},
                      style: TextButton.styleFrom(
                        foregroundColor: _kSuccess,
                        padding: EdgeInsets.zero,
                      ),
                      icon: const Icon(Icons.done, size: 16),
                      label: const Text('Oku', style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
