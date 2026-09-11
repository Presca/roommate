# roommate 🌙

A tiny iOS app with one job: at bedtime, your sleepy roommate walks onto your
screen and asks you to turn the phone off. Ignore her and she comes back
fifteen minutes later, grumpier. Let her sleep and she's happy in the morning.

She has a **happiness** bar and a **frustration** bar you can check in the app.
Every night you keep the screen on past bedtime nudges frustration up; every
quiet night brings happiness up and frustration down.

Built on Apple's **Screen Time API** (Family Controls, ManagedSettings,
DeviceActivity). Everything stays on your phone.

## What actually happens at night

| when | what you see |
|---|---|
| lights-off time (default 11:00 pm) | Whatever app you're in gets covered by her lock screen: sleepy pose, *"it's 11:00 pm... your phone screen is too bright, it's disturbing my sleep. can you please turn it off? thanks..."*, two buttons. A notification arrives too – tap it and the app plays the full animated version (she walks in, types it out, sulks, walks off). |
| **okay, goodnight 🌙** | The app you were in closes. Happiness +10. She's asleep now – if you open a blocked app again you get a *"shh... she's asleep"* screen instead. |
| **15 more minutes...** | The lock lifts. Frustration +15, happiness −5. Apple counts your usage of the apps you picked; after 15 more minutes she's back with the frustrated pose: *"please, I'm trying to sleep. you should too..."* After 30 she's fuming: *"...you're still on it. I'm not asking again. lights off. now."* And so on, every 15 min, for up to 2 hours. |
| wake time (default 7:00 am) | Everything unlocks. The night is tallied: a peaceful night is +15 happiness / −25 frustration. It's added to "recent nights" in the app. |

The home screen shows her sitting with her book: **happy** (♡), **neutral**
("...") or **annoyed** (💢) depending on the bars.

## Try it in a browser first (no Xcode at all)

`web/index.html` is the whole demo as one web page: open it on your phone
or laptop, or serve the folder with `python3 -m http.server`. It has the
same mood logic, the animated visit, a ⚡ fast mode (she comes back every
20 seconds instead of 15 minutes), a "make it bedtime now" button, and a
slot to drop in the two character sheets and the font. Everything is kept
in the browser's local storage.

## Trying it without a paid developer account (demo)

Family Controls can't be signed by a free "Personal Team", so the repo has a
second target, **RoommateDemo**, with the same app and none of the Screen
Time parts. She can't block apps in it. Instead:

- at lights-off you get a notification from her (sleepy pose);
- 15 and 30 minutes later, two more, grumpier, unless you said goodnight;
- tapping a notification, or opening the app during bedtime, plays the
  animated visit; the buttons in it update her happiness / frustration and
  the night log, and "not yet..." pushes the follow-ups 15 minutes out.

Setup is the same as below except you can skip the team / entitlement
steps: run `./bootstrap.sh`, pick the **RoommateDemo** scheme at the top of
Xcode, choose your iPhone, and press ▶. With a free account Xcode asks you
to add your Apple ID under *Settings ▸ Accounts* and to trust the
certificate on the phone (*Settings ▸ General ▸ VPN & Device Management*).
Free builds stop launching after 7 days – just press ▶ again.

The demo runs in the Simulator too, which is handy for the animation.

## What you need

- An iPhone on **iOS 16 or newer**. The Screen Time API does not work in the
  Simulator – you have to run on a real phone.
- A Mac with **Xcode 15+**.
- For the real thing (blocking apps): a **paid Apple Developer account**
  ($99/yr). Family Controls is not available to free "Personal Team"
  accounts. For your own phone the *development* entitlement is enough – no
  need to apply to Apple for the distribution one. For the **demo** target a
  free account is fine.
- Python 3 + Pillow, only to slice the character sheets (`pip3 install pillow`).

## Setup

```bash
git clone https://github.com/Presca/roommate
cd roommate

# 1. artwork – put your two character sheets here, then slice them into poses
cp ~/Downloads/standing-sheet.png Artwork/standing.png
cp ~/Downloads/sitting-sheet.png  Artwork/sitting.png
pip3 install pillow
python3 Scripts/slice_sheets.py Artwork/standing.png Artwork/sitting.png

# 2. font (optional) – drop your Cute Planner .ttf/.otf in here
cp ~/Downloads/CutePlanner.ttf Roommate/Resources/Fonts/

# 3. generate the Xcode project (installs XcodeGen via Homebrew if needed)
TEAM_ID=ABCDE12345 ./bootstrap.sh      # or just ./bootstrap.sh and pick the team in Xcode
```

Then in Xcode:

1. Select the **Roommate** target ▸ *Signing & Capabilities* ▸ choose your
   team. Do the same for the three extension targets (MonitorExtension,
   ShieldConfigurationExtension, ShieldActionExtension). Xcode will register
   the App Group and Family Controls capability for you.
2. If the bundle id `com.presca.roommate` is taken on your team, change
   `bundleIdPrefix` / the four `PRODUCT_BUNDLE_IDENTIFIER`s **and** the
   `group.com.presca.roommate` App Group in `project.yml`, plus
   `RoommateConfig.appGroup` in `Shared/RoommateShared.swift`, then re-run
   `./bootstrap.sh`.
3. Plug in your iPhone, pick it as the run destination, press ▶.

On the phone:

1. Open *settings* (⚙️) ▸ turn on **she watches my bedtime**. iOS asks for
   Screen Time access and notifications – allow both.
2. Tap **apps that keep you up** and pick the apps (or whole categories like
   *Social*) that she should guard. She needs at least one – that's how she
   knows you're still on the phone after she asked you to stop.
3. Optionally flip **she blocks every app, not just those**.
4. Set your lights-off and wake times. Done. Use **preview her visit** on the
   home screen to watch the animation any time.

## Things Apple won't let us do (so here's what we do instead)

- **The lock screen can't animate.** Apple's shield is a fixed layout: one
  image, a title, a subtitle, two buttons, our colours. So the pose and the
  words change with her mood, but the walk-in / typewriter / walk-out
  animation lives in the app. The bedtime notification opens straight into it,
  and opening the app during bedtime plays it too.
- **The lock screen can't use a custom font.** Only the app can.
- **iOS can't tell us when you lock the phone.** "Turning it off" is the
  *okay, goodnight* button. "Ignoring her" is *15 more minutes*, after which
  Apple measures use of the apps you picked and wakes her up again at 15-minute
  marks.
- **The shield needs a moment.** After *15 more minutes* iOS sometimes keeps
  the blocked app's screen dimmed until you switch apps once. Normal.
- Screen Time schedules are handled by iOS itself, so she works even if the
  app is closed – but the first night after enabling, if it's already past
  lights-off, the app puts her out immediately rather than waiting for iOS.

## Tweaking her

- Lines: `Shared/RoommateShared.swift` ▸ `RoommateLines`.
- Mood maths: `MoodStore.complied() / snoozed() / escalate() / nightEnded()`
  in the same file.
- How often she comes back: `RoommateConfig.escalationMinutes` (15) and
  `escalationSteps` (8).
- Colours: `Roommate/Theme.swift`.
- Poses: the imageset names in `Shared/Character.xcassets`. The slicer
  expects the standing sheet in the order *peek · talk · frustrated · walk*
  and the sitting sheet in *happy · neutral · annoyed*.

## Layout

```
web/index.html                   browser demo of the whole thing, single file
project.yml                      XcodeGen spec (app, demo app, 3 extensions)
bootstrap.sh                     installs xcodegen, generates Roommate.xcodeproj
Scripts/slice_sheets.py          character sheets → transparent poses → asset catalog
Artwork/                         your two sheets go here (git-ignored)
Shared/                          code + artwork compiled into the app AND the extensions
  RoommateShared.swift           config, Stage, lines, MoodStore (App Group), Shielding
  RoommateNotifier.swift         the "she's awake" notifications
  Character.xcassets             her 7 poses
Roommate/                        the app
  RoommateApp.swift              entry, notification tap handling, deep link roommate://visit
  RoommateModel.swift            observable state for SwiftUI
  ScreenTimeManager.swift        authorization + DeviceActivity schedule/events;
                                 DemoScheduler (notifications) when built with -DDEMO
  Theme.swift                    colours, font loader (Cute Planner or SF Rounded)
  Views/                         HomeView, SettingsView, VisitSceneView (the animation),
                                 TypewriterText + SpeechBubble, MoodBar, CharacterImage
  Resources/Fonts/               drop the font here
MonitorExtension/                iOS wakes this at bedtime / wake / every 15 min of use
ShieldConfigurationExtension/    what her lock screen looks like
ShieldActionExtension/           what the two buttons do
```
