// =============================================================================
// Note Counter Pro - Premium Upgrade Screen
// =============================================================================
// Shows multiple premium plans + buy button (Google Play IAP).
// Plans: Monthly (₹49), Yearly (₹299), Lifetime (₹499)
// =============================================================================

import 'package:flutter/material.dart';
import '../services/premium_service.dart';
import '../services/admob_service.dart';
import '../utils/constants.dart';
import '../utils/app_localizations.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  bool _isLoading = false;
  String? _selectedPlan;

  @override
  void initState() {
    super.initState();
    // Listen to PremiumService so that when trial is granted (via
    // rewarded ad from THIS screen or from Settings), this screen
    // rebuilds to show the correct 3-state UI.
    PremiumService().addListener(_onPremiumChanged);
  }

  @override
  void dispose() {
    PremiumService().removeListener(_onPremiumChanged);
    super.dispose();
  }

  void _onPremiumChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _purchase(String productId) async {
    setState(() {
      _isLoading = true;
      _selectedPlan = productId;
    });
    final started = await PremiumService().purchasePlan(productId);
    if (!started && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not start purchase. Please try again or check your Google Play connection.',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    }
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() => _isLoading = false);

    if (PremiumService().isPremium && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Premium activated! Enjoy ad-free experience.'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 3),
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _restore() async {
    setState(() => _isLoading = true);
    await PremiumService().restorePurchases();
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() => _isLoading = false);

    if (PremiumService().isPremium && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Premium restored!'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No previous purchases found.')),
      );
    }
  }

  /// Show a rewarded video ad. On completion, grant 1 day of premium
  /// trial via PremiumService.grantRewardedTrialDays(1).
  /// Uses the same loading-dialog + auto-retry flow as the Settings screen
  /// to avoid the "ad not ready, try again" UX problem.
  Future<void> _watchRewardedAd() async {
    final loc = context.loc;

    // If ad already loaded, show immediately.
    if (AdMobService.isRewardedAdReady) {
      _doShowRewardedAd(loc);
      return;
    }

    // Otherwise show a loading dialog and poll until ad is ready or
    // we time out (10 seconds).
    AdMobService.preloadRewardedAd();
    final ready = await _showRewardedAdLoadingDialog();
    if (!ready || !mounted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.t('adNotReadyMsg')),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      return;
    }
    _doShowRewardedAd(loc);
  }

  void _doShowRewardedAd(AppLocalizations loc) {
    AdMobService.showRewardedAd(
      onRewardEarned: () async {
        await PremiumService().grantRewardedTrialDays(1);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.t('rewardGrantedMsg')),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 4),
            ),
          );
          setState(() {}); // rebuild to show "Premium Active" state
        }
      },
    );
  }

  /// Show a loading dialog while waiting for the rewarded ad to preload.
  /// Returns true if the ad became ready within 10 seconds, false otherwise.
  Future<bool> _showRewardedAdLoadingDialog() async {
    final loc = context.loc;
    int attempts = 0;
    const maxAttempts = 10; // 10 attempts × 1 second = 10 second timeout

    // Show a non-dismissible loading dialog.
    if (!mounted) return false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Expanded(child: Text(loc.t('adLoadingMsg'))),
          ],
        ),
      ),
    );

    while (attempts < maxAttempts) {
      await Future.delayed(const Duration(seconds: 1));
      if (AdMobService.isRewardedAdReady) {
        if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
        return true;
      }
      attempts++;
    }

    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final theme = Theme.of(context);
    final isPremium = PremiumService().isPremium;

    return Scaffold(
      appBar: AppBar(title: Text(loc.t('premium'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),

            // Hero icon
            Container(
              width: 90,
              height: 90,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFD4AF37), Color(0xFFE6C757)],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD4AF37).withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.workspace_premium,
                  size: 48, color: Colors.white),
            ),

            Text(
              loc.t('premiumTitle'),
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              loc.t('premiumSubtitle'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: (Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[600]),
              ),
            ),

            const SizedBox(height: 24),

            // Benefits — 10 items
            _BenefitTile(icon: Icons.block, color: AppColors.danger,
                title: loc.t('premiumBenefit1Title'), subtitle: loc.t('premiumBenefit1Sub')),
            _BenefitTile(icon: Icons.fingerprint, color: AppColors.success,
                title: loc.t('appLock'), subtitle: loc.t('appLockDesc')),
            _BenefitTile(icon: Icons.record_voice_over, color: AppColors.info,
                title: loc.t('voiceAnnouncement'), subtitle: loc.t('voiceAnnouncementDesc')),
            _BenefitTile(icon: Icons.support_agent, color: AppColors.primary,
                title: loc.t('prioritySupport'), subtitle: loc.t('prioritySupportDesc')),
            _BenefitTile(icon: Icons.update, color: AppColors.primary,
                title: loc.t('premiumBenefit3Title'), subtitle: loc.t('premiumBenefit3Sub')),
            _BenefitTile(icon: Icons.store, color: AppColors.success,
                title: loc.t('businessDetails'), subtitle: loc.t('businessDetailsSubtitle')),
            _BenefitTile(icon: Icons.qr_code_2, color: AppColors.info,
                title: loc.t('upiQrCode'), subtitle: loc.t('generatePaymentQr')),
            _BenefitTile(icon: Icons.receipt_long, color: AppColors.warning,
                title: loc.t('billsInvoices'), subtitle: loc.t('billsInvoicesDesc')),
            _BenefitTile(icon: Icons.bar_chart, color: AppColors.info,
                title: loc.t('reportsAnalytics'), subtitle: loc.t('reportsDesc')),
            _BenefitTile(icon: Icons.image_search, color: AppColors.success,
                title: loc.t('qrScannerTitle'), subtitle: loc.t('qrScannerDesc')),

            const SizedBox(height: 24),

            // === 3 states ===
            // 1. PAID premium (IAP) → show "Premium Active" only
            // 2. TRIAL active (rewarded ad) → show trial status + extend + paid plans
            // 3. FREE user → show rewarded ad + paid plans

            if (isPremium && !PremiumService().isTrialActive) ...[
              // === PAID PREMIUM ===
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.success, width: 2),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.success, size: 48),
                    const SizedBox(height: 8),
                    Text(loc.t('premiumActive'),
                        style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold, color: AppColors.success)),
                    const SizedBox(height: 4),
                    Text(loc.t('premiumActiveSub'),
                        textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ] else ...[
              // === TRIAL ACTIVE or FREE USER ===

              // If trial active, show trial status banner at the top
              if (PremiumService().isTrialActive) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.success, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer, color: AppColors.success, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${loc.t('trialActive')}: ${PremiumService().trialRemainingLabel}',
                              style: const TextStyle(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              loc.t('trialActiveDesc'),
                              style: TextStyle(
                                  fontSize: 11,
                                  color: (Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[600])),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // === FREE: Watch Ad → 1 Day Premium ===
              _RewardedAdCard(onWatch: _watchRewardedAd),
              const SizedBox(height: 16),

              // === "Want permanent premium?" separator ===
              if (PremiumService().isTrialActive) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(child: Divider(color: (Theme.of(context).brightness == Brightness.dark ? Colors.grey[700] : Colors.grey[300]))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          loc.t('wantPermanentPremium'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: (Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[600]),
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: (Theme.of(context).brightness == Brightness.dark ? Colors.grey[700] : Colors.grey[300]))),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // === Paid Plan Cards ===
              ...PremiumService.plans.map((plan) => _PlanCard(
                    plan: plan,
                    isLoading: _isLoading && _selectedPlan == plan['id'],
                    onTap: () => _purchase(plan['id'] as String),
                  )),

              const SizedBox(height: 12),

              // Restore
              Center(
                child: TextButton.icon(
                  onPressed: _isLoading ? null : _restore,
                  icon: const Icon(Icons.restore, size: 18),
                  label: Text(loc.t('premiumRestore')),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Note
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: (Theme.of(context).brightness == Brightness.dark ? Colors.grey[850] : Colors.grey[100]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 18, color: (Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[600])),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(loc.t('premiumNote'),
                        style: theme.textTheme.bodySmall?.copyWith(color: (Theme.of(context).brightness == Brightness.dark ? Colors.grey[300] : Colors.grey[700]))),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final bool isLoading;
  final VoidCallback onTap;

  const _PlanCard({required this.plan, required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isBestValue = plan['badge'] != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isBestValue ? const Color(0xFFD4AF37) : (Theme.of(context).brightness == Brightness.dark ? Colors.grey[700]! : Colors.grey[300]!),
          width: isBestValue ? 2 : 1,
        ),
        color: isBestValue ? const Color(0xFFD4AF37).withOpacity(0.05) : null,
      ),
      child: Stack(
        children: [
          if (isBestValue)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFFD4AF37), Color(0xFFB8941F)]),
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(14),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
                child: Text(
                  plan['badge'] as String,
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          InkWell(
            onTap: isLoading ? null : onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(plan['name'] as String,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(plan['description'] as String,
                            style: TextStyle(fontSize: 12, color: (Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[600]))),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(plan['price'] as String,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: isBestValue ? const Color(0xFFD4AF37) : AppColors.primary,
                              )),
                          const SizedBox(width: 2),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(plan['period'] as String,
                                style: TextStyle(fontSize: 12, color: (Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[600]))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 36,
                        child: FilledButton(
                          onPressed: isLoading ? null : onTap,
                          style: FilledButton.styleFrom(
                            backgroundColor: isBestValue
                                ? const Color(0xFFD4AF37)
                                : AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          ),
                          child: isLoading
                              ? const SizedBox(width: 16, height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Buy', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _BenefitTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: (Theme.of(context).brightness == Brightness.dark ? Colors.grey[800]! : Colors.grey[200]!)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: (Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[600]))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Highlighted "Watch Ad → 1 Day Free Premium" card shown on the Premium
/// screen BEFORE the paid plan cards. Designed to grab the user's eye so
/// they see there's a free path to premium before being asked to pay.
class _RewardedAdCard extends StatefulWidget {
  final VoidCallback onWatch;
  const _RewardedAdCard({required this.onWatch});

  @override
  State<_RewardedAdCard> createState() => _RewardedAdCardState();
}

class _RewardedAdCardState extends State<_RewardedAdCard> {
  @override
  void initState() {
    super.initState();
    // Preload the rewarded ad as soon as the user opens the Premium
    // screen, so by the time they tap "Watch Ad Now" the ad is likely
    // already ready.
    AdMobService.preloadRewardedAd();
    // Listen for ad-readiness changes so we can toggle the button state.
    AdMobService.addRewardedReadinessListener(_onReadinessChanged);
  }

  @override
  void dispose() {
    AdMobService.removeRewardedReadinessListener(_onReadinessChanged);
    super.dispose();
  }

  void _onReadinessChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final theme = Theme.of(context);
    final ready = AdMobService.isRewardedAdReady;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        // Gold gradient background — eye-catching but not garish.
        gradient: const LinearGradient(
          colors: [Color(0xFFD4AF37), Color(0xFFFFD700), Color(0xFFD4AF37)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD700), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4AF37).withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // "FREE" badge in the top-right corner
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.success,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Text(
                'FREE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.play_circle_filled,
                        color: Colors.white, size: 32),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        loc.t('watchAdFreePremium'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  loc.t('watchAdFreePremiumDesc'),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.95),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: widget.onWatch,
                    icon: ready
                        ? const Icon(Icons.play_arrow, size: 20)
                        : const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                    label: Text(
                      ready
                          ? loc.t('watchAdNow')
                          : loc.t('loadingAd'),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF8B0000),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
