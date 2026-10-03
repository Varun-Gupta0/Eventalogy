import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../ai/models/agent_models.dart';
import '../../ai/services/agent_chat_service.dart';

class PlanReviewScreen extends StatefulWidget {
  final String conversationId;
  final AgentWorkflowState state;

  const PlanReviewScreen({
    super.key,
    required this.conversationId,
    required this.state,
  });

  @override
  State<PlanReviewScreen> createState() => _PlanReviewScreenState();
}

class _PlanReviewScreenState extends State<PlanReviewScreen> {
  bool _isApproving = false;
  String? _error;

  Future<void> _handleApprove() async {
    setState(() {
      _isApproving = true;
      _error = null;
    });

    final service = AgentChatService();
    final res = await service.submitApproval(widget.conversationId, true, note: 'Approved via Plan Review Screen');

    setState(() {
      _isApproving = false;
    });

    if (res.success) {
      if (mounted) {
        context.go('/my-events');
      }
    } else {
      setState(() {
        _error = res.error ?? 'Failed to approve plan.';
      });
    }
  }

  void _handleChangeSomething() {
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.state.eventPlan;
    final budget = widget.state.budgetBreakdown;
    final approval = widget.state.pendingApprovals.isNotEmpty ? widget.state.pendingApprovals.first : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background.withValues(alpha: 0.9),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'REVIEW YOUR EVENT',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 12,
            letterSpacing: 2.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: plan == null
            ? const Center(child: Text('No plan details available', style: TextStyle(color: Colors.white)))
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_error != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 24),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: Colors.red),
                                const SizedBox(width: 12),
                                Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red))),
                              ],
                            ),
                          ),
                        
                        Text(
                          plan['title'] ?? 'Event Plan',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          plan['summary'] ?? '',
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 32),

                        const Text('RECOMMENDED SERVICES', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                        const SizedBox(height: 16),
                        if (plan['requiredServices'] != null)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: (plan['requiredServices'] as List<dynamic>).map((s) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceLighter,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.glassBorder),
                              ),
                              child: Text(s.toString(), style: const TextStyle(color: Colors.white, fontSize: 14)),
                            )).toList(),
                          ),
                        
                        const SizedBox(height: 32),

                        if (approval != null) ...[
                          const Text('SELECTED VENUE', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.glassBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(approval.venue ?? 'No Venue Selected', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                if (approval.venue != null)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 8.0),
                                    child: Text('Perfectly matches your vision and requirements.', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),

                          if (approval.recommendedVendors != null && approval.recommendedVendors!.isNotEmpty) ...[
                            const Text('SELECTED VENDORS', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                            const SizedBox(height: 16),
                            ...approval.recommendedVendors!.map((vendor) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.glassBorder),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(vendor['name'] ?? 'Vendor', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        Text(vendor['serviceCategory'] ?? 'Service', style: const TextStyle(color: AppColors.primary, fontSize: 12)),
                                      ],
                                    ),
                                    Text('₹${vendor['estimatedCost'] ?? 0}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 32),
                          ],
                        ],

                        if (budget != null) ...[
                          const Text('ESTIMATED BUDGET', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.glassBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (budget['lineItems'] != null)
                                  ...(budget['lineItems'] as List<dynamic>).map((item) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 16),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(item['category'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                                const SizedBox(height: 4),
                                                Text(item['description'] ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                              ],
                                            ),
                                          ),
                                          Text('₹${item['estimatedCost'] ?? 0}', style: const TextStyle(color: Colors.white, fontSize: 16)),
                                        ],
                                      ),
                                    );
                                  }),
                                const Divider(color: AppColors.glassBorder, height: 32),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Total Estimate', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                    Text('₹${budget['totalEstimatedCost'] ?? 0}', style: const TextStyle(color: AppColors.primary, fontSize: 24, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 48),
                        ],

                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isApproving ? null : _handleChangeSomething,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 20),
                                  side: const BorderSide(color: AppColors.glassBorder),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                child: const Text('Change Something', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed: _isApproving ? null : _handleApprove,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 20),
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                child: _isApproving
                                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                                    : const Text('Approve & Book', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 48),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
