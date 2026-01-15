# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Scrobbit is an iOS app that automatically scrobbles tracks played on Apple Music to Last.fm. It uses SwiftUI, SwiftData for persistence, and integrates with both MusicKit/MediaPlayer and the Last.fm API.

## Build Commands

```bash
# Build
xcodebuild build -scheme Scrobbit

# Run tests
xcodebuild test -scheme Scrobbit

# Build for release
xcodebuild build -scheme Scrobbit -configuration Release
```

## Setup

1. Copy `Debug.xcconfig.template` to `Debug.xcconfig`
2. Get API credentials from https://www.last.fm/api/account/create
3. Fill in `LASTFM_API_KEY` and `LASTFM_API_SECRET` in `Debug.xcconfig`
4. Open `Scrobbit.xcodeproj` in Xcode and run on iOS 17+ device

## Architecture

### Service Layer (`Scrobbit/Services/`)
- **ScrobbleService**: Orchestrates the scrobbling workflow - compares MediaPlayer library play counts with `LibraryCache` to detect new plays, sends batches to Last.fm
- **LastFmService**: Last.fm API client with OAuth2 auth (`ASWebAuthenticationSession`), MD5 signatures, batch scrobbling (max 50 per request)
- **MusicKitService**: Apple Music authorization and library scanning via `MPMediaQuery.songs()` on background thread
- **BackgroundTaskManager**: iOS background app refresh with 30-minute intervals
- **KeychainService**: Secure credential storage

### Data Models (`Scrobbit/Models/`)
- **Track** (@Model): SwiftData entity for scrobble history, uniquely identified by `scrobbleID` format `{artist}-{track}-{timestamp}`
- **LibraryCache** (@Model): Persistent cache of MediaPlayer library with play counts - delta detection identifies new plays
- **MediaPlayerItem**: Transient model for library scanning with lazy artwork loading
- **DisplayableTrack**: Protocol for uniform rendering of different track types

### Data Flow
```
MediaPlayer library → LibraryCache (comparison) → ScrobbleService (detects new plays)
    → LastFmService (batch scrobble) → Last.fm API
    → LastFmService (fetch recent) → Track (history cache) → Views
```

### Key Patterns
- **First sync**: Establishes baseline without retroactively scrobbling old plays
- **Timestamp estimation**: For multiple plays, works backward from `lastPlayedDate` using track duration
- **Background thread**: MediaPlayer queries run on `userInitiated` dispatch queue
- **Upsert**: Updates existing Track entries with latest artwork from Last.fm

### Views (`Scrobbit/Views/`)
MainTabView with three tabs: HomeView (stats + recent tracks), HistoryView (SwiftData @Query), SettingsView (account management)

### Theme (`Scrobbit/Theme/Theme.swift`)
Centralized design tokens for colors, spacing, corner radius, and animations. Use `Theme.Colors`, `Theme.Spacing`, etc.

## iOS Requirements
- Minimum iOS 17 (SwiftUI, SwiftData, @Observable)
- iOS 18+ for native Tab API (fallback provided)
- MusicKit entitlement required
