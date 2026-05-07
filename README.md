# IPTV for Stremio (Selective Regions + Working Channels)

This project is a lightweight IPTV-org style setup focused on:

- Keeping only selected regions
- Testing stream URLs and marking only working channels
- Building `.m3u` playlists you can use in Stremio or other players

## Project Structure

- `.github/workflows/validate-streams.yml`: Optional GitHub Actions validation run
- `channels/channels.csv`: Main source list of channels and stream URLs
- `playlists/`: Generated playlists by region and `all.m3u`
- `reports/`: Validation outputs (generated)
- `scripts/Build-Playlists.ps1`: Builds playlists from source data
- `scripts/Test-StreamLinks.ps1`: Tests stream URLs and writes validation reports

## 1) Add Your Regions and Channels

Edit `channels/channels.csv`.

Important columns:

- `region`: Country/region code like `IN`, `US`, `GB`
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
pwsh -File ./scripts/Test-StreamLinks.ps1 -Regions US,UK -TimeoutSec 10
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
pwsh -File ./scripts/Build-Playlists.ps1 -Regions US,UK
```

Generated files:

- `playlists/all.m3u`
- `playlists/IN.m3u`, `playlists/US.m3u`, etc.

Build logic keeps one primary stream per channel identity (prefers `tvg_id`, otherwise `region+name`) so backup URLs do not create duplicate playlist entries.

## 4) Use in Stremio

Use hosted raw playlist URLs (for example from GitHub raw content) in your Stremio IPTV addon configuration.

Typical URL shape after pushing to GitHub:

```text
https://raw.githubusercontent.com/<your-user>/<your-repo>/main/playlists/all.m3u
```

Or region-specific:

```text
https://raw.githubusercontent.com/<your-user>/<your-repo>/main/playlists/IN.m3u
```

## Suggested Workflow

1. Add or update channel URLs in `channels/channels.csv`
2. Run link validation script
3. Review report and keep only valid entries
4. Build playlists
5. Commit and push to GitHub

## Notes

- Some streams block bots or require specific headers. Those may fail automated checks even if they work in a media player.
- Revalidate regularly because IPTV links expire often.
