param(
    [string[]]$Regions,
    [string]$InputCsv = "channels/channels.csv",
    [string]$OutputDir = "playlists"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $InputCsv)) {
    throw "Input file not found: $InputCsv"
}

$channels = Import-Csv -Path $InputCsv

$filtered = $channels | Where-Object {
    ($_.enabled -eq "true") -and ($_.last_checked_ok -eq "true") -and -not [string]::IsNullOrWhiteSpace($_.stream_url)
}

function Get-DedupeKey {
    param([object]$Channel)

    $tvgId = "$($Channel.tvg_id)".Trim().ToUpperInvariant()
    if (-not [string]::IsNullOrWhiteSpace($tvgId)) {
        return "TVG:$tvgId"
    }

    $region = "$($Channel.region)".Trim().ToUpperInvariant()
    $name = ("$($Channel.name)".Trim() -replace "\s+", " ").ToUpperInvariant()
    return "NAME:$region|$name"
}

if ($Regions -and $Regions.Count -gt 0) {
    $normalizedRegions = @()
    foreach ($r in $Regions) {
        $normalizedRegions += ($r -split ",")
    }

    $regionSet = @{}
    foreach ($r in $normalizedRegions) {
        $regionKey = "$r".Trim().ToUpperInvariant()
        if (-not [string]::IsNullOrWhiteSpace($regionKey)) {
            $regionSet[$regionKey] = $true
        }
    }

    $filtered = $filtered | Where-Object {
        $region = "$($_.region)".Trim().ToUpperInvariant()
        $regionSet.ContainsKey($region)
    }
}

# Keep one primary stream per channel identity (tvg_id preferred, then region+name).
$filtered = $filtered | Sort-Object `
    @{ Expression = {
            $status = "$($_.last_status)".Trim()
            if ($status -eq "206") { 0 }
            elseif ($status -eq "200") { 1 }
            else { 2 }
        }
    }, `
    @{ Expression = {
            $parsed = [DateTime]::MinValue
            [DateTime]::TryParse("$($_.last_checked_at_utc)", [ref]$parsed) | Out-Null
            $parsed
        }; Descending = $true
    }, `
    @{ Expression = { "$($_.name)".Trim().ToUpperInvariant() } }

$seen = @{}
$deduped = New-Object System.Collections.Generic.List[Object]
foreach ($c in $filtered) {
    $key = Get-DedupeKey -Channel $c
    if (-not $seen.ContainsKey($key)) {
        $seen[$key] = $true
        $deduped.Add($c) | Out-Null
    }
}

$filtered = $deduped

New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

function New-M3uContent {
    param([object[]]$Items)

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("#EXTM3U") | Out-Null

    foreach ($c in $Items) {
        $tvgId = "$($c.tvg_id)".Trim()
        $tvgLogo = "$($c.tvg_logo)".Trim()
        $groupTitle = "$($c.group_title)".Trim()
        $name = "$($c.name)".Trim()
        $url = "$($c.stream_url)".Trim()

        $lines.Add("#EXTINF:-1 tvg-id=`"$tvgId`" tvg-logo=`"$tvgLogo`" group-title=`"$groupTitle`",$name") | Out-Null
        $lines.Add($url) | Out-Null
    }

    return $lines
}

$allSorted = $filtered | Sort-Object region, name
$allPath = Join-Path $OutputDir "all.m3u"
New-M3uContent -Items $allSorted | Out-File -FilePath $allPath -Encoding utf8

$regionsPresent = $allSorted | Group-Object -Property region
foreach ($grp in $regionsPresent) {
    $regionCode = "$($grp.Name)".Trim().ToUpperInvariant()
    if ([string]::IsNullOrWhiteSpace($regionCode)) {
        continue
    }

    $regionPath = Join-Path $OutputDir ("{0}.m3u" -f $regionCode)
    $items = $grp.Group | Sort-Object name
    New-M3uContent -Items $items | Out-File -FilePath $regionPath -Encoding utf8
}

Write-Host "Playlists generated in: $OutputDir"
Write-Host "All channels file: $allPath"
Write-Host "Channel count: $($allSorted.Count)"
