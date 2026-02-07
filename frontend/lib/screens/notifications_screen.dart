import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:frontend/data/client.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<Map<String, dynamic>>> _notificationsFuture;
  DateTime? _selectedDate;
  final _apiClient = ApiClient();

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  void _loadNotifications() {
    setState(() {
      _notificationsFuture = _apiClient.getNotifications(date: _selectedDate);
    });
  }

  void _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      _loadNotifications();
    }
  }

  void _clearDateFilter() {
    setState(() {
      _selectedDate = null;
    });
    _loadNotifications();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'ON_TRACK':
        return Colors.green;
      case 'WARNING':
        return Colors.orange;
      case 'OVERSPENT':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Icon _getStatusIcon(String status) {
    switch (status) {
      case 'ON_TRACK':
        return const Icon(Icons.check_circle, color: Colors.green);
      case 'WARNING':
        return const Icon(Icons.warning, color: Colors.orange);
      case 'OVERSPENT':
        return const Icon(Icons.error, color: Colors.red);
      default:
        return const Icon(Icons.info, color: Colors.grey);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget Notifications'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Date filter section
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Filter by Date',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedDate != null
                            ? DateFormat('MMMM dd, yyyy').format(_selectedDate!)
                            : 'All dates',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _selectDate,
                  icon: const Icon(Icons.calendar_today),
                  label: const Text('Select'),
                ),
                if (_selectedDate != null)
                  TextButton(
                    onPressed: _clearDateFilter,
                    child: const Text('Clear'),
                  ),
              ],
            ),
          ),
          // Notifications list
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _notificationsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadNotifications,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final notifications = snapshot.data ?? [];

                if (notifications.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_none,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _selectedDate != null
                              ? 'No notifications for this date'
                              : 'No notifications',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    _loadNotifications();
                    await _notificationsFuture;
                  },
                  child: ListView.builder(
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      final status = notification['status'] as String? ?? 'UNKNOWN';
                      final message = notification['message'] as String? ?? '';
                      final timestamp = notification['timestamp'] as String? ?? '';
                      final data = notification['data'] as Map<String, dynamic>? ?? {};
                      final shouldNotify = notification['shouldNotify'] as bool? ?? false;

                      DateTime? notifTime;
                      try {
                        notifTime = DateTime.parse(timestamp);
                      } catch (_) {}

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header with status icon and time
                              Row(
                                children: [
                                  _getStatusIcon(status),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          status,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: _getStatusColor(status),
                                          ),
                                        ),
                                        if (notifTime != null)
                                          Text(
                                            DateFormat('MMM dd, yyyy HH:mm').format(notifTime),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (shouldNotify)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.amber[100],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'Alert',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.amber,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Message
                              Text(
                                message,
                                style: const TextStyle(fontSize: 14),
                              ),
                              // Data details
                              if (data.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                _buildDataDetails(data),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataDetails(Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (data['spent'] != null)
            _buildDetailRow('Spent', '\$${(data['spent'] as num).toStringAsFixed(2)}'),
          if (data['limit'] != null)
            _buildDetailRow('Budget Limit', '\$${(data['limit'] as num).toStringAsFixed(2)}'),
          if (data['remaining'] != null)
            _buildDetailRow('Remaining', '\$${(data['remaining'] as num).toStringAsFixed(2)}'),
          if (data['percentUsed'] != null)
            _buildDetailRow('Percentage Used', '${(data['percentUsed'] as num).toStringAsFixed(0)}%'),
          if (data['period'] != null)
            _buildDetailRow('Period', data['period'].toString()),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
