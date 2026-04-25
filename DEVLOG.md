# 8PartyPlay — Dev Log

لاگ کامل توسعه‌ی اپ از ابتدا تا الان + خلاصه‌ی ساختار و audit نهایی.

## 1. وضعیت فعلی (Snapshot)

- **نام اپ:** 8PartyPlay (قبلاً 888Play / 888PartyPlay)
- **پلتفرم:** iOS 18+ (Swift / SwiftUI، MVVM)
- **بک‌اند:** Supabase (Auth + Postgres + Realtime) — اسکیما کامل در `supabase_final_production.sql`
- **پرداخت:** RevenueCat (اشتراک ماهانه/سالانه + بسته‌های ستاره)
- **وب‌سایت:** Next.js داخل `website/` (لندینگ + صفحات قانونی + پنل ادمین)
- **اسناد بازسازی:** پوشه `rebuild-prompt/` (شماره‌گذاری شده ۰۱ تا ۲۰)

### بازی‌های فعال (۱۱ بازی)
1. **Reverse Singing** — خوانندگی معکوس با ضبط صدا
2. **Guess the Seconds** — حدس ثانیه
3. **Imposter** — بازی جاسوس (Single / MultiDevice / Team)
4. **Ten Tangle** — اعداد گره‌خورده
5. **Memory Grid** — حافظه شبکه‌ای
6. **Memory Path** — مسیر حافظه
7. **Pass & Guess** — حدس دست‌به‌دست
8. **Spin the Bottle** — جرئت یا حقیقت
9. **Tap In Order** — ضربه به ترتیب
10. **Color Trap** — تله رنگ
11. **Draw & Rush** — نقاشی سریع (Single + MultiDevice)

### ابزارها (Tools tab)
- Coin Flip (شیر یا خط)
- Dice Roll (تاس)
- Hourglass / Timer (ساعت شنی)
- Team Picker (تیم‌بندی)
- Cards (کارت‌های آماده + AI Card Generator)
- Spin Bottle Tool

### اقتصاد و سیستم اشتراک
- ستاره (Stars) — ارز داخلی
- اشتراک ماهانه و سالانه (RevenueCat)
- پنل ادمین در وب برای Remote Config

## 2. ساختار پروژه

```
ios/App8PartyPlay/
├─ App8PartyPlayApp.swift, ContentView.swift, Config.swift
├─ Models/      (10 file — AppModels, Card, CasualRoom, DrawRush, Economy, MemoryPath, PartyGameTutorial, QuickGame, SpinBottle, Supabase)
├─ ViewModels/  (12 file — AppViewModel + 4 extension + 7 ViewModel مخصوص هر بازی)
├─ Services/    (12 file — Supabase ×4، CasualRoom، Sound، Notification، Feedback، Telemetry، SessionResilience، MemoryPathGenerator، DeviceTokenStore، SharedResultBuilder)
├─ Views/       (~45 file — هر بازی: SetupView + SessionView، به‌علاوه Home/Tools/Friends/Factory/Profile/Paywall/...)
└─ Utilities/   (Localization، Typography، Animation، Constants، DeviceIdentity، AIContentModeration، KeyboardDismiss)
website/        (Next.js)
rebuild-prompt/ (مستندات بازسازی)
supabase_final_production.sql
```

## 3. Audit نهایی — کدهای پاک‌شده

این پاکسازی روی build فعلی انجام شد:

**حذف کامل:**
- `Models/GameEngineProtocol.swift` — protocol و registry که هیچ‌جا implement نشده بود (فقط `SharedResultBuilder` ازش استفاده می‌شد، که به یک فایل کوچک‌تر در `Services/SharedResultBuilder.swift` منتقل شد).

**کاهش اندازه:**
- `Utilities/AnimationModifiers.swift` — از ۱۹۳ خط به ۳۲ خط. فقط `slideUpOnAppear` و `CardPressStyle` استفاده می‌شد. حذف شده‌ها: `BounceOnAppearModifier`, `PulseModifier`, `ShakeModifier`, `CountdownScaleModifier`, `ConfettiModifier`, `ConfettiParticle` به‌همراه extension‌های مربوطه.

**فایل‌های جدید:**
- `Services/SharedResultBuilder.swift` — جایگزین کوچک‌شده‌ی محتوای استفاده‌شده از `GameEngineProtocol.swift`.
- `DEVLOG.md` (همین فایل).

> پاکسازی‌های قبلی (commit `678e7c6`): حذف `App888Play/` legacy، فونت‌های Vazirmatn (بعد از حذف فارسی)، ۱۳ فایل SQL تاریخچه‌ای، `friendsHeader` و `placeholderBody/sessionHeader` مرده.

Build بعد از پاکسازی: ✅ سبز.

## 3.1 پاکسازی XP/Level (audit جدید)

کل سیستم XP و Level Progress از پروژه حذف شد (به‌درخواست کاربر).

**حذف کامل از این فایل‌ها:**
- `Models/AppModels.swift` — `XPProgress` struct + فیلد `xpWon` از `GameResultRow`.
- `Models/EconomyModels.swift` — `XPLevelCurve` enum و فیلدهای `xpForParticipation`/`xpForWin` از `RewardPolicy`.
- `Models/SupabaseModels.swift` — `XPProgressRecord` struct، فیلد `xpAwarded` از `GameResultRecord`/`GameResultUpsertRecord`، فیلد `xpWon` از `SessionStateResultRecord`.
- `Services/SharedResultBuilder.swift` — منطق xp.
- `Services/SupabaseDatabaseService.swift` — متد `fetchXPProgress`.
- `ViewModels/AppViewModel.swift` — property `xpProgress`، توابع `xpForGame`/`totalXP`/`globalLevel`/`updateXPAfterMatch`، تمام مقداردهی‌ها در `init`/`refreshDashboardData`/`applyGuestState`.
- `Views/MainTabView.swift` — کارت آمار XP در `gameContextCard` (matches played / wins).

> توجه: جدول `xp_progress` و ستون‌های `xp_awarded` در دیتابیس Supabase دست‌نخورده باقی مانده‌اند ولی توسط app نوشته/خوانده نمی‌شوند. در migration بعدی می‌توانند drop شوند.

Build بعد از پاکسازی XP: ✅ سبز.

## 3.2 پاکسازی FakeAnswer (audit جدید)

بازی «Guess the Fake Answer» در commit‌های قدیمی اضافه و سپس حذف شده بود، ولی ~۱۰۹ ارجاع به ساختارهای `FakeAnswer*` در کد باقی مانده بود (مدل‌ها، رکوردهای Supabase، state‌های `AppViewModel` و `CasualRoom` settings). همه‌ی این کدها مرده بودند و توسط هیچ بازی فعلی استفاده نمی‌شدند.

**حذف کامل از این فایل‌ها:**
- `Models/AppModels.swift` — `FakeAnswerQuestionPack`, `FakeAnswerSettings`, `FakeAnswerRoundPhase`, `FakeAnswerQuestion`, `FakeAnswerSubmission`, `FakeAnswerOption`, `FakeAnswerVote`, `FakeAnswerScoreEvent`, `FakeAnswerRevealItem`, `FakeAnswerRoundState` + فیلد `fakeAnswerState` از `GameSession`.
- `Models/SupabaseModels.swift` — تمام `SessionStateFakeAnswer*Record` ها + فیلد `fakeAnswerState` از `SessionStateRecord` و کلید `fake_answer_state` از CodingKeys.
- `Models/CasualRoomModels.swift` — فیلد `settings: FakeAnswerSettings` از `CasualRoom`، فیلدهای `settingsRounds/settingsAnswerTime/settingsVoteTime/settingsQuestionPack` از `CasualRoomStatePayload`.
- `Services/CasualRoomService.swift` — پارامتر `settings` از `createRoom`/`fetchRoom`، حذف کامل `updateRoomSettings`. RPC `casual_create_room` همچنان مقادیر دیفالت (`0`/`"random"`) دریافت می‌کند تا با schema موجود سازگار باشد.
- `ViewModels/AppViewModel.swift` — property `currentFakeAnswerSettings`، تابع `updateFakeAnswerSettings`، پارامتر `fakeAnswerState` از `updateSession`، تمام جایگذاری‌ها در ساخت `GameSession`/`SessionStateRecord`.
- `ViewModels/CasualRoomViewModel.swift` — property `fakeAnswerSettings`، تابع `updateSettings`، تمام مقداردهی‌ها در rejoin/refresh/createRoom/broadcastTeamState.
- `Views/TeamSetupView.swift` — خط `appModel.currentFakeAnswerSettings = casualVM.fakeAnswerSettings`.

> توجه: ستون‌های `settings_rounds/settings_answer_time/settings_vote_time/settings_question_pack` در جدول `casual_rooms` و RPC `casual_update_room_settings` در دیتابیس Supabase دست‌نخورده باقی مانده‌اند. در migration بعدی می‌توانند drop شوند.

Build بعد از پاکسازی FakeAnswer: ✅ سبز.

## 4. تاریخچه کامل توسعه (Git Log)

ترتیب: قدیمی به جدید. ۵۹۰ commit.

- `1a2633e` **2026-04-05** — Developed a modern and polished party games app with multiple game modes and social features.
- `05903b1` **2026-04-05** — Improved the app to make it more social, rewarding, and fun to use.
- `2d0374a` **2026-04-05** — Connect the app to a secure online system for accounts and rewards.
- `9858d7a` **2026-04-05** — Finalized the game's online features and improved how player progress is saved.
- `8319ef3` **2026-04-05** — Updated the app to fix issues with logging in, playing with friends, and receiving game rewards.
- `dfb9164` **2026-04-05** — Redesigned the app's look to be cleaner, simpler, and easier to use.
- `ec4623a` **2026-04-05** — Refined the app's appearance to make it look cleaner and feel easier to use.
- `9071a8c` **2026-04-05** — We've updated the app design to make it easier to find games and play with friends.
- `019d084` **2026-04-05** — Fixed the issues preventing games from starting and playing correctly.
- `b11c632` **2026-04-05** — بازطراحی صفحه ورود و امکان ورود مستقیم به برنامه به عنوان مهمان
- `68d463c` **2026-04-05** — جدا سازی دوستان آفلاین و آنلاین و اضافه کردن قابلیت دعوت به بازی
- `3b6c1eb` **2026-04-05** — New version from Rork
- `e427e54` **2026-04-05** — Add a numeric ID for users and show email in profile.
- `f6efd95` **2026-04-05** — Updated the friends list and added a feature to find and add new friends.
- `04c981a` **2026-04-05** — Add player IDs and improve how you find and add friends.
- `77d9c10` **2026-04-05** — New version from Rork
- `563044b` **2026-04-05** — New version from Rork
- `4d25d0b` **2026-04-05** — اصلاح سیستم دوستان و رفع مشکلات فنی برنامه برای اجرای بهتر.
- `9983ed6` **2026-04-05** — رفع تداخل در تنظیمات بخش بازی‌های آنلاین و اصلاح کدهای پایگاه داده.
- `4ed0e87` **2026-04-05** — تغییر چیدمان منوی اصلی و اضافه شدن بخش لابی.
- `864c106` **2026-04-05** — Updated the Friends screen and added new ways to find and add people.
- `5a112b8` **2026-04-05** — Updated the Lobby to be the main hub for online games.
- `bbe4eea` **2026-04-05** — Completed the interactive gameplay features for all three games and improved the overall game flow.
- `ce8ae89` **2026-04-05** — Added three new games: Hot Bomb, Wrong Answer Only, and Title It.
- `4d4ac62` **2026-04-05** — Improved how games start and play to make them work better.
- `8bbe181` **2026-04-05** — Updated the design of the wallet screen to look cleaner and more modern.
- `50a5b59` **2026-04-06** — ساده‌سازی و بهبود طراحی بخش لابی
- `64ba16f` **2026-04-06** — اضافه شدن زبان‌های جدید و بخش تنظیمات به پروفایل
- `51fd23f` **2026-04-06** — به‌روزرسانی ظاهر پروفایل، تنظیمات زبان و تغییر فونت فارسی به وزیر
- `f3a6eb0` **2026-04-06** — Make the friends list and game invitations work for real.
- `6c4c3cf` **2026-04-06** — Updated the games, wallet, and multiplayer features.
- `a8dc2a5` **2026-04-06** — New version from Rork
- `1c5c390` **2026-04-06** — Updated the app's connection settings and created a database setup guide.
- `3b2ef9a` **2026-04-06** — Updated the game database to be more secure and reliable.
- `c18ba49` **2026-04-06** — New version from Rork
- `e207612` **2026-04-06** — New version from Rork
- `115203a` **2026-04-06** — رفع خطای فنی در بخش مدیریت اطلاعات و خریدها.
- `dedf081` **2026-04-06** — بهبود بخش‌های داخلی برنامه، فعال‌سازی اعلان‌ها و اصلاح فونت فارسی
- `ee17cd8` **2026-04-06** — بازطراحی ظاهر کارت‌های بازی، صفحه لابی و اضافه شدن بخش آموزش و ویدیو
- `4810757` **2026-04-06** — یکسان‌سازی اندازه کارت‌های بازی و حذف نام‌های تکراری
- `ba33121` **2026-04-06** — به‌روزرسانی طراحی کارت‌های بازی و نمایش نحوه بازی به جای جزئیات فنی
- `129c99f` **2026-04-06** — جداسازی بازی‌ها و آموزش‌ها در تب‌های مجزا و بهینه‌سازی ظاهر کارت‌ها و صفحات بازی
- `7581105` **2026-04-06** — Improved friend search and added a store section for unlocking items.
- `0e3dcdb` **2026-04-06** — اضافه شدن بازی «آواز برعکس» با راهنمای فارسی و محیطی ساده.
- `6a3fb62` **2026-04-06** — بهبود عملکرد دکمه‌های انتخاب حالت بازی در صفحه جزئیات
- `c743c51` **2026-04-06** — اضافه شدن بازی جذاب «خوانندگی معکوس» به همراه سیستم امتیازدهی هوشمند
- `5e35170` **2026-04-06** — حذف بازی Reverse Singing از لیست بازی‌ها
- `0ffb868` **2026-04-06** — بهینه‌سازی ظاهر لابی و کارت‌های بازی و اضافه شدن بازی آواز معکوس به همراه ویدیوهای آموزشی
- `03fdeb7` **2026-04-06** — اضافه کردن بازی خوانندگی معکوس به لیست بازی‌ها
- `7980f8b` **2026-04-06** — حذف تمامی بازی‌های موجود و کدهای مربوطه برای شروع مجدد پروژه.
- `4b7c645` **2026-04-06** — Restored to the previous version
- `80bc7fa` **2026-04-06** — پاک‌سازی بازی‌های فعلی برای آماده‌سازی جهت افزودن بازی‌های جدید.
- `20612cc` **2026-04-06** — نام اپلیکیشن به 888Play تغییر کرد و بازی جدید «خوانندگی معکوس» اضافه شد.
- `70d53c8` **2026-04-07** — Added three new ways to play games and a system to track your progress.
- `2649a7f` **2026-04-07** — Implement the full economy and progression system for 888Play.
- `c738d3d` **2026-04-07** — Added the Reverse Singing game to the app.
- `9a84539` **2026-04-07** — تغییرات جدید در بازی خوانندگی معکوس و رایگان شدن آن
- `72965ce` **2026-04-07** — Restored to the previous version
- `a0e63a2` **2026-04-07** — به‌روزرسانی بازی Reverse Singing و ساده‌سازی منوها
- `25ca2c3` **2026-04-07** — ظاهر بازی «برعکس‌خوانی» طبق عکس‌های جدید تغییر کرد.
- `2573da0` **2026-04-08** — به‌روزرسانی ظاهر دکمه‌ها و چیدمان صفحه بازی برای هماهنگی بیشتر با برنامه.
- `87a3f24` **2026-04-08** — کاهش فاصله خالی بالای صفحه در بازی خوانندگی معکوس
- `09a2167` **2026-04-08** — Saved edited files
- `e8a1911` **2026-04-08** — Saved edited files
- `a04a3a6` **2026-04-08** — کاهش فاصله خالی بالای صفحه اصلی برنامه.
- `7741750` **2026-04-08** — اصلاح چیدمان صفحه اصلی و رنگ‌بندی تب‌ها
- `7e0e88b` **2026-04-08** — ظاهر منوی اصلی و بخش‌های برنامه برای استفاده راحت‌تر تغییر کرد.
- `808d12c` **2026-04-08** — اضافه شدن بازی جدید «حدس ثانیه» به بخش ۸۸۸پلی.
- `000f1c1` **2026-04-08** — بازطراحی صفحه تنظیمات و رابط کاربری بازی حدس ثانیه
- `4c39b8b` **2026-04-08** — به‌روزرسانی رابط کاربری و تغییر منطق انتخاب زمان در بازی حدس ثانیه
- `0303901` **2026-04-08** — اضافه شدن دکمه سه نقطه برای خروج و بازگشت در تمامی بازی‌ها
- `5124494` **2026-04-08** — اضافه شدن دکمه خروج و بازگشت به صفحات بازی
- `de3fc60` **2026-04-08** — بازطراحی صفحه پروفایل، منوی انتخاب بازی و بهبود ظاهر بازی
- `242640f` **2026-04-08** — بهبود تنظیمات شروع بازی و چیدمان بخش‌ها
- `0b71b13` **2026-04-08** — جابه‌جایی نام بازی به بالای تصویر در صفحه اصلی
- `f6e7720` **2026-04-08** — بهبود بخش تنظیمات بازی و ظاهر صفحه اصلی
- `97b7e78` **2026-04-08** — بهبود ظاهر بخش بازیکن اول در بازی خوانندگی معکوس
- `b633adc` **2026-04-08** — به‌روزرسانی نحوه بازگشت به صفحه اصلی بازی‌ها و تغییر ظاهر دکمه‌های انتخاب نوع بازی
- `276ad0d` **2026-04-08** — تغییر نام و ظاهر دکمه شروع بازی در حالت تک دستگاه
- `bdbbf0f` **2026-04-08** — به‌روزرسانی نمایش وضعیت بازیکن دوم در بازی آواز معکوس
- `cd86866` **2026-04-08** — Saved edited files
- `a94a59e` **2026-04-08** — Restored to the previous version
- `9153c94` **2026-04-08** — ساده‌سازی صفحه بازی و تغییر متن‌های راهنما
- `ea49746` **2026-04-08** — دکمه‌های فیلتر در صفحه بازی‌ها کوچک‌تر شدند.
- `ca460a1` **2026-04-08** — تغییرات در ظاهر صفحه بازی
- `66b3181` **2026-04-08** — حذف متن توضیحات دکمه شروع بازی
- `801489e` **2026-04-08** — Add the Guess the Fake Answer multiplayer game
- `13dc8a8` **2026-04-09** — به‌روزرسانی بخش بازی‌های گروهی و اضافه شدن قابلیت ورود سریع
- `59e4c2f` **2026-04-09** — Restored to the previous version
- `94f0f37` **2026-04-09** — تغییر طراحی دکمه‌ها و ساده‌سازی فرآیند ورود به اتاق بازی
- `a2f4210` **2026-04-09** — اضافه شدن بخش راهنما، حالت بازی تک‌دستگاه جدید و بهبود دسترسی به پروفایل در بازی‌ها
- `54c53d5` **2026-04-09** — ساده‌سازی ورود به بازی‌های چندنفره و حذف نیاز به لاگین
- `b133d37` **2026-04-09** — Fix anonymous auth fallback and 1-device stuck state
- `95331c1` **2026-04-09** — Revert "Fix anonymous auth fallback and 1-device stuck state"
- `2082bb2` **2026-04-09** — Fix: anonymous auth fallback, 1-device stuck state, toast auto-dismiss
- `2c819e4` **2026-04-09** — Revert "Fix: anonymous auth fallback, 1-device stuck state, toast auto-dismiss"
- `af622f2` **2026-04-09** — امکان بازی چندنفره بدون نیاز به حساب کاربری اضافه شد.
- `aa68eea` **2026-04-09** — رفع مشکلات فنی و آماده‌سازی برنامه برای اجرا
- `43a9c1a` **2026-04-09** — مشکل نصب نشدن برنامه روی شبیه‌ساز برطرف شد.
- `f74e90c` **2026-04-09** — Restored to the previous version
- `2514328` **2026-04-09** — You can now play casual games with friends using a simple room code without needing to sign in.
- `3771700` **2026-04-09** — New version from Rork
- `ea00381` **2026-04-09** — Improved multiplayer game stability and connection reliability.
- `3028728` **2026-04-09** — Improved the multiplayer room system for better stability and security.
- `0132a0f` **2026-04-09** — New version from Rork
- `c898233` **2026-04-09** — Improve game room reliability and add automatic rejoining.
- `f6ff6b7` **2026-04-09** — بهینه‌سازی رابط کاربری بخش لابی و رفع مشکلات بازی حدس جواب واقعی
- `6a98ea6` **2026-04-09** — رفع مشکل توقف بازی و بهبود تنظیمات دورهای بازی
- `5a57dc9` **2026-04-10** — اضافه شدن بازی جدید Ten Tangle و بهبود پایداری سیستم بازی‌های چندنفره.
- `e82ee43` **2026-04-10** — Restored to the previous version
- `8fc8d19` **2026-04-10** — Added a new game called Ten Tangle for group play.
- `a87368b` **2026-04-10** — رفع مشکل توقف بازی «حدس جواب واقعی» در حالت تک‌دستگاهی و بهبود بخش پایانی بازی.
- `aa92850` **2026-04-10** — یکسان‌سازی اندازه کارت‌های بازی در صفحه اصلی
- `f1d36c3` **2026-04-10** — بزرگ‌تر کردن اندازه و تغییر طراحی کارت‌های بازی.
- `01e1077` **2026-04-10** — Restored to the previous version
- `8e887ec` **2026-04-10** — بازطراحی و بزرگ‌تر کردن کارت‌های بازی
- `296479f` **2026-04-10** — Restored to the previous version
- `4526940` **2026-04-10** — تغییر ظاهر و اندازه کارت‌های بازی
- `ca6a8d5` **2026-04-10** — Restored to the previous version
- `1237f07` **2026-04-10** — بازطراحی و افزایش ارتفاع کارت‌های بازی در صفحه اصلی
- `91b5a06` **2026-04-10** — Restored to the previous version
- `d5df0e6` **2026-04-10** — تغییر ظاهر و بزرگ‌تر کردن کارت‌های بازی در منوی اصلی
- `4daa589` **2026-04-10** — Restored to the previous version
- `175186c` **2026-04-10** — کارت‌های بازی در صفحه اصلی بزرگ‌تر شدند و ظاهر جدیدی پیدا کردند.
- `2894349` **2026-04-10** — یکسان‌سازی کارت‌های بازی و به‌روزرسانی تنظیمات ظرفیت و برچسب‌ها
- `2386015` **2026-04-10** — بهینه‌سازی ظاهر کارت‌های بازی و یکپارچه‌سازی صفحات برنامه
- `4e4181e` **2026-04-10** — Restored to the previous version
- `7bf3bf7` **2026-04-10** — بهبود ظاهر کارت‌های بازی و بازطراحی بخش‌های لابی، دوستان و کیف پول برای تجربه کاربری بهتر.
- `8fcf98f` **2026-04-10** — به‌روزرسانی ظاهر کارت‌های بازی و مرتب‌سازی صفحه لابی و بخش مسابقات.
- `2d71867` **2026-04-10** — به‌روزرسانی ظاهر صفحه لابی و بازطراحی بخش ورود به حساب کاربری
- `9a3b9e3` **2026-04-10** — بهبود صفحه ورود، لابی و چیدمان کارت‌های بازی
- `b7bb5c9` **2026-04-10** — یکسان‌سازی ظاهر کارت‌های بازی و تغییر آیکون بازی Ten Tangle
- `d9bb97e` **2026-04-10** — بازی جدید ایمپاستر با سبک‌های مختلف بازی اضافه شد.
- `0d2da03` **2026-04-10** — Feshordeh tar kardane safheye tanzimate bazi ha va behbod namayeshe naghsh ha
- `6a149df` **2026-04-10** — Restored to the previous version
- `d029bc1` **2026-04-10** — به‌روزرسانی طراحی بازی شیاد و بهینه‌سازی بخش تنظیمات
- `cabc840` **2026-04-10** — تغییر متن بالای صفحه و کوچک‌تر کردن دکمه‌های انتخاب بازی
- `3091c80` **2026-04-10** — Restored to the previous version
- `861eeb8` **2026-04-10** — بهبود ظاهر و نحوه انتخاب حالت‌های بازی در بخش بازی جاسوس (Imposter)
- `06d9c2b` **2026-04-10** — Added a new team mode for playing together in groups.
- `9c64a63` **2026-04-10** — بازطراحی کارت‌های انتخاب حالت بازی جاسوس.
- `2d8c664` **2026-04-10** — اضافه شدن بازی جدید Memory Grid به برنامه.
- `189efbd` **2026-04-10** — رفع مشکلات دکمه‌ها و بهبود ظاهر بازی‌ها
- `da5e7ff` **2026-04-10** — بهینه‌سازی ظاهر بازی‌ها و تغییرات در بازی حافظه
- `c18d1b9` **2026-04-10** — بهبود ظاهر بخش تیم‌ها و رفع اشکالات بازی حافظه.
- `e6f031e` **2026-04-10** — New version from Rork
- `7eb2dbf` **2026-04-11** — رفع مشکل منوی بازی و دکمه‌های خروج در بازی حافظه (Memory Grid)
- `4066fc4` **2026-04-11** — رفع مشکل دکمه‌های شروع مجدد و خروج در بازی حافظه
- `f571a86` **2026-04-11** — رفع مشکل دکمه‌های خروج و بازگشت در بازی حافظه
- `64f2520` **2026-04-11** — دکمه‌های خروج و بازگشت در بازی حافظه اصلاح شدند.
- `3f36866` **2026-04-11** — رفع مشکل دکمه‌های خروج و بازگشت در بازی حافظه
- `b92a85b` **2026-04-11** — اصلاح منوی سه نقطه و دکمه‌های خروج در بازی‌ها
- `531a17d` **2026-04-11** — رفع مشکل دکمه‌های خروج و بازگشت در بازی
- `afbaa15` **2026-04-11** — New version from Rork
- `544cd85` **2026-04-11** — اصلاح دکمه‌های منو و خروج در بازی
- `c28dfdd` **2026-04-11** — تغییر منوی بازی‌ها به حالت پاپ‌آپ برای دسترسی بهتر.
- `5d6402d` **2026-04-12** — Restored to the previous version
- `f843f95` **2026-04-12** — تغییر نحوه نمایش منو به صورت شناور روی صفحه بازی
- `5bb19cc` **2026-04-12** — اصلاح محل قرارگیری منوی بازی برای جلوگیری از پوشانده شدن محتوا
- `1695388` **2026-04-12** — جابه‌جایی دکمه منو به نوار بالای صفحه
- `b325458` **2026-04-12** — Restored to the previous version
- `3942aa1` **2026-04-12** — Restored to the previous version
- `e572dba` **2026-04-12** — کم کردن فاصله بالای صفحه در محیط بازی
- `b95af7e` **2026-04-12** — Restored to the previous version
- `53d85a2` **2026-04-12** — نمایش آیکون پروفایل فقط در منوهای اصلی و جایگزینی آن با منوی سه‌نقطه در صفحات بازی.
- `bfe2a48` **2026-04-12** — Restored to the previous version
- `df35635` **2026-04-12** — اصلاح نمایش آیکون پروفایل و اضافه کردن منوی خروج در محیط بازی
- `e38d0c1` **2026-04-13** — اصلاح دکمه خروج از بازی و اضافه کردن پیام تایید.
- `6dafa8c` **2026-04-13** — Added a new game called Pass & Guess for playing together on one phone.
- `abc3620` **2026-04-13** — Added a way for everyone to play Pass & Guess on their own phones at the same time.
- `9a6c139` **2026-04-13** — Added a new game called Memory Path to the app.
- `216899f` **2026-04-13** — Restored to the previous version
- `be563b1` **2026-04-13** — اضافه شدن بازی جدید «مسیر حافظه» به برنامه
- `5551000` **2026-04-14** — رفع مشکل دکمه‌های بازی و اضافه شدن امکان تعیین سختی مراحل.
- `dcd1661` **2026-04-14** — بهبود بازی مسیر حافظه و رفع مشکلات دکمه‌ها و زمان‌بندی.
- `cf4bf97` **2026-04-14** — محدود کردن شرایط استفاده از راهنما در بازی Memory Path
- `7ffbcf4` **2026-04-14** — New version from Rork
- `9e4916d` **2026-04-14** — بهبودهای کلی و رفع مشکلات بازی «مسیر حافظه»
- `13a88a5` **2026-04-14** — آماده‌سازی نهایی برنامه برای انتشار در فروشگاه اپل و بررسی سیستم‌های دیتابیس.
- `de07ba0` **2026-04-14** — آماده‌سازی دیتابیس نهایی و بررسی شرایط انتشار در اپ استور
- `6f3c52a` **2026-04-14** — رفع خطاهای فنی و اضافه کردن امکان حذف حساب کاربری
- `138c564` **2026-04-14** — رفع خطای بخش تنظیمات دیتابیس بازی.
- `58d3350` **2026-04-14** — New version from Rork
- `5906e38` **2026-04-14** — New version from Rork
- `97639aa` **2026-04-14** — رفع خطاهای دیتابیس و آماده‌سازی نهایی برنامه
- `fac8f2b` **2026-04-14** — رفع مشکلات دیتابیس برای اجرای بدون خطای برنامه.
- `02ba906` **2026-04-14** — New version from Rork
- `e5e3617` **2026-04-14** — New version from Rork
- `2e86503` **2026-04-14** — New version from Rork
- `a8de23d` **2026-04-14** — New version from Rork
- `3ae2149` **2026-04-14** — New version from Rork
- `bd565b4` **2026-04-14** — New version from Rork
- `fc5dcc8` **2026-04-14** — Added monthly and yearly subscription options
- `46b8793` **2026-04-14** — Added sounds, animations, and a welcome guide to make the app more fun.
- `08d83e2` **2026-04-14** — New version from Rork
- `8a9739d` **2026-04-14** — Improved the path generation for the Memory Path game to create more engaging and varied levels.
- `eb2b6a5` **2026-04-14** — Create a new app icon for the 888Play party game.
- `ca9dd3d` **2026-04-14** — یکپارچه‌سازی سیستم خرید ستاره و اشتراک ماهانه
- `42c85c3` **2026-04-14** — Added a new section with ideas for real-life party games.
- `79348fb` **2026-04-14** — رفع مشکل خطا در هنگام خرید ستاره‌ها
- `8d3ce49` **2026-04-14** — حذف بخش معرفی و نمایش تعداد بازی‌ها در تب‌ها
- `6f9574c` **2026-04-14** — حذف بخش تنظیمات نام کاربری و نماد آواتار از پروفایل
- `0408ad9` **2026-04-14** — Updated project settings
- `4801e35` **2026-04-14** — رفع خطای اجرا نشدن برنامه به دلیل آدرس اشتباه فایل‌ها
- `1e03a62` **2026-04-14** — Updated project settings
- `c67c25a` **2026-04-14** — New version from Rork
- `56cb894` **2026-04-14** — New version from Rork
- `8695792` **2026-04-14** — New version from Rork
- `f404956` **2026-04-14** — بهینه‌سازی و رفع ایرادات بخش بازی آواز معکوس
- `301f36d` **2026-04-14** — ترتیب بازی‌ها تغییر کرد و ظاهر صفحات و دکمه‌ها در تمام بازی‌ها یکسان و هماهنگ شد.
- `9239b5f` **2026-04-14** — تغییر ترتیب بازی‌ها و رفع چند مشکل فنی
- `ebc1369` **2026-04-14** — Updated project settings
- `a3d2047` **2026-04-14** — Taghyire zaheriye baziye Reverse Singing va hazfe entekhabe zaban.
- `7f0abd7` **2026-04-14** — بهبود بخش بازی آواز معکوس و تنظیمات جدید برای ضبط صدا
- `6d04211` **2026-04-14** — افزودن صدا و لرزش به بازی‌ها و اصلاح بخش تاریخچه و تنظیمات
- `c47fa36` **2026-04-14** — Updated project settings
- `746b873` **2026-04-14** — Updated project settings
- `fe841e8` **2026-04-14** — بهبود صداها و رفع مشکل ضبط در بازی آواز معکوس
- `9e9ef63` **2026-04-15** — هماهنگ‌سازی ظاهر برنامه و بهبود کیفیت ضبط صدا در بازی‌ها
- `5de48fd` **2026-04-15** — یکپارچه‌سازی و بازطراحی صفحات تنظیمات بازی‌ها
- `abc985a` **2026-04-15** — تغییر ظاهر کارت‌های بازی و یکسان‌سازی صفحه تنظیمات
- `c321253` **2026-04-15** — افزایش تعداد بازیکنان و بزرگ‌تر کردن آیکون بازی‌ها
- `5b7f4b9` **2026-04-15** — New version from Rork
- `7393839` **2026-04-15** — New version from Rork
- `9063350` **2026-04-15** — New version from Rork
- `b12ef9c` **2026-04-15** — New version from Rork
- `c9e338c` **2026-04-15** — New version from Rork
- `70b78f6` **2026-04-15** — بروزرسانی ظاهر و نوشته‌های صفحه شروع بازی‌ها
- `af8f450` **2026-04-15** — Taghyire tarrahiye hero card va be ruz resaniyekomeye multi device
- `5232f92` **2026-04-15** — اضافه کردن آیکون‌های مرتبط برای تمامی بازی‌های دورهمی
- `7a46d55` **2026-04-15** — Taghyire zaher va tartibe filterhaye baziha
- `a1aecd8` **2026-04-15** — Updated project settings
- `1ef6f7a` **2026-04-15** — New version from Rork
- `bb9d3b5` **2026-04-15** — ساده‌سازی آیکون‌های بازی و اصلاح آیکون چندگوشی
- `95ae5f6` **2026-04-15** — آیکون‌های بخش آموزش بازی‌های دورهمی به حالت توپر بازگردانده شدند.
- `7846e36` **2026-04-15** — بازگرداندن آیکون‌های اصلی بازی به حالت توپر
- `106696e` **2026-04-15** — حذف پس‌زمینه از نشان‌گر تعداد بازیکنان در کارت‌های بازی
- `15dabec` **2026-04-15** — اضافه کردن راهنمای کوتاه برای هر بازی
- `a8940e8` **2026-04-15** — Restored to the previous version
- `073309b` **2026-04-15** — New version from Rork
- `753e969` **2026-04-15** — بروزرسانی تصاویر کارت‌های بازی به سبک ساده و مینیمال
- `892385a` **2026-04-15** — تغییر طراحی بخش انتخاب سبک بازی و اضافه شدن تصاویر جدید
- `ee2b3e6` **2026-04-15** — Taghir axhaye baziye Imposter va jabejayi tedad-e bazikonha dar cardha
- `ab30266` **2026-04-15** — وسط‌چین کردن آیکون‌ها و متن‌های کارت‌های بازی
- `edced9f` **2026-04-15** — New version from Rork
- `030b020` **2026-04-15** — Fixed critical app issues and improved the start-up experience.
- `aa7f7ef` **2026-04-15** — تغییر چیدمان کارت‌های بازی در صفحه اصلی و اصلاح صفحه خوش‌آمدگویی.
- `3ac58e8` **2026-04-15** — New version from Rork
- `94828cc` **2026-04-15** — تغییر چیدمان بازی‌ها در صفحه اصلی به صورت دوتایی و مربعی.
- `f4f4986` **2026-04-15** — تغییر چیدمان و ظاهر کارت‌های بازی در صفحه اصلی
- `9af5073` **2026-04-15** — Restored to the previous version
- `770696b` **2026-04-15** — تغییر ظاهر کارت‌های بازی در صفحه اصلی
- `def23af` **2026-04-15** — حذف بازی Guess the Real Answer و به‌روزرسانی حالت‌های سایر بازی‌ها
- `894fc4c` **2026-04-15** — Updated game settings and cleaned up game lists.
- `e3b2daf` **2026-04-15** — New version from Rork
- `dfb0918` **2026-04-15** — فعال‌سازی قابلیت بازی چندنفره و تورنمنت برای بازی‌های اصلی
- `79b73a9` **2026-04-15** — New version from Rork
- `886fae6` **2026-04-15** — Improved multiplayer game stability and connection recovery.
- `6ee80cb` **2026-04-15** — New version from Rork
- `268ca69` **2026-04-15** — طراحی وب‌سایت جدید برای 888Play و افزودن صفحات قانونی.
- `87155eb` **2026-04-15** — New version from Rork
- `f79082d` **2026-04-15** — New version from Rork
- `8b69b32` **2026-04-16** — مرکز‌چین کردن و بزرگ‌تر کردن متن سناریو در بازی
- `61e3cba` **2026-04-16** — محدود کردن تعداد دورها و زمان در بازی حدس ثانیه
- `6e5bc36` **2026-04-16** — Tanzime adad-haye baziye Ten Tangle bar asase tedade bazikon-ha
- `45eaf70` **2026-04-16** — تغییر صفحات خوش‌آمدگویی و اضافه کردن قابلیت ثبت نام.
- `bdedc38` **2026-04-16** — تغییر صفحه معرفی بازی‌ها در قسمت شروع برنامه
- `55964f8` **2026-04-16** — تغییر نام برنامه به 888PartyPlay و بروزرسانی سایت
- `504f332` **2026-04-16** — New version from Rork
- `25c404d` **2026-04-16** — به‌روزرسانی بخش بازی خوانندگی معکوس
- `cce697b` **2026-04-16** — New version from Rork
- `2b73d10` **2026-04-16** — به‌روزرسانی متن‌های وب‌سایت و حذف تعداد بازی‌ها
- `085890f` **2026-04-16** — Updated project settings
- `3c32f87` **2026-04-16** — به‌روزرسانی ظاهر دکمه‌های بازی و حذف بخش مسابقات از حدس زمان
- `c882906` **2026-04-16** — به‌روزرسانی تنظیمات بازی Ten Tangle و یکپارچه‌سازی صفحات آماده‌سازی بازی‌ها
- `b252d48` **2026-04-16** — انتقال بخش انتخاب سوال بازی Pass & Guess به شروع راند
- `9108a55` **2026-04-16** — New version from Rork
- `1f08e3e` **2026-04-16** — Updated project settings
- `d5abedb` **2026-04-16** — Create a new app icon for 888 Party Play.
- `95b9f1f` **2026-04-16** — تنظیم تصویر جدید برای آیکون برنامه
- `70ac228` **2026-04-16** — Updated project settings
- `f398d49` **2026-04-16** — Updated project settings
- `a3d918a` **2026-04-16** — Updated project settings
- `ea9e140` **2026-04-16** — تغییر نام برنامه به 888 PartyPlay
- `bf4a1ba` **2026-04-16** — اضافه کردن صداهای حرفه‌ای و بهبود ظاهر بازی‌ها
- `ddfd03f` **2026-04-16** — افزودن لوگو و آیکون به وب‌سایت
- `50ca7d5` **2026-04-16** — تغییر ترتیب بخش بازیکنان و محدود کردن تعداد دورهای بازی
- `0fe509f` **2026-04-16** — Be ruz resani-ye aykon-e barnameh
- `01de0d2` **2026-04-16** — New version from Rork
- `0580a0f` **2026-04-16** — آماده‌سازی برنامه برای انتشار در اپ استور و رفع ایرادات قانونی
- `cba1941` **2026-04-16** — New version from Rork
- `f370cbd` **2026-04-16** — Final updates for app launch readiness
- `c2c4acc` **2026-04-16** — New version from Rork
- `b626f5d` **2026-04-16** — Polished the app with new features and helpful guides to get it ready for launch.
- `6438ba6` **2026-04-16** — New version from Rork
- `7b32427` **2026-04-16** — New version from Rork
- `80db945` **2026-04-16** — پایدارسازی بخش چندنفره و مدیریت هوشمند قطعی اتصال
- `84c1524` **2026-04-16** — Added easy-to-follow instructions and helpful tips for new players.
- `8fd6060` **2026-04-16** — Improved star earning clarity and friend invitation features.
- `06a9fab` **2026-04-16** — New version from Rork
- `c34638d` **2026-04-16** — New version from Rork
- `15dcae7` **2026-04-16** — New version from Rork
- `7102cd1` **2026-04-16** — Improved the Star reward system to make it more reliable and secure.
- `8272592` **2026-04-16** — Updated the game's payment system and star rewards.
- `a52b367` **2026-04-16** — New version from Rork
- `abaf68f` **2026-04-17** — Added two new competitive games, Tap in Order and Color Trap, with multiplayer and tournament support.
- `402e4b7` **2026-04-17** — Update Tap In Order game with two new memory modes.
- `68aaa27` **2026-04-17** — اضافه کردن محدودیت خطا، انیمیشن‌های پایان بازی و تنظیمات پیشرفته شبکه در بازی «Tap in Order»
- `00d1939` **2026-04-17** — تغییر نحوه برنده شدن و حذف محدودیت باخت در بازی Tap In Order
- `9f38b17` **2026-04-17** — اصلاح نمایش آمار بازی و اضافه کردن قابلیت انصراف
- `5b66fa2` **2026-04-17** — Added a new "Draw & Rush" drawing and guessing game.
- `c881c24` **2026-04-17** — به‌روزرسانی بازی نقاشی: داوری توسط بازیکن و انتخاب موضوع آزاد
- `b66492b` **2026-04-17** — بازطراحی بخش کیف پول، حذف سیستم امتیاز XP و بهبود ظاهر صفحات بازی
- `a0e10c5` **2026-04-17** — به‌روزرسانی رابط کاربری بازی Draw & Rush و بازطراحی بخش کیف پول
- `6fe3c98` **2026-04-17** — حذف بخش اقتصاد تورنمنت از صفحه کیف پول
- `d8e68d7` **2026-04-17** — به‌روزرسانی رابط کاربری بازی‌ها و مدیریت لیست دوستان
- `052bdac` **2026-04-17** — Updated project settings
- `3947718` **2026-04-17** — Fixed a sound-related error that was preventing the app from being finalized for the App Store.
- `a1f9d2b` **2026-04-17** — Updated project settings
- `f597d94` **2026-04-17** — بهبود فرآیند خرید و نمایش مستقیم جزئیات بسته‌ها
- `1ca3b25` **2026-04-17** — یکسان‌سازی صفحات تنظیمات و اضافه کردن راهنمای بازی
- `1e9d3cd` **2026-04-17** — به‌روزرسانی منوی اصلی و انتقال بخش کیف پول به پروفایل.
- `b87d7b6` **2026-04-17** — Kuchak kardan profile va yeki kardan Lobby va Friends.
- `0bf7f03` **2026-04-17** — New version from Rork
- `2db36b6` **2026-04-17** — Added a new "Cards" section with ready-to-use party game prompts.
- `f90fca3` **2026-04-17** — حذف بخش حالت مهمان و نگه داشتن دکمه ورود
- `d4f46ec` **2026-04-17** — طراحی بخش انتخاب‌گر به سبک شیشه‌ای تغییر یافت.
- `998b6b5` **2026-04-17** — بازطراحی بخش کارت‌ها با ظاهر و منطق جدید
- `9c5f859` **2026-04-17** — به‌روزرسانی بخش کارت‌ها با دسته‌بندی‌های جدید و قابلیت هوش مصنوعی
- `69b0952` **2026-04-17** — به‌روزرسانی بخش کارت‌ها با دسته‌بندی‌های جدید و تغییرات ظاهری
- `16f06e9` **2026-04-17** — Redesigned the Cards feature with new categories and simpler filters.
- `a2d5fb6` **2026-04-17** — بازطراحی بخش کارت‌ها و اضافه کردن قابلیت تولید با هوش مصنوعی
- `df079d7` **2026-04-17** — ۸۸۸ کارت جدید و جذاب به بخش‌های مختلف بازی اضافه شد.
- `ceb44dc` **2026-04-17** — به‌روزرسانی ظاهر بخش کارت‌های بازی
- `740464a` **2026-04-17** — سیستم فیلتر کارت‌ها برای نمایش دقیق‌تر دسته‌بندی‌ها به‌روزرسانی شد.
- `2eda236` **2026-04-17** — Move Icebreaker to the Talk category.
- `059cd3f` **2026-04-17** — اضافه شدن بخش جدید «شروع‌کننده‌ها» به قسمت گفتگو و به‌روزرسانی لیست سوالات.
- `6127a3d` **2026-04-17** — به‌روزرسانی طراحی بخش کارت‌ها با ظاهری مدرن و جذاب
- `bfb954b` **2026-04-17** — بازطراحی کامل ظاهر بخش کارت‌ها و بهبود تجربه کاربری
- `675380a` **2026-04-17** — Fix various app errors to improve stability.
- `75548e2` **2026-04-17** — اضافه شدن سیستم تولید کارت با هوش مصنوعی
- `8293140` **2026-04-17** — Updated adult game cards to be more daring and exciting.
- `3c9d4dc` **2026-04-17** — Added a new Spin the Bottle game for playing together on one phone.
- `e829254` **2026-04-17** — Updated project settings
- `afdabb6` **2026-04-17** — New version from Rork
- `7461b87` **2026-04-17** — New version from Rork
- `002204b` **2026-04-18** — به‌روزرسانی طراحی و انیمیشن بازی چرخش بطری
- `3f24ead` **2026-04-18** — New version from Rork
- `c2d46c4` **2026-04-18** — تغییر ظاهر اسامی بازیکنان و طولانی‌تر کردن زمان چرخش بطری
- `ec8c28f` **2026-04-18** — افزایش زمان چرخش بطری در بازی
- `d7bf72b` **2026-04-18** — بهبود انیمیشن و دکمه چرخش بطری
- `09b89fc` **2026-04-18** — به‌روزرسانی ظاهر صفحه بازی و ساده‌سازی لیست‌ها
- `7fa592b` **2026-04-18** — تغییر ظاهر منوی بالای صفحه و اولویت‌بندی بخش دوستان
- `9dd98f8` **2026-04-18** — اضافه شدن ابزارهای جدید بازی شامل تاس، بطری چرخنده و تایمر به برنامه
- `e14e654` **2026-04-18** — به‌روزرسانی طراحی کارت اصلی و دکمه‌های برنامه.
- `8b588ab` **2026-04-18** — بهبود انیمیشن‌های تاس، بطری و ساعت شنی
- `7e6734f` **2026-04-18** — بهبود بازی چرخش بطری و تغییر نام آن به جرات یا حقیقت
- `d2a58c6` **2026-04-18** — به‌روزرسانی تصاویر و انیمیشن‌های تاس و ساعت شنی
- `47be424` **2026-04-18** — Behbood-e animation-e tass va saat sheni baraye hes-e vagheyi-tar.
- `fe1cd5a` **2026-04-18** — نام بازی به «جرئت و حقیقت» تغییر کرد و حرکت بطری بهتر شد.
- `7a88be8` **2026-04-18** — نمایش نام بازیکن انتخاب‌شده و اضافه کردن افکت‌های صوتی
- `ee1d6b2` **2026-04-18** — New version from Rork
- `ae48c80` **2026-04-18** — به‌روزرسانی انیمیشن‌های تاس و ساعت شنی
- `28cf50a` **2026-04-18** — Restored to the previous version
- `f1192e8` **2026-04-18** — بهبود بخش ساعت شنی و بازی جرئت یا حقیقت
- `2b34a39` **2026-04-18** — تغییرات ظاهری در ابزارها و بخش دوستان برنامه
- `62b49e7` **2026-04-18** — بهبود ظاهر آیکون بطری و بررسی آمادگی برنامه
- `6fde901` **2026-04-18** — Updated project settings
- `ef50323` **2026-04-18** — بهبود حرکت تاس، آیکون‌ها و هماهنگ‌سازی فونت‌های برنامه
- `32558db` **2026-04-18** — بهبود ابزار تاس با انیمیشن سه بعدی و اصلاح آیکون بطری.
- `e7dadf2` **2026-04-18** — بروزرسانی ظاهر تاس، شیشه و تغییر نام بخش تولیدکننده
- `ee75f6e` **2026-04-18** — Updated project settings
- `58527ae` **2026-04-18** — Simplified the app economy and updated game access.
- `cb06a5a` **2026-04-18** — Updated project settings
- `0b275a9` **2026-04-18** — New version from Rork
- `b65964b` **2026-04-18** — Simplified the app economy and updated the game library.
- `9a69285` **2026-04-18** — Cleaned up the app and performed a final check of all features and settings.
- `f210a13` **2026-04-18** — حذف بازی‌های اضافی و آماده‌سازی نهایی برنامه برای انتشار
- `0e29718` **2026-04-18** — Finalized app economy and game access for App Store submission.
- `06f96bd` **2026-04-18** — Added a new system to invite friends and earn rewards.
- `439c7e6` **2026-04-18** — New version from Rork
- `15e9abd` **2026-04-18** — New version from Rork
- `b9a2011` **2026-04-18** — New version from Rork
- `75956c6` **2026-04-18** — New version from Rork
- `4ea8380` **2026-04-18** — ساخت پنل مدیریت جامع و سیستم تنظیمات از راه دور
- `623c957` **2026-04-18** — New version from Rork
- `6e319b5` **2026-04-18** — Updated project settings
- `23f35cb` **2026-04-18** — رفع مشکل ورود به بخش مدیریت و آماده‌سازی نهایی برای انتشار
- `6309d2c` **2026-04-19** — رفع مشکل ضبط و پخش در بازی آواز معکوس
- `0abf80d` **2026-04-19** — Updated project settings
- `ea1adf4` **2026-04-19** — رفع مشکل ضبط صدا در بخش خوانندگی معکوس
- `cb7723a` **2026-04-19** — New version from Rork
- `02cd0b1` **2026-04-19** — بهبود سیستم ورود و رفع اشکالات فنی برنامه
- `926ea43` **2026-04-19** — New version from Rork
- `4667699` **2026-04-19** — رفع خطاهای موجود در فایل تنظیمات پایگاه داده برای اجرای صحیح برنامه.
- `a07129d` **2026-04-19** — بروزرسانی وب‌سایت با قابلیت‌های جدید از جمله بازی‌ساز هوش مصنوعی و دسته‌های کارت.
- `3dd26d1` **2026-04-19** — رفع مشکل راه‌اندازی و ورود به پنل مدیریت
- `c435bc3` **2026-04-19** — New version from Rork
- `ef6c211` **2026-04-19** — اضافه شدن بخش ابزارهای بازی به وب‌سایت و بهبود سیستم ورود مدیریت
- `5e0785f` **2026-04-19** — اضافه شدن ابزارهای شیر یا خط و تیم‌بندی به اپلیکیشن
- `70db259` **2026-04-19** — بهبود ابزارهای شیر و خط و گروه‌بندی تیم‌ها در برنامه
- `9f5cdb9` **2026-04-19** — بروزرسانی بخش ابزارها و بهبود انیمیشن شیر یا خط
- `da955cd` **2026-04-19** — بهبود انیمیشن چرخش سکه برای نمایش واقعی‌تر ضخامت و دو طرف آن
- `bf28946` **2026-04-19** — Restored to the previous version
- `07d3ae3` **2026-04-19** — بهبود انیمیشن و طراحی چرخش سکه
- `fed6b5a` **2026-04-19** — واقعی‌تر کردن ظاهر سکه در بخش ابزارها
- `6caf97e` **2026-04-19** — New version from Rork
- `8cbad3d` **2026-04-19** — New version from Rork
- `ea52ccf` **2026-04-19** — New version from Rork
- `cff4b2a` **2026-04-19** — New version from Rork
- `c4527e9` **2026-04-19** — New version from Rork
- `520f09a` **2026-04-19** — New version from Rork
- `c950ab4` **2026-04-19** — New version from Rork
- `60c775b` **2026-04-19** — New version from Rork
- `3d52a2b` **2026-04-19** — New version from Rork
- `843c474` **2026-04-19** — New version from Rork
- `9cb8a9c` **2026-04-19** — New version from Rork
- `b2b164e` **2026-04-19** — یکی کردن بخش مدیریت و وب‌سایت اصلی
- `bddfb7e` **2026-04-19** — به‌روزرسانی بخش ابزارهای وب‌سایت با تصاویر واقعی و اندازه کوچک‌تر
- `a35f710` **2026-04-19** — Bozorgtar kardane noghte haye abi roye tas
- `96da4a9` **2026-04-19** — New version from Rork
- `0586a3d` **2026-04-19** — New version from Rork
- `b63c35e` **2026-04-19** — New version from Rork
- `636dad9` **2026-04-19** — New version from Rork
- `f3da4a7` **2026-04-19** — به‌روزرسانی سیستم برای رفع مشکل امنیتی و نمایش سایت
- `6fbf189` **2026-04-19** — Updated project settings
- `7e6ddd8` **2026-04-19** — اصلاح لینک پنل مدیریت و رفع مشکل ثبت اطلاعات کاربران در اپلیکیشن
- `32368d2` **2026-04-20** — Updated project settings
- `f170a02` **2026-04-20** — Updated project settings
- `14bd858` **2026-04-20** — New version from Rork
- `e9bb2ef` **2026-04-20** — New version from Rork
- `8d9c495` **2026-04-20** — Updated project settings
- `3000970` **2026-04-20** — New version from Rork
- `511dc37` **2026-04-20** — Updated project settings
- `9b55826` **2026-04-20** — New version from Rork
- `f7802bc` **2026-04-20** — New version from Rork
- `ef9c31a` **2026-04-20** — New version from Rork
- `eb74c5b` **2026-04-20** — Updated app configuration and improved the admin dashboard.
- `c44c247` **2026-04-20** — New version from Rork
- `a9ec6a3` **2026-04-20** — Updated app settings and fixed website links.
- `f5c3b5d` **2026-04-20** — New version from Rork
- `be2191f` **2026-04-20** — Updated project settings
- `98dafa2` **2026-04-20** — Updated project settings
- `72b274d` **2026-04-20** — New version from Rork
- `1532a62` **2026-04-20** — اضافه کردن دکمه خروج از حساب کاربری
- `029d2e6` **2026-04-20** — تغییر نام صفحه اجتماعی به دوستان و ساده‌سازی منوها
- `2ec6185` **2026-04-20** — جمع‌وجورتر کردن بخش دوستان آنلاین در صفحه دوستان
- `4ee39e1` **2026-04-20** — جمع‌وجور کردن بخش لیست دوستان آنلاین و آفلاین
- `4ac466d` **2026-04-20** — تغییر زبانه کارت‌ها به ابزار و مرتب‌سازی بخش‌های آن
- `22458aa` **2026-04-20** — تغییر نام بخش باکس به ایده‌ها
- `3afe67e` **2026-04-20** — تغییر ظاهر بخش کارت‌ها و اضافه کردن عنوان جدید
- `d6b8e94` **2026-04-20** — ساده‌سازی و بهینه‌سازی ظاهر صفحه ساخت کارت
- `047719c` **2026-04-20** — تغییر عنوان بخش کارت‌ها به Ready to Use Cards
- `afdc396` **2026-04-20** — مرتب‌سازی و تغییر ظاهر بخش ساخت کارت
- `dd00fd0` **2026-04-20** — نمایش کارت‌ها به صورت لیست در بخش ابزارها
- `dedfe5d` **2026-04-20** — تغییر نام دسته‌بندی‌ها و طراحی مجدد دکمه‌های کنترلی
- `9b8c9bd` **2026-04-20** — بازطراحی کامل بخش ساخت بازی‌های جدید
- `cba6c3b` **2026-04-20** — تغییر چیدمان و کوچک‌تر کردن دکمه‌های انتخاب محتوا
- `b099d5b` **2026-04-20** — بخش ایده‌ها و انتخاب بازیکنان بازطراحی شد.
- `2d30b2c` **2026-04-20** — بخش انتخاب حال و هوای بازی تغییر کرد و فشرده‌تر شد.
- `c773417` **2026-04-20** — به‌روزرسانی دسته‌بندی‌های سبک بازی به ۸ مدل جدید
- `9dfd64b` **2026-04-20** — Updated project settings
- `78fb210` **2026-04-20** — Updated project settings
- `4b280f6` **2026-04-20** — New version from Rork
- `c04cce0` **2026-04-20** — Updated project settings
- `43e58fc` **2026-04-20** — Updated project settings
- `10b46ee` **2026-04-20** — Updated project settings
- `73e748d` **2026-04-20** — Updated project settings
- `e8b1aba` **2026-04-20** — Updated project settings
- `c6052f9` **2026-04-20** — Updated project settings
- `dfb6304` **2026-04-20** — Updated project settings
- `afeb3b4` **2026-04-20** — رفع مشکل ورود به بازی با کد و اصلاح نمایش نوبت بازیکنان.
- `09576da` **2026-04-20** — نمایش نتیجه هر دور در بازی حدس ثانیه
- `91e1624` **2026-04-20** — اصلاح دکمه افزودن دوستان برای کارکرد بهتر
- `552f2f8` **2026-04-20** — بزرگ‌تر کردن نمایش کد شناسایی در بخش پروفایل
- `cf7ddbf` **2026-04-20** — رفع مشکل افزودن دوست
- `2fcdfa8` **2026-04-20** — مشکل بسته نشدن خودکار کیبورد برطرف شد.
- `6501d9e` **2026-04-20** — Updated project settings
- `20c2ae9` **2026-04-21** — مشکلات کیبورد، ورود به بازی با کد و خروج از حساب کاربری برطرف شد.
- `20ea06b` **2026-04-21** — Updated project settings
- `e50da4d` **2026-04-21** — اصلاح خروج از حساب، بستن خودکار کیبورد و بهبود همگام‌سازی بازی‌ها
- `79979be` **2026-04-21** — بررسی و رفع ایرادات اصلی برنامه برای بهبود عملکرد.
- `fbf0851` **2026-04-21** — حل مشکل باقی ماندن کیبورد روی صفحه برنامه.
- `abff3bb` **2026-04-21** — اصلاح مشکل نمایش تصاویر قدیمی در ابزارهای بازی
- `5bbbe82` **2026-04-21** — Updated project settings
- `21885ec` **2026-04-21** — Restored to the previous version
- `cc47a53` **2026-04-21** — New version from Rork
- `0be8a2f` **2026-04-21** — یکپارچه‌سازی فونت عنوان‌ها و تغییر نام برنامه به 888partyplay.
- `eacc7bb` **2026-04-21** — اصلاح فونت عنوان‌ها در کل برنامه
- `d314753` **2026-04-21** — Yeksansazi andazeye fonte tamame title-haye barname
- `78cc8e2` **2026-04-21** — Updated project settings
- `f92dfe8` **2026-04-21** — Behbood-e seda-ha, e'lan-ha va vorood-e khodkar be bazi.
- `7ecaa93` **2026-04-21** — اصلاح اندازه نام برنامه در صفحه ورودی برای نمایش در یک خط
- `a3034b9` **2026-04-21** — اصلاح زمان درخواست اعلان، حذف راهنمای بازی‌ها و افزودن آیکون کارت
- `1c6592b` **2026-04-21** — New version from Rork
- `c99c0e8` **2026-04-21** — New version from Rork
- `9529b00` **2026-04-21** — بهبود پایداری و امنیت بخش‌های مختلف برنامه
- `7ed6f81` **2026-04-22** — اصلاح سیستم مدیریت اتاق‌های بازی و نحوه عملکرد برنامه در پس‌زمینه
- `d90a786` **2026-04-22** — Updated project settings
- `95ec7e7` **2026-04-22** — اضافه شدن دکمه «آماده» برای شروع بازی و بهبود مدیریت اتاق‌های بازی
- `584e3d1` **2026-04-22** — تغییر قالب پیام دعوت برای اشتراک‌گذاری راحت‌تر کد بازی
- `8c51d4e` **2026-04-22** — تمام‌صفحه کردن بخش ورود با کد و هماهنگی شروع بازی
- `a2b2756` **2026-04-22** — New version from Rork
- `5f54547` **2026-04-22** — Improved the multiplayer system for a more reliable and synchronized experience across all games
- `3b13375` **2026-04-22** — Updated project settings
- `7dfcc44` **2026-04-22** — بهبود پایداری اتاق‌های بازی و هماهنگی زمان‌سنج
- `599281d` **2026-04-22** — Restored to the previous version
- `48381bd` **2026-04-22** — New version from Rork
- `fc6053b` **2026-04-22** — بهبود منطق بازی‌های گروهی و هماهنگ‌سازی تنظیمات بین بازیکنان
- `3989bb8` **2026-04-22** — قابلیت همگام‌سازی بازی بین گوشی‌های مختلف در حالت چندنفره اضافه شد.
- `e0500d7` **2026-04-22** — بهبود سیستم مدیریت اتاق و وضعیت آمادگی بازیکنان
- `45d3486` **2026-04-22** — Updated project settings
- `ff90bf8` **2026-04-22** — جداسازی صفحه مدیر و بازیکنان در بازی‌های گروهی و هماهنگ‌سازی شروع بازی.
- `0decb65` **2026-04-22** — Updated project settings
- `d099a44` **2026-04-22** — نمایش نام واقعی افراد هنگام ارسال درخواست دوستی
- `9409180` **2026-04-22** — بهبود نمایش پیام‌های اطلاع‌رسانی و مدیریت بازیکنان در لابی.
- `b46f2d1` **2026-04-22** — حل مشکل شروع نشدن بازی برای بازیکنان میهمان در لابی
- `c48f6e0` **2026-04-22** — هماهنگ‌سازی شروع هم‌زمان بازی و خروج خودکار بازیکنان هنگام ترک میزبان.
- `10e8d69` **2026-04-22** — رفع مشکل خروج خودکار بازیکنان مهمان هنگام شروع بازی
- `27952f4` **2026-04-22** — رفع مشکل نمایش بازی برای تماشاگران و تک‌نفره کردن بازی حدس ثانیه
- `2c46f23` **2026-04-22** — رفع مشکل باز نشدن صفحه بازی برای بازیکنان مهمان
- `ad3c923` **2026-04-22** — بهبود نمایش زنده بازی و رفع مشکل گیر کردن در صفحه انتظار.
- `be632c5` **2026-04-22** — شروع خودکار نوبت بازیکنان در بازی‌های گروهی
- `044ca33` **2026-04-22** — Restored to the previous version
- `33a6f1e` **2026-04-22** — اصلاح روند نوبت‌دهی در بازی و اضافه شدن دکمه شروع نوبت
- `1b58199` **2026-04-23** — بهبود سیستم بازی‌های چندنفره، نمایش نتایج و امکان بازی مجدد
- `44c74dd` **2026-04-23** — New version from Rork
- `2c79673` **2026-04-23** — بهبود پایداری و هماهنگی در بازی‌های چندنفره
- `46c08d4` **2026-04-23** — New version from Rork
- `ce420e9` **2026-04-23** — اصلاح مشکلات بخش بازی چندنفره و بهبود اتصال بازیکنان.
- `1a64356` **2026-04-23** — Improved turn synchronization and rematch reliability for multiplayer games.
- `9dad100` **2026-04-23** — بهبود و اصلاح سیستم بازی چندنفره و همگام‌سازی
- `0388b50` **2026-04-23** — New version from Rork
- `de841ea` **2026-04-23** — New version from Rork
- `21ab670` **2026-04-23** — New version from Rork
- `7fefdd0` **2026-04-23** — Implement multiplayer telemetry and observability layer.
- `9f02199` **2026-04-23** — New version from Rork
- `36fe041` **2026-04-23** — Create monitoring views for multiplayer game stability
- `952ef26` **2026-04-23** — بهبود ظاهر و راحتی کار با بخش‌های چندنفره بازی.
- `373bfcf` **2026-04-23** — رفع مشکل گیر کردن بازیکنان در صفحه انتظار و بهبود سرعت ورود به بازی.
- `05072a2` **2026-04-23** — Updated project settings
- `1d145e0` **2026-04-23** — New version from Rork
- `cc4a2cc` **2026-04-23** — رفع مشکل ورود میزبان به بازی و بازطراحی صفحه انتظار
- `0190118` **2026-04-23** — New version from Rork
- `71a8727` **2026-04-23** — رفع مشکلات سرعت و هماهنگی در بازی چندنفره و بهبود تجربه ورود مهمان‌ها به بازی.
- `17270c1` **2026-04-23** — رفع مشکل ایجاد اتاق در بازی چندنفره
- `7c2fcb6` **2026-04-23** — بروزرسانی وضعیت اتصال بازیکنان و بهبود سیستم بازی مجدد
- `a3df8ea` **2026-04-23** — رفع مشکلات اجرای بازی چندنفره و بهبود اتصال بازیکنان
- `adf366a` **2026-04-23** — New version from Rork
- `a9ce774` **2026-04-23** — New version from Rork
- `35e0d5b` **2026-04-23** — New version from Rork
- `fcb5d3d` **2026-04-23** — تغییر نام برنامه به 8partyplay
- `9a709d3` **2026-04-23** — Update app for App Store safety and compliance
- `afe5fe4` **2026-04-23** — تغییر نام برنامه به 8PartyPlay در همه قسمت‌ها
- `bc41a32` **2026-04-23** — Updated project settings
- `eca6234` **2026-04-23** — Updated project settings
- `d9d59b8` **2026-04-23** — تغییر نام برنامه به 8PartyPlay در تمامی بخش‌ها
- `8c45ae2` **2026-04-23** — New version from Rork
- `a227942` **2026-04-23** — New version from Rork
- `a01f2ac` **2026-04-23** — نام برنامه و وب‌سایت در تمامی بخش‌ها به 8PartyPlay تغییر یافت.
- `104ad75` **2026-04-23** — بررسی و اصلاح دسترسی‌های برنامه برای انطباق با قوانین اپ استور
- `e005580` **2026-04-23** — New version from Rork
- `693a500` **2026-04-23** — حذف کامل دسته‌بندی ۱۸+ و محتوای بزرگسال از برنامه.
- `06c251f` **2026-04-23** — تغییر تمامی اعداد ۸۸۸ به ۸ در تمام بخش‌های برنامه و وب‌سایت.
- `be92fc5` **2026-04-23** — به‌روزرسانی لوگوی اپلیکیشن و وب‌سایت به طرح جدید ۸PartyPlay
- `601c01f` **2026-04-23** — به‌روزرسانی تصاویر بطری و سکه در بازی‌ها و ابزارهای برنامه
- `0df8f8d` **2026-04-23** — تغییر ظاهر بطری و سکه در بازی‌ها
- `9f65110` **2026-04-23** — Be-rozresani axhaye bazi va moratab kardan liste bazi-ha
- `8be7ee7` **2026-04-23** — به‌روزرسانی تصاویر شیر و خط در بازی
- `1e1a4e9` **2026-04-23** — به‌روزرسانی لوگو در وب‌سایت و اپلیکیشن
- `bbc14ec` **2026-04-23** — بازطراحی وب‌سایت و به‌روزرسانی تصاویر ابزارها
- `53d3d90` **2026-04-23** — Updated project settings
- `9483908` **2026-04-23** — به‌روزرسانی قوانین و حریم خصوصی
- `a2242aa` **2026-04-23** — به‌روزرسانی قوانین و سیاست حریم خصوصی برای هماهنگی با قوانین اپل
- `f2aa09a` **2026-04-24** — ایجاد راهنمای کامل برای بازسازی برنامه و به‌روزرسانی سیستم فنی آن
- `e13d9ab` **2026-04-24** — ساخت پرامپت‌های جامع برای بازسازی و توضیح کامل بخش‌های مختلف اپلیکیشن
- `c2b009b` **2026-04-24** — Sakhte prompte kamel baraye UI/UX va joziyate safehaye barname.
- `bd0fde2` **2026-04-24** — Tozihate kamel va joziyate tamame baziha ezafe shod
- `be18ed5` **2026-04-24** — New version from Rork
- `a59bca2` **2026-04-24** — New version from Rork
- `2fcca4a` **2026-04-24** — تکمیل و اصلاح دستورالعمل‌های بازسازی کامل اپلیکیشن
- `7063350` **2026-04-24** — مرتب‌سازی و تکمیل فایل‌های راهنمای ساخت مجدد اپلیکیشن.
- `559cd0c` **2026-04-24** — به‌روزرسانی و تکمیل دستورالعمل‌های بازسازی برنامه برای اندروید، وب و آیفون.
- `68b4f83` **2026-04-24** — New version from Rork
- `c42b172` **2026-04-24** — New version from Rork
- `a93b72c` **2026-04-24** — تکمیل و سازماندهی مستندات طراحی و رابط کاربری برنامه
- `d69eb88` **2026-04-25** — Delete prompts directory
- `8e507aa` **2026-04-25** — سازمان‌دهی و نام‌گذاری تصاویر صفحات مختلف اپلیکیشن.
- `01f1466` **2026-04-25** — New version from Rork
- `678e7c6` **2026-04-25** — پاکسازی فایل‌های اضافی و کدهای بلااستفاده برنامه.