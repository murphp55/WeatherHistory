# WeatherHistory — Agent Notes

## One-liner
Flutter (Dart) desktop/mobile app showing current weather plus same-date data from the prior 5 years via the Open-Meteo API.

## Run it
```
cd weatherhistory
flutter pub get
flutter run -d windows
flutter test
```

## Where we are right now
- Last touched: 2026-01-20
- Working on: Dormant — single initial commit, MVP complete.
- Known broken: Nothing known.

*This section goes stale fast. Check `git log -5` and `git status` before trusting it.*

## Gotchas
- All app code lives in `weatherhistory/lib/main.dart` (~700 lines). Models, service, and UI are colocated — search there before assuming files are missing.
- The Flutter project root is `weatherhistory/`, not the repo root. Run `flutter` commands from inside that subdirectory.
- Six API calls fire per refresh (1 current + 5 historical via `Future.wait`); no caching layer exists.
- Open-Meteo archive API may return empty/null for very recent dates — UI renders "— " placeholders rather than erroring.

## Non-obvious conventions
- Zero external pub packages beyond `cupertino_icons` and `flutter_lints`; uses Dart stdlib (`http`/`convert`) only. Resist adding deps for small features.
- Cities are hardcoded in `_cityOptions` inside `_WeatherHistoryPageState` — edit that list to add locations.
- Units pinned to imperial (fahrenheit, mph, inch) via query string params.

See README.md for project description, tech stack, and feature list.
