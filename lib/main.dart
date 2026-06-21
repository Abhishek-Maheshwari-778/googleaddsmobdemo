import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) {
    await MobileAds.instance.initialize();
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Google Ads Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const SimpleAdsDemoScreen(),
    );
  }
}

class SimpleAdsDemoScreen extends StatefulWidget {
  const SimpleAdsDemoScreen({super.key});

  @override
  State<SimpleAdsDemoScreen> createState() => _SimpleAdsDemoScreenState();
}

class _SimpleAdsDemoScreenState extends State<SimpleAdsDemoScreen> {
  // TEST AD UNIT IDs (Use test IDs so ads actually show up, real IDs won't show without store approval)
  final String _bannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
  final String _rewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917';

  BannerAd? _bannerAd;
  RewardedAd? _rewardedAd;

  bool _isBannerAdLoaded = false;
  bool _isRewardedAdLoaded = false;

  int _rewardScore = 0;

  @override
  void initState() {
    super.initState();
    _loadAllAds();
  }

  void _loadAllAds() {
    if (kIsWeb || (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS)) {
      print('Ads are only supported on Android and iOS.');
      return;
    }
    _loadBannerAd();
    _loadRewardedAd();
  }

  // 1. Banner Ad
  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: _bannerAdUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _isBannerAdLoaded = true),
        onAdFailedToLoad: (ad, err) {
          debugPrint('BannerAd failed to load: $err');
          ad.dispose();
        },
      ),
    )..load();
  }

  // 2. Rewarded Video Ad
  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _loadRewardedAd(); 
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _loadRewardedAd(); 
            },
          );
          setState(() {
            _rewardedAd = ad;
            _isRewardedAdLoaded = true;
          });
        },
        onAdFailedToLoad: (err) {
          debugPrint('RewardedAd failed to load: $err');
          _isRewardedAdLoaded = false;
        },
      ),
    );
  }

  void _showRewardedAd() {
    if (_isRewardedAdLoaded && _rewardedAd != null) {
      _rewardedAd!.show(onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        setState(() {
          _rewardScore += reward.amount.toInt();
        });
        _showToast('You got a reward! Total Score: $_rewardScore');
      });
      _isRewardedAdLoaded = false;
      _rewardedAd = null;
    } else {
      _showToast('Rewarded Ad is loading... please wait.');
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _rewardedAd?.dispose();
    super.dispose();
  }

  Widget _buildSectionTitle(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
        const SizedBox(height: 5),
        Text(description, style: const TextStyle(fontSize: 14, color: Colors.black54)),
        const Divider(thickness: 1),
        const SizedBox(height: 10),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Simple Google Ads Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload Ads',
            onPressed: () {
              _loadAllAds();
              _showToast('Reloading ads...');
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
               padding: const EdgeInsets.all(12),
               decoration: BoxDecoration(color: Colors.yellow[100], borderRadius: BorderRadius.circular(8)),
               child: const Text(
                 'NOTE: This app uses Google Test Ad IDs. Only Banner and Rewarded ads are active.',
                 style: TextStyle(color: Colors.brown, fontWeight: FontWeight.w600),
               ),
            ),
            
            // Rewarded Ad Section
            _buildSectionTitle('Rewarded Video Ad', 'Full screen video ad. Gives user a reward after watching.'),
            Text(
              'Your Reward Coins: $_rewardScore 🪙',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _showRewardedAd,
              icon: const Icon(Icons.video_library),
              label: const Text('Watch Video & Earn Reward'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
            ),

            const SizedBox(height: 50),
          ],
        ),
      ),
      // Banner Ad Section (Bottom Navigation Bar)
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            color: Colors.grey[200],
            width: double.infinity,
            padding: const EdgeInsets.all(4.0),
            child: const Text('Banner Ad (Always at bottom)', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          if (_isBannerAdLoaded && _bannerAd != null)
            SafeArea(
              child: SizedBox(
                width: _bannerAd!.size.width.toDouble(),
                height: _bannerAd!.size.height.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),
            )
          else
            const SizedBox(height: 50, child: Center(child: Text('Loading Banner Ad...'))),
        ],
      ),
    );
  }
}
