// 배너 광고 (Flutter, google_mobile_ads) — 톡톡런 lib/features/ads/ads.dart·ad_slot.dart 를 상태 관리 없이 옮긴 견본.
// pubspec: google_mobile_ads. AndroidManifest <application> 안에 AdMob 앱 ID:
//   <meta-data android:name="com.google.android.gms.ads.APPLICATION_ID" android:value="ca-app-pub-…~…"/>
// 화면 틀(Scaffold 의 bottomNavigationBar 등)에 `const AdSlot()` 을 둔다. 러닝·게임 진행처럼 집중하는 화면에는 두지 않는다.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// 빌드 옵션 `--dart-define=AD_SLOT=…` 로 정한다.
/// - `test`(기본): Google 시험 광고. 시험폰·개발 빌드는 이것 — 내 실제 광고를 누르면 무효 클릭으로
///   AdMob 계정이 막힐 수 있다.
/// - `live`: 실제 광고. **Play 에 올릴 AAB 만** 이것으로 빌드한다.
/// - `placeholder`: 회색 자리만(레이아웃 확인), `off`: 자리 없음(스토어 스크린샷·테스트).
enum AdSlotMode { off, placeholder, test, live }

final AdSlotMode adSlotMode = switch (const String.fromEnvironment('AD_SLOT', defaultValue: 'test')) {
  'off' => AdSlotMode.off,
  'placeholder' => AdSlotMode.placeholder,
  'live' => AdSlotMode.live,
  _ => AdSlotMode.test,
};

/// 광고 단위 — 실제(AdMob 에서 만든 것) / Google 이 공개한 시험용(앵커 적응형 배너)
abstract final class AdUnits {
  static const bannerLive = 'ca-app-pub-0000000000000000/0000000000'; // AdMob › 앱 › 광고 단위에서 복사
  static const bannerTest = 'ca-app-pub-3940256099942544/9214589741';
}

/// 동의(UMP) 확인 → 필요한 사용자(유럽 등)에게 동의 창 → SDK 시작. 한 번만 돈다.
/// 실패해도 앱은 그대로(광고만 안 나온다).
final Future<bool> adsReady = _start();

Future<bool> _start() async {
  if (adSlotMode != AdSlotMode.test && adSlotMode != AdSlotMode.live) return false;
  if (defaultTargetPlatform != TargetPlatform.android) return false;
  try {
    await _gatherConsent();
    if (!await ConsentInformation.instance.canRequestAds()) return false;
    await MobileAds.instance.initialize();
    return true;
  } catch (_) {
    return false;
  }
}

Future<void> _gatherConsent() {
  final done = Completer<void>();
  ConsentInformation.instance.requestConsentInfoUpdate(
    ConsentRequestParameters(),
    () async {
      // 동의가 필요한 사용자에게만 창이 뜬다. 이미 답했으면 뜨지 않는다
      await ConsentForm.loadAndShowConsentFormIfRequired((_) {
        if (!done.isCompleted) done.complete();
      });
    },
    // 네트워크 없음 등 — 지난번 답으로 판단한다
    (_) {
      if (!done.isCompleted) done.complete();
    },
  );
  return done.future;
}

/// 설정 화면에 "광고 개인정보 설정" 줄을 보일지 — 동의를 받아야 하는 사용자에게만 (UMP 규칙)
Future<bool> adsPrivacyRequired() async {
  if (adSlotMode != AdSlotMode.test && adSlotMode != AdSlotMode.live) return false;
  try {
    return await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
        PrivacyOptionsRequirementStatus.required;
  } catch (_) {
    return false;
  }
}

/// 동의를 다시 고르는 창 (설정의 "광고 개인정보 설정")
Future<void> showAdsPrivacyOptions() {
  final done = Completer<void>();
  ConsentForm.showPrivacyOptionsForm((_) {
    if (!done.isCompleted) done.complete();
  });
  return done.future;
}

/// 화면 아래 배너. 광고를 못 받으면 자리를 접는다(빈 칸을 남기지 않는다).
class AdSlot extends StatelessWidget {
  const AdSlot({super.key});

  @override
  Widget build(BuildContext context) => switch (adSlotMode) {
    AdSlotMode.off => const SizedBox.shrink(),
    AdSlotMode.placeholder => const _Placeholder(),
    AdSlotMode.test => const _Banner(unit: AdUnits.bannerTest),
    AdSlotMode.live => const _Banner(unit: AdUnits.bannerLive),
  };
}

/// 레이아웃 확인용 회색 자리 (표준 배너 320×50 + 여백)
class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      height: 60,
      color: c.surface,
      alignment: Alignment.center,
      child: Container(
        width: 320,
        height: 50,
        decoration: BoxDecoration(color: c.surfaceContainerHighest, borderRadius: BorderRadius.circular(6)),
        alignment: Alignment.center,
        child: Text('Ad', style: TextStyle(color: c.onSurfaceVariant)),
      ),
    );
  }
}

/// 앵커 적응형 배너 — 화면 폭에 맞춘 높이를 Google 이 정한다
class _Banner extends StatefulWidget {
  const _Banner({required this.unit});
  final String unit;

  @override
  State<_Banner> createState() => _BannerState();
}

class _BannerState extends State<_Banner> {
  BannerAd? _ad;
  bool _loaded = false;
  bool _started = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    adsReady.then((ok) {
      if (mounted && ok) setState(() => _ready = true);
    });
  }

  Future<void> _load(int width) async {
    _started = true;
    final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
    if (size == null || !mounted) return;
    final ad = BannerAd(
      adUnitId: widget.unit,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (mounted) setState(() => _ad = null);
        },
      ),
    );
    setState(() => _ad = ad);
    await ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, c) {
        if (!_started) {
          final w = c.maxWidth.truncate();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_started) _load(w);
          });
        }
        final ad = _ad;
        if (ad == null || !_loaded) return const SizedBox.shrink();
        return Container(
          color: Theme.of(context).colorScheme.surface,
          alignment: Alignment.center,
          height: ad.size.height.toDouble(),
          child: SizedBox(
            width: ad.size.width.toDouble(),
            height: ad.size.height.toDouble(),
            child: AdWidget(ad: ad),
          ),
        );
      },
    );
  }
}
