package com.junorion.myapp;   // 앱 패키지로 바꾼다

import android.app.Activity;
import android.os.Handler;
import android.os.Looper;
import android.view.Gravity;
import android.view.View;
import android.webkit.JavascriptInterface;
import android.widget.FrameLayout;

import com.google.android.gms.ads.AdListener;
import com.google.android.gms.ads.AdRequest;
import com.google.android.gms.ads.AdSize;
import com.google.android.gms.ads.AdView;
import com.google.android.gms.ads.LoadAdError;
import com.google.android.gms.ads.MobileAds;

/**
 * 화면 아래 배너(320×50). 광고는 웹 페이지 안이 아니라 WebView 위에 겹친
 * 네이티브 AdView 에 그린다. 웹(index.html 의 syncAd)이 #adSlot 의 자리를 CSS 픽셀로
 * 알려 주면 그 자리로 옮긴다. CSS 픽셀은 viewport 가 device-width 라 dp 와 같다.
 *
 * 광고가 실패하거나 오프라인이면 뷰를 숨긴 채 두고 잠시 뒤 다시 청한다. 어떤 경우에도
 * 웹 쪽으로 예외를 던지지 않는다.
 */
final class Ads {

    /** 자리가 이보다 좁으면(가로 화면의 좁은 옆 칸) 배너가 이웃을 덮으므로 띄우지 않는다. */
    private static final int MIN_SLOT_DP = 300;
    private static final long RETRY_MS = 60_000;

    private final Activity activity;
    private final AdView banner;
    private final Handler ui = new Handler(Looper.getMainLooper());
    private final float density;

    private boolean wanted;   // 웹이 지금 보여도 된다고 했는가
    private boolean loaded;   // 받아 둔 광고가 있는가
    private boolean loading;

    Ads(Activity activity, FrameLayout root) {
        this.activity = activity;
        this.density = activity.getResources().getDisplayMetrics().density;

        banner = new AdView(activity);
        banner.setAdUnitId(BuildConfig.BANNER_AD_UNIT);
        banner.setAdSize(AdSize.BANNER);
        banner.setVisibility(View.GONE);
        banner.setAdListener(new AdListener() {
            @Override public void onAdLoaded() {
                loading = false;
                loaded = true;
                apply();
            }
            @Override public void onAdFailedToLoad(LoadAdError e) {
                // 오프라인·광고 없음 모두 여기로 온다. 조용히 숨기고 나중에 다시 청한다.
                loading = false;
                loaded = false;
                apply();
                ui.postDelayed(Ads.this::load, RETRY_MS);
            }
        });
        root.addView(banner, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT, FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.TOP | Gravity.START));

        // 초기화는 디스크를 읽으므로 메인 스레드를 막지 않게 따로 돌린다.
        new Thread(() -> MobileAds.initialize(activity, status -> ui.post(this::load))).start();
    }

    private void load() {
        if (loading || loaded || activity.isFinishing()) return;
        loading = true;
        banner.loadAd(new AdRequest.Builder().build());
    }

    private void apply() {
        banner.setVisibility(wanted && loaded ? View.VISIBLE : View.GONE);
    }

    /** 자리(CSS 픽셀, 페이지 왼쪽 위 기준)를 받아 배너를 그 가운데에 놓는다. */
    @JavascriptInterface
    public void place(double x, double y, double w, double h) {
        ui.post(() -> {
            if (w < MIN_SLOT_DP) { wanted = false; apply(); return; }
            float bw = AdSize.BANNER.getWidth() * density;
            float bh = AdSize.BANNER.getHeight() * density;
            banner.setTranslationX((float) ((x + w / 2) * density - bw / 2));
            banner.setTranslationY((float) ((y + h / 2) * density - bh / 2));
            wanted = true;
            apply();
        });
    }

    @JavascriptInterface
    public void hide() {
        ui.post(() -> { wanted = false; apply(); });
    }

    void pause()   { banner.pause(); }
    void resume()  { banner.resume(); }
    void destroy() { ui.removeCallbacksAndMessages(null); banner.destroy(); }
}
