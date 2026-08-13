import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_currency_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../services/local_storage_service.dart';
import '../../services/sms_auto_capture_service.dart';
import '../../utils/formatters.dart';

const _kPrimary = Color(0xFF6C5CE7);
const _kIncome  = Color(0xFF00B894);
const _kExpense = Color(0xFFFF7675);
const _kWarning = Color(0xFFFDCB6E);

class SmsLogScreen extends StatefulWidget {
  const SmsLogScreen({super.key});

  @override
  State<SmsLogScreen> createState() => _SmsLogScreenState();
}

class _SmsLogScreenState extends State<SmsLogScreen> {
  String _selectedFilter = 'All'; // 'All', 'Captured', 'Duplicates', 'Blocked'
  late String _duplicateMode;
  late int _windowMinutes;
  List<Map<String, dynamic>> _logs = [];

  @override
  void initState() {
    super.initState();
    _duplicateMode = LocalStorageService.getDuplicateMode();
    _windowMinutes = LocalStorageService.getDeduplicationWindowMinutes();
    _loadLogs();
  }

  void _loadLogs() {
    setState(() {
      _logs = LocalStorageService.getSmsCaptureLogs();
    });
  }

  Future<void> _changeDuplicateMode(String newMode) async {
    await LocalStorageService.setDuplicateMode(newMode);
    setState(() {
      _duplicateMode = newMode;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_getModeToastMessage(newMode)),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: _kPrimary,
        ),
      );
    }
  }

  String _getModeToastMessage(String mode) {
    switch (mode) {
      case 'allow_all':
        return '🔄 Mode set to: Capture All Duplicates';
      case 'flag_review':
        return '⚠️ Mode set to: Flag & Review Duplicates';
      case 'smart':
      default:
        return '✨ Mode set to: Smart Deduplication (Recommended)';
    }
  }

  Future<void> _forceCaptureSms(Map<String, dynamic> log) async {
    final body = log['body'] as String?;
    if (body == null || body.isEmpty) return;

    final dateStr = log['date'] as String?;
    final date = dateStr != null ? DateTime.tryParse(dateStr) : DateTime.now();
    final sender = log['sender'] as String?;

    final tx = await SmsAutoCaptureService.captureFromSms(
      body,
      smsDate: date,
      senderAddress: sender,
      forceCapture: true,
    );

    if (mounted) {
      if (tx != null) {
        Provider.of<TransactionProvider>(context, listen: false).loadTransactions();
        _loadLogs();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 Added ₹${tx.amount.toStringAsFixed(2)} to Transactions!'),
            backgroundColor: _kIncome,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Could not parse SMS as financial transaction.'),
            backgroundColor: _kExpense,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _scanInboxNow() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔍 Scanning SMS inbox for missed transactions...'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    final count = await SmsAutoCaptureService.scanRecentSms(minutes: 1440);
    _loadLogs();
    if (mounted) {
      Provider.of<TransactionProvider>(context, listen: false).loadTransactions();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(count > 0
              ? '🎉 Captured $count missed transaction(s)!'
              : '✅ Inbox scan finished. No new financial SMS found.'),
          backgroundColor: count > 0 ? _kIncome : _kPrimary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredLogs {
    if (_selectedFilter == 'Captured') {
      return _logs.where((l) => l['status'] == 'captured' || l['status'] == 'flagged_duplicate').toList();
    } else if (_selectedFilter == 'Duplicates') {
      return _logs.where((l) => l['status'] == 'duplicate_suppressed' || l['status'] == 'flagged_duplicate').toList();
    } else if (_selectedFilter == 'Blocked') {
      return _logs.where((l) => l['status'] == 'promo_blocked').toList();
    }
    return _logs;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = Provider.of<ThemeCurrencyProvider>(context).currency;
    final bg = isDark ? const Color(0xFF0E0E1A) : const Color(0xFFF2F4FA);
    final cardBg = isDark ? const Color(0xFF1A1A2E) : Colors.white;

    final capturedCount = _logs.where((l) => l['status'] == 'captured' || l['status'] == 'flagged_duplicate').length;
    final dupCount = _logs.where((l) => l['status'] == 'duplicate_suppressed' || l['status'] == 'flagged_duplicate').length;
    final blockedCount = _logs.where((l) => l['status'] == 'promo_blocked').length;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              size: 20, color: isDark ? Colors.white70 : Colors.black54),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'SMS Capture & Duplicates',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF1A1A2E),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: _kPrimary),
            tooltip: 'Scan Inbox',
            onPressed: _scanInboxNow,
          ),
          if (_logs.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_outline_rounded,
                  color: isDark ? Colors.white54 : Colors.black45),
              tooltip: 'Clear Log History',
              onPressed: () async {
                await LocalStorageService.clearSmsCaptureLogs();
                _loadLogs();
              },
            ),
        ],
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Duplicate Mode Card ──────────────────────────────────────
                _buildModeCard(isDark, cardBg),
                const SizedBox(height: 16),

                // ── Summary Stats Row ────────────────────────────────────────
                Row(
                  children: [
                    _StatBadge(
                      label: 'Captured',
                      count: capturedCount,
                      color: _kIncome,
                      icon: Icons.check_circle_outline,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 10),
                    _StatBadge(
                      label: 'Duplicates',
                      count: dupCount,
                      color: _kWarning,
                      icon: Icons.copy_rounded,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 10),
                    _StatBadge(
                      label: 'Blocked',
                      count: blockedCount,
                      color: Colors.blue,
                      icon: Icons.block_rounded,
                      isDark: isDark,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Filter Chips ─────────────────────────────────────────────
                Row(
                  children: ['All', 'Captured', 'Duplicates', 'Blocked'].map((filter) {
                    final isSel = _selectedFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        selected: isSel,
                        label: Text(filter),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          color: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                        ),
                        selectedColor: _kPrimary,
                        backgroundColor: cardBg,
                        onSelected: (_) => setState(() => _selectedFilter = filter),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // ── Log Items ────────────────────────────────────────────────
                if (_filteredLogs.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.sms_outlined, size: 48, color: isDark ? Colors.white24 : Colors.black26),
                        const SizedBox(height: 12),
                        Text(
                          'No SMS Logs Found',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'When bank or payment app SMS alerts arrive, their capture status & duplicates will appear here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                else
                  ..._filteredLogs.map((log) => _buildLogCard(log, isDark, cardBg, currency)),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeCard(bool isDark, Color cardBg) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _kPrimary.withValues(alpha: isDark ? 0.25 : 0.15)),
        boxShadow: [
          BoxShadow(
            color: _kPrimary.withValues(alpha: isDark ? 0.12 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _kPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.shield_outlined, color: _kPrimary, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Duplicate Handling Feature',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Choose how Pocketify handles duplicate SMS alerts received for the same transaction:',
            style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
          ),
          const SizedBox(height: 14),

          _buildRadioTile(
            title: 'Smart Deduplication (Recommended)',
            subtitle: 'Auto-suppress duplicate SMS received within 3 minutes',
            value: 'smart',
            groupValue: _duplicateMode,
            onChanged: (v) => _changeDuplicateMode(v!),
            isDark: isDark,
          ),
          _buildRadioTile(
            title: 'Flag & Review Duplicates',
            subtitle: 'Capture duplicate SMS but mark as [Possible Duplicate ⚠️]',
            value: 'flag_review',
            groupValue: _duplicateMode,
            onChanged: (v) => _changeDuplicateMode(v!),
            isDark: isDark,
          ),
          _buildRadioTile(
            title: 'Allow All Duplicates',
            subtitle: 'Capture every financial SMS alert without deduplication',
            value: 'allow_all',
            groupValue: _duplicateMode,
            onChanged: (v) => _changeDuplicateMode(v!),
            isDark: isDark,
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Colors.white10),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Deduplication Window',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              Text(
                '$_windowMinutes min window',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _kPrimary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [1, 3, 5, 10].map((mins) {
              final isSel = _windowMinutes == mins;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () async {
                      await LocalStorageService.setDeduplicationWindowMinutes(mins);
                      setState(() => _windowMinutes = mins);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSel ? _kPrimary : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${mins}m',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRadioTile({
    required String title,
    required String subtitle,
    required String value,
    required String groupValue,
    required ValueChanged<String?> onChanged,
    required bool isDark,
  }) {
    final isSelected = value == groupValue;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? _kPrimary.withValues(alpha: 0.10) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? _kPrimary.withValues(alpha: 0.4) : (isDark ? Colors.white10 : Colors.black12),
          ),
        ),
        child: Row(
          children: [
            // ignore: deprecated_member_use
            Radio<String>(
              value: value,
              // ignore: deprecated_member_use
              groupValue: groupValue,
              // ignore: deprecated_member_use
              onChanged: onChanged,
              activeColor: _kPrimary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? _kPrimary : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log, bool isDark, Color cardBg, String currency) {
    final status = log['status'] as String? ?? 'captured';
    final body = log['body'] as String? ?? '';
    final sender = log['sender'] as String? ?? 'SMS';
    final amount = (log['amount'] as num? ?? 0.0).toDouble();
    final reason = log['reason'] as String? ?? '';
    final dateStr = log['date'] as String?;
    final date = dateStr != null ? DateTime.tryParse(dateStr) : null;

    Color badgeColor;
    String badgeText;
    IconData badgeIcon;

    switch (status) {
      case 'duplicate_suppressed':
        badgeColor = _kWarning;
        badgeText = 'Duplicate Suppressed';
        badgeIcon = Icons.copy_rounded;
        break;
      case 'flagged_duplicate':
        badgeColor = Colors.orange;
        badgeText = 'Flagged Duplicate';
        badgeIcon = Icons.warning_amber_rounded;
        break;
      case 'promo_blocked':
        badgeColor = Colors.grey;
        badgeText = 'Non-Financial';
        badgeIcon = Icons.block_rounded;
        break;
      case 'captured':
      default:
        badgeColor = _kIncome;
        badgeText = 'Captured';
        badgeIcon = Icons.check_circle_outline_rounded;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(badgeIcon, size: 13, color: badgeColor),
                        const SizedBox(width: 5),
                        Text(
                          badgeText,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: badgeColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    sender,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (date != null)
                Text(
                  Formatters.formatShortDateTime(date),
                  style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                reason,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
              if (amount > 0)
                Text(
                  Formatters.formatCurrency(amount, symbol: currency),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _kPrimary,
                  ),
                ),
            ],
          ),
          if (status == 'duplicate_suppressed' || status == 'promo_blocked') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(color: _kPrimary.withValues(alpha: 0.4)),
                ),
                onPressed: () => _forceCaptureSms(log),
                icon: const Icon(Icons.add_circle_outline, size: 16, color: _kPrimary),
                label: const Text(
                  'Force Add to Transactions',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _kPrimary),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;
  final bool isDark;

  const _StatBadge({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 6),
                Text(
                  '$count',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}
