import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await MobileAds.instance.initialize();
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Google Ads Robust Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.light),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const RobustAdsDemoScreen(),
    );
  }
}

enum AdStatus { loading, ready, failed, notSupported }

class RobustAdsDemoScreen extends StatefulWidget {
  const RobustAdsDemoScreen({super.key});

  @override
  State<RobustAdsDemoScreen> createState() => _RobustAdsDemoScreenState();
}

class _RobustAdsDemoScreenState extends State<RobustAdsDemoScreen> with WidgetsBindingObserver {
  // Test Ad Unit IDs
  final String _bannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
  final String _interstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712';
  final String _rewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917';
  final String _appOpenAdUnitId = 'ca-app-pub-3940256099942544/9257395921';

  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  AppOpenAd? _appOpenAd;

  AdStatus _bannerStatus = AdStatus.loading;
  AdStatus _interstitialStatus = AdStatus.loading;
  AdStatus _rewardedStatus = AdStatus.loading;
  AdStatus _appOpenStatus = AdStatus.loading;

  int _interstitialLoadAttempts = 0;
  int _rewardedLoadAttempts = 0;
  int _appOpenLoadAttempts = 0;
  final int _maxFailedLoadAttempts = 3;

  int _rewardScore = 0;
  bool _isShowingAppOpenAd = false;
  bool _isAdPlatformSupported = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _isAdPlatformSupported = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

    if (!_isAdPlatformSupported) {
      _bannerStatus = AdStatus.notSupported;
      _interstitialStatus = AdStatus.notSupported;
      _rewardedStatus = AdStatus.notSupported;
      _appOpenStatus = AdStatus.notSupported;
      return;
    }

    _loadAllAds();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    _appOpenAd?.dispose();
    super.dispose();
  }

  // App Lifecycle for App Open Ad
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _showAppOpenAd();
    }
  }

  void _loadAllAds() {
    if (!_isAdPlatformSupported) return;
    
    setState(() {
      _bannerStatus = AdStatus.loading;
      _interstitialStatus = AdStatus.loading;
      _rewardedStatus = AdStatus.loading;
      _appOpenStatus = AdStatus.loading;
    });

    _loadBannerAd();
    _loadInterstitialAd();
    _loadRewardedAd();
    _loadAppOpenAd();
  }

  // --- Banner Ad ---
  void _loadBannerAd() {
    _bannerAd?.dispose();
    _bannerAd = BannerAd(
      adUnitId: _bannerAdUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() => _bannerStatus = AdStatus.ready);
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint('BannerAd failed to load: $err');
          setState(() => _bannerStatus = AdStatus.failed);
          ad.dispose();
        },
      ),
    )..load();
  }

  // --- Interstitial Ad ---
  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialLoadAttempts = 0;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _loadInterstitialAd(); // Reload for next time
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _loadInterstitialAd(); 
            },
          );
          setState(() {
            _interstitialAd = ad;
            _interstitialStatus = AdStatus.ready;
          });
        },
        onAdFailedToLoad: (err) {
          debugPrint('InterstitialAd failed to load: $err');
          _interstitialLoadAttempts += 1;
          _interstitialAd = null;
          
          if (_interstitialLoadAttempts <= _maxFailedLoadAttempts) {
            // Exponential backoff retry
            Future.delayed(Duration(seconds: _interstitialLoadAttempts * 2), _loadInterstitialAd);
          } else {
            setState(() => _interstitialStatus = AdStatus.failed);
          }
        },
      ),
    );
  }

  void _showInterstitialAd() {
    if (_interstitialStatus == AdStatus.ready && _interstitialAd != null) {
      _interstitialAd!.show();
      setState(() => _interstitialStatus = AdStatus.loading);
      _interstitialAd = null;
    } else {
      _showToast('Interstitial Ad is not ready yet.');
    }
  }

  // --- Rewarded Ad ---
  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedLoadAttempts = 0;
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
            _rewardedStatus = AdStatus.ready;
          });
        },
        onAdFailedToLoad: (err) {
          debugPrint('RewardedAd failed to load: $err');
          _rewardedLoadAttempts += 1;
          _rewardedAd = null;
          
          if (_rewardedLoadAttempts <= _maxFailedLoadAttempts) {
            Future.delayed(Duration(seconds: _rewardedLoadAttempts * 2), _loadRewardedAd);
          } else {
            setState(() => _rewardedStatus = AdStatus.failed);
          }
        },
      ),
    );
  }

  void _showRewardedAd() {
    if (_rewardedStatus == AdStatus.ready && _rewardedAd != null) {
      _rewardedAd!.show(onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        setState(() {
          _rewardScore += reward.amount.toInt();
        });
        _showToast('Reward Earned! +${reward.amount.toInt()} coins');
      });
      setState(() => _rewardedStatus = AdStatus.loading);
      _rewardedAd = null;
    } else {
      _showToast('Rewarded Ad is not ready yet.');
    }
  }

  // --- App Open Ad ---
  void _loadAppOpenAd() {
    AppOpenAd.load(
      adUnitId: _appOpenAdUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenLoadAttempts = 0;
          setState(() {
            _appOpenAd = ad;
            _appOpenStatus = AdStatus.ready;
          });
        },
        onAdFailedToLoad: (err) {
          debugPrint('AppOpenAd failed to load: $err');
          _appOpenLoadAttempts += 1;
          _appOpenAd = null;
          
          if (_appOpenLoadAttempts <= _maxFailedLoadAttempts) {
            Future.delayed(Duration(seconds: _appOpenLoadAttempts * 2), _loadAppOpenAd);
          } else {
            setState(() => _appOpenStatus = AdStatus.failed);
          }
        },
      ),
    );
  }

  void _showAppOpenAd() {
    if (_isShowingAppOpenAd) return;
    if (_appOpenStatus == AdStatus.ready && _appOpenAd != null) {
      _isShowingAppOpenAd = true;
      _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          _isShowingAppOpenAd = false;
          ad.dispose();
          _loadAppOpenAd(); 
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          _isShowingAppOpenAd = false;
          ad.dispose();
          _loadAppOpenAd(); 
        },
      );
      _appOpenAd!.show();
      setState(() => _appOpenStatus = AdStatus.loading);
      _appOpenAd = null;
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Widget _buildStatusChip(String name, AdStatus status) {
    Color color;
    IconData icon;
    String label;

    switch (status) {
      case AdStatus.loading:
        color = Colors.blue;
        icon = Icons.hourglass_empty;
        label = 'Loading';
        break;
      case AdStatus.ready:
        color = Colors.green;
        icon = Icons.check_circle;
        label = 'Ready';
        break;
      case AdStatus.failed:
        color = Colors.red;
        icon = Icons.error;
        label = 'Failed';
        break;
      case AdStatus.notSupported:
        color = Colors.grey;
        icon = Icons.block;
        label = 'Not Supported';
        break;
    }

    return Chip(
      avatar: status == AdStatus.loading 
        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : Icon(icon, color: Colors.white, size: 18),
      label: Text('$name: $label'),
      backgroundColor: color,
      labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Robust Ads Demo', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllAds,
            tooltip: 'Reload All Ads',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Dashboard
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Ad Status Dashboard', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Divider(),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 4.0,
                      children: [
                        _buildStatusChip('Banner', _bannerStatus),
                        _buildStatusChip('Interstitial', _interstitialStatus),
                        _buildStatusChip('Rewarded', _rewardedStatus),
                        _buildStatusChip('App Open', _appOpenStatus),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Interstitial Actions
            Card(
              child: ListTile(
                leading: const Icon(Icons.fullscreen, size: 40, color: Colors.teal),
                title: const Text('Interstitial Ad', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Full screen ad between flows.'),
                trailing: ElevatedButton(
                  onPressed: _interstitialStatus == AdStatus.ready ? _showInterstitialAd : null,
                  child: const Text('SHOW'),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Rewarded Actions
            Card(
              child: ListTile(
                leading: const Icon(Icons.stars, size: 40, color: Colors.orange),
                title: Text('Rewarded Ad (Score: $_rewardScore)', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Watch a video to earn coins.'),
                trailing: ElevatedButton(
                  onPressed: _rewardedStatus == AdStatus.ready ? _showRewardedAd : null,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                  child: const Text('WATCH'),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // App Open Info
            Card(
              child: ListTile(
                leading: const Icon(Icons.phone_android, size: 40, color: Colors.purple),
                title: const Text('App Open Ad', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Minimize the app (Home button) and open it again to see this ad!'),
              ),
            ),
            
            const SizedBox(height: 100), // Space for bottom banner
          ],
        ),
      ),
      // Bottom Banner Ad
      bottomNavigationBar: SafeArea(
        child: Container(
          color: Theme.of(context).colorScheme.surfaceVariant,
          width: double.infinity,
          height: _bannerStatus == AdStatus.ready && _bannerAd != null ? _bannerAd!.size.height.toDouble() + 20 : 60,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Banner Ad', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              if (_bannerStatus == AdStatus.ready && _bannerAd != null)
                SizedBox(
                  width: _bannerAd!.size.width.toDouble(),
                  height: _bannerAd!.size.height.toDouble(),
                  child: AdWidget(ad: _bannerAd!),
                )
              else if (_bannerStatus == AdStatus.loading)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else if (_bannerStatus == AdStatus.notSupported)
                const Expanded(child: Center(child: Text('Not Supported on Windows/Web')))
              else
                const Expanded(child: Center(child: Text('Failed to load banner'))),
            ],
          ),
        ),
      ),
    );
  }
}
