# 출시 빌드 코드 축소(R8)용 규칙.
#
# 광고 SDK(google_mobile_ads · play-services-ads)가 들여온 WorkManager 는 앱 시작 때 Room 데이터베이스
# (androidx.work.impl.WorkDatabase_Impl)를 이름으로 찾아 만든다. R8 이 쓰이지 않는 클래스로 보고 지우면
# "Failed to create an instance of androidx.work.impl.WorkDatabase" 로 앱이 켜지자마자 죽는다(톡톡런, 2026-11-15 A32).
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
