# IPTV Playlists

Curated, validated IPTV playlists for Stremio and other IPTV players.

- **All regions playlist:** 93 working streams
- **US:** 64 popular working channels
- **UK:** 16 popular working channels
- **Pakistan:** 13 popular working channels

Last full playlist validation: **93/93 streams working**.

## Playlist URLs

Use these raw GitHub URLs in Stremio, IPTV Smarters, VLC, TiviMate, or any player that accepts an M3U URL.

```text
https://raw.githubusercontent.com/vipins5/iptv-playlists/main/playlists/all.m3u
```

Region-specific playlists:

```text
https://raw.githubusercontent.com/vipins5/iptv-playlists/main/playlists/US.m3u
https://raw.githubusercontent.com/vipins5/iptv-playlists/main/playlists/UK.m3u
https://raw.githubusercontent.com/vipins5/iptv-playlists/main/playlists/PK.m3u
```

Category playlists:

```text
https://raw.githubusercontent.com/vipins5/iptv-playlists/main/playlists/categories/News.m3u
https://raw.githubusercontent.com/vipins5/iptv-playlists/main/playlists/categories/Movies.m3u
https://raw.githubusercontent.com/vipins5/iptv-playlists/main/playlists/categories/Entertainment.m3u
https://raw.githubusercontent.com/vipins5/iptv-playlists/main/playlists/categories/Sports.m3u
https://raw.githubusercontent.com/vipins5/iptv-playlists/main/playlists/categories/Documentary.m3u
https://raw.githubusercontent.com/vipins5/iptv-playlists/main/playlists/categories/Music.m3u
https://raw.githubusercontent.com/vipins5/iptv-playlists/main/playlists/categories/Lifestyle.m3u
https://raw.githubusercontent.com/vipins5/iptv-playlists/main/playlists/categories/Other.m3u
```

Repository:

```text
https://github.com/vipins5/iptv-playlists
```

Landing page, after enabling GitHub Pages for this repo:

```text
https://vipins5.github.io/iptv-playlists/
```

## Project Structure

- `.github/workflows/validate-streams.yml`: Optional GitHub Actions validation run
- `channels/channels.csv`: Main source list of channels and stream URLs
- `index.html`: Static landing page for GitHub Pages
- `playlists/`: Generated playlists by region and `all.m3u`
- `reports/`: Validation outputs (generated)
- `scripts/Import-M3uSources.ps1`: Imports public M3U sources and probes streams before adding them
- `scripts/Build-Playlists.ps1`: Builds playlists from source data
- `scripts/Test-StreamLinks.ps1`: Tests stream URLs and writes validation reports

## 1) Add Your Regions and Channels

Edit `channels/channels.csv`.

Important columns:

- `region`: Country/region code like `US`, `UK`, `PK`
- `stream_url`: Direct stream URL (`.m3u8`, MPEG-TS, etc.)
- `enabled`: `true` or `false` (manual include/exclude)
- `last_checked_ok`: `true` or `false` (set by validator)

Only records where both `enabled=true` and `last_checked_ok=true` are exported to playlists.

## 2) Validate Stream Links Locally (PowerShell)

From project root:

```powershell
pwsh -File ./scripts/Test-StreamLinks.ps1
```

Optional filters:

```powershell
pwsh -File ./scripts/Test-StreamLinks.ps1 -Regions US,UK,PK -TimeoutSec 5
```

Output files:

- `reports/stream-check-report.csv`
- `reports/stream-check-report.json`

The script also updates `channels/channels.csv` by writing:

- `last_checked_ok`
- `last_checked_at_utc`
- `last_status`
- `last_error`

## 3) Build Playlists

```powershell
pwsh -File ./scripts/Build-Playlists.ps1
```

For selected regions only:

```powershell
pwsh -File ./scripts/Build-Playlists.ps1 -Regions US,UK,PK
```

Generated files:

- `playlists/all.m3u`
- `playlists/US.m3u`
- `playlists/UK.m3u`
- `playlists/PK.m3u`
- `playlists/categories/*.m3u`

Build logic keeps one primary stream per channel identity (prefers `tvg_id`, otherwise `region+name`) so backup URLs do not create duplicate playlist entries.

## 4) Use in Stremio or IPTV Players

Use this URL for the complete playlist:

```text
https://raw.githubusercontent.com/vipins5/iptv-playlists/main/playlists/all.m3u
```

Or use a region-specific URL:

```text
https://raw.githubusercontent.com/vipins5/iptv-playlists/main/playlists/US.m3u
https://raw.githubusercontent.com/vipins5/iptv-playlists/main/playlists/UK.m3u
https://raw.githubusercontent.com/vipins5/iptv-playlists/main/playlists/PK.m3u
```

Or use a category URL:

```text
https://raw.githubusercontent.com/vipins5/iptv-playlists/main/playlists/categories/News.m3u
https://raw.githubusercontent.com/vipins5/iptv-playlists/main/playlists/categories/Movies.m3u
https://raw.githubusercontent.com/vipins5/iptv-playlists/main/playlists/categories/Entertainment.m3u
```

## 5) Enable the Landing Page

The repo includes `index.html` for GitHub Pages.

To publish it:

1. Open the repository on GitHub.
2. Go to **Settings** > **Pages**.
3. Under **Build and deployment**, choose **Deploy from a branch**.
4. Select branch **main** and folder **/ (root)**.
5. Save.

The landing page will be available at:

```text
https://vipins5.github.io/iptv-playlists/
```

## Suggested Workflow

1. Add or update channel URLs in `channels/channels.csv`
2. Run link validation script
3. Review report and keep only valid entries
4. Build playlists
5. Test the generated playlist URLs
6. Commit and push to GitHub

Useful commands:

```powershell
pwsh -File ./scripts/Test-StreamLinks.ps1 -Regions US,UK,PK -TimeoutSec 5
pwsh -File ./scripts/Build-Playlists.ps1 -Regions US,UK,PK
git add .
git commit -m "Update playlists"
git push
```

## Notes

- Some streams block bots or require specific headers. Those may fail automated checks even if they work in a media player.
- Revalidate regularly because IPTV links expire often.
- US, UK, and Pakistan playlists are intentionally trimmed to popular/recognizable channels instead of keeping every available FAST stream.
- Religious, shopping, duplicate, and non-direct YouTube page URLs are disabled from generated playlists.
