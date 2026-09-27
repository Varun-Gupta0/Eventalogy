import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../state/ai_planner_state.dart';
import '../services/ai_planner_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/custom_text_field.dart';

class AIPlannerFlowScreen extends StatefulWidget {
  const AIPlannerFlowScreen({super.key});

  @override
  State<AIPlannerFlowScreen> createState() => _AIPlannerFlowScreenState();
}

class _AIPlannerFlowScreenState extends State<AIPlannerFlowScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  
  final _visionController = TextEditingController();
  final _locationController = TextEditingController();
  final _guestController = TextEditingController();
  final _budgetController = TextEditingController();
  
  bool _isGenerating = false;

  void _nextStep() {
    if (_currentStep < 4) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  void _generatePlan() async {
    setState(() => _isGenerating = true);
    final request = AIPlannerState().currentRequest;
    request.vision = _visionController.text;
    request.location = _locationController.text;
    request.guestCount = int.tryParse(_guestController.text) ?? 50;
    request.budget = double.tryParse(_budgetController.text) ?? 5000.0;
    
    // Using Live Service for Phase 7
    final plan = await OpenRouterAIPlannerServiceImpl().generatePlan(request);
    
    setState(() => _isGenerating = false);
    if (mounted) {
      context.push('/ai-generated', extra: plan);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Column(
          children: [
            const Text(
              'EVENTOLOGY ARCHITECT',
              style: TextStyle(
                fontSize: 10,
                color: AppColors.primary,
                letterSpacing: 2.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Planning Session',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: AppColors.background.withOpacity(0.8),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(10),
          child: LinearProgressIndicator(
            value: (_currentStep + 1) / 5,
            backgroundColor: Colors.white.withOpacity(0.1),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            minHeight: 2,
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned(
            top: 200,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.05),
              ),
            ),
          ),
          PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (idx) => setState(() => _currentStep = idx),
            children: [
              // Step 1
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Let\'s build your dream.',
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, height: 1.1),
                    ),
                    const SizedBox(height: 8),
                    const Text('What kind of event are we planning?', style: TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 40),
                    _buildOptionCard('Wedding', Icons.favorite, () {
                      AIPlannerState().currentRequest.eventType = 'Wedding';
                      _nextStep();
                    }),
                    const SizedBox(height: 16),
                    _buildOptionCard('Birthday', Icons.cake, () {
                      AIPlannerState().currentRequest.eventType = 'Birthday';
                      _nextStep();
                    }),
                    const SizedBox(height: 16),
                    _buildOptionCard('Corporate', Icons.business, () {
                      AIPlannerState().currentRequest.eventType = 'Corporate';
                      _nextStep();
                    }),
                  ],
                ),
              ),
              // Step 2
              _buildFormStep(
                title: 'Describe your vision',
                subtitle: 'E.g. A royal sunset wedding with pastel decor...',
                children: [
                  CustomTextField(controller: _visionController, label: 'Vision', hint: 'Type your thoughts...'),
                  const SizedBox(height: 40),
                  _buildGlowButton('Next', _nextStep),
                ],
              ),
              // Step 3
              _buildFormStep(
                title: 'Where and who?',
                subtitle: 'Location and guest count',
                children: [
                  CustomTextField(controller: _locationController, label: 'Location', hint: 'City or Venue'),
                  const SizedBox(height: 16),
                  CustomTextField(controller: _guestController, label: 'Guests', hint: 'E.g., 300'),
                  const SizedBox(height: 40),
                  _buildGlowButton('Next', _nextStep),
                ],
              ),
              // Step 4
              _buildFormStep(
                title: 'Budget Allocation',
                subtitle: 'How much are you looking to spend?',
                children: [
                  CustomTextField(controller: _budgetController, label: 'Budget (₹)', hint: 'E.g., 1000000'),
                  const SizedBox(height: 40),
                  _buildGlowButton('Next', _nextStep),
                ],
              ),
              // Step 5
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.auto_awesome, size: 64, color: AppColors.primary),
                      const SizedBox(height: 24),
                      const Text('Ready to generate?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text('Our AI will now architect your entire event.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 40),
                      _isGenerating
                          ? const CircularProgressIndicator(color: AppColors.primary)
                          : _buildGlowButton('Generate Architecture', _generatePlan),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormStep({required String title, required String subtitle, required List<Widget> children}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, height: 1.1)),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 40),
          ...children,
        ],
      ),
    );
  }

  Widget _buildOptionCard(String title, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 16),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            const Spacer(),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildGlowButton(String text, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(color: AppColors.background, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
