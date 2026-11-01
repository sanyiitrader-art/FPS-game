# Testing

A green build means the project compiled. It does not mean the game works. Only real
phones show that. GitHub Actions already checks scripts for syntax errors and runs logic
tests, but touch input, networking, sound, performance and layout can only be judged on
devices.

## How to report problems

For every problem, send me:

1. Phone model and Android version
2. Which APK you installed (arm64, arm32 or universal)
3. What you did, what you expected, what happened
4. A screenshot or short screen recording if it is a visual problem
5. For build failures: the red error lines from the failed workflow step

## Device record

Keep a small table of every device you test on. Results differ a lot between phones.

| Device | Android | RAM | APK | Notes |
|---|---|---|---|---|
| | | | | |

Try at least one older or cheaper phone, and at least two different brands once
multiplayer arrives.

## Phase 1 checklist: foundation and menus

What this phase contains: install, loading screen, main menu, name editing, settings,
sounds. MULTIPLAYER shows a "not available yet" message until Phase 2.

**Install and launch**
- [ ] APK installs. If it refuses to update, uninstall the old build first (see BUILD.md).
- [ ] App is named **Quiet Front** and shows the icon made from your `icon.png`
- [ ] The icon looks right on your launcher (adaptive icons can be cropped to a circle or
      squircle; the artwork should not be cut off)
- [ ] The game opens in landscape and stays landscape when you rotate the phone
- [ ] No permission prompts appear

**Loading screen**
- [ ] A dark scene with military figures appears (simple placeholder figures until real
      models are added in a later phase)
- [ ] A loading animation runs near the bottom
- [ ] The main menu opens by itself and the screen does not stay on loading longer than
      needed
- [ ] Soft background music plays only if a music file has been added; silence is expected
      before that

**Main menu**
- [ ] Buttons: PLAY, MULTIPLAYER, SETTINGS, SHOP, AVATAR
- [ ] PLAY looks disabled and does nothing
- [ ] SHOP shows "coming soon"
- [ ] MULTIPLAYER shows a message that LAN play arrives in the next build
- [ ] A 3D figure stands on one side with a gentle idle movement
- [ ] Buttons respond to a touch every time and make a soft click sound
- [ ] Screen changes take a fraction of a second and never feel slow

**Avatar (player name)**
- [ ] The default name looks like `OPERATOR-123`
- [ ] You can change the name with the on-screen keyboard
- [ ] Names longer than 16 characters are cut off
- [ ] An empty name is not accepted
- [ ] Close the app completely and reopen it: the new name is still there

**Settings**
- [ ] Music toggle and sound effects toggle work separately
- [ ] Graphics quality can be set to LOW, MEDIUM and HIGH
- [ ] Camera sensitivity and aim sensitivity sliders move smoothly
- [ ] Vibration toggle: turning it on gives a short buzz when you tap its toggle
- [ ] Crosshair shape (+, O, square) and size sliders show a live preview
- [ ] Close and fully restart the app: every setting is remembered

Graphics quality, sensitivity and crosshair affect the game itself only once matches exist
(Phase 3 onward). In this phase check that the choices are saved and the crosshair preview
reacts.

**Layout and navigation**
- [ ] Nothing is cut off by a notch, rounded corners or the navigation bar
- [ ] Text is readable and buttons are easy to hit with a thumb
- [ ] The Android back button goes back one screen; on the main menu it asks whether to quit
- [ ] Home button and returning to the game works; the app does not restart
- [ ] The app feels smooth while idle; the phone does not get hot on the menu

## Later phases (outline, detailed lists come with each phase)

**Phase 2:** hosting, hotspot popup, discovery on different phones and hotspots, joining,
lobby sync, ready system, countdown cancel rules, customization, map selection, team
assignment, disconnects.

**Phase 3:** movement, camera drag, shooting, joystick and multi-touch, deaths, respawn,
other players visible, name tags, performance with several phones.

**Phase 4:** weapons, reloads, switching, pickups, drops, bombs, sticky bombs, health
pickups, settings overlay during a match, scoreboards, match end, return to lobby.

**Phase 5:** both maps, final art and sound, low graphics mode, long sessions, 20-player
stress test, heat and battery.

## What CI already checks for you

- Every script parses without errors
- Logic tests: ready and countdown rules, team start rules, ammo handling, scoring, packet
  encoding (more are added as the code grows)
- Required files exist, `icon.png` is valid, JSON files parse, asset licenses are listed

## What only a real device can show

Touch feel, frame rate, sound, heat, battery, hotspot behavior, discovery, latency,
packet loss and memory use. Please do not assume any of these work until you have tested
them.