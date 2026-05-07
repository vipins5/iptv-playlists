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

function Get-CategoryName {
    param([object]$Channel)

    $group = "$($Channel.group_title)".Trim()
    $name = "$($Channel.name)".Trim()
    $haystack = "$group $name".ToLowerInvariant()

    if ($haystack -match "news|weather|business|bloomberg|cnbc|court") { return "News" }
    if ($haystack -match "movie|movies|cinema|film") { return "Movies" }
    if ($haystack -match "sport|nfl|nba|tennis|golf|bein|acc") { return "Sports" }
    if ($haystack -match "kid|kids|cartoon|animation") { return "Kids" }
    if ($haystack -match "documentary|science|history|learning|education|nature|outdoor|culture") { return "Documentary" }
    if ($haystack -match "music|radio") { return "Music" }
    if ($haystack -match "relig|faith|christian|church|tbn") { return "Religious" }
    if ($haystack -match "shop|shopping|qvc|hsn") { return "Shopping" }
    if ($haystack -match "travel|lifestyle|food|home|design|auto") { return "Lifestyle" }
    if ($haystack -match "entertainment|series|comedy|classic|reality|daytime|general|usa|uk") { return "Entertainment" }

    return "Other"
}

function Get-FileSafeName {
    param([string]$Value)

    $safe = "$Value".Trim() -replace "[^A-Za-z0-9_-]+", "-" -replace "^-+|-+$", ""
    if ([string]::IsNullOrWhiteSpace($safe)) {
        return "Other"
    }
    return $safe
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

$categoryDir = Join-Path $OutputDir "categories"
New-Item -ItemType Directory -Path $categoryDir -Force | Out-Null
Get-ChildItem -Path $categoryDir -Filter "*.m3u" -File | Remove-Item -Force

$categoryItems = foreach ($c in $allSorted) {
    [PSCustomObject]@{
        category = Get-CategoryName -Channel $c
        channel  = $c
    }
}

$categoriesPresent = $categoryItems | Group-Object -Property category
foreach ($grp in $categoriesPresent) {
    $categoryName = "$($grp.Name)".Trim()
    if ([string]::IsNullOrWhiteSpace($categoryName)) {
        continue
    }

    $categoryPath = Join-Path $categoryDir ("{0}.m3u" -f (Get-FileSafeName -Value $categoryName))
    $items = $grp.Group | ForEach-Object { $_.channel } | Sort-Object region, name
    New-M3uContent -Items $items | Out-File -FilePath $categoryPath -Encoding utf8
}

Write-Host "Playlists generated in: $OutputDir"
Write-Host "All channels file: $allPath"
Write-Host "Channel count: $($allSorted.Count)"
Write-Host "Category playlists: $categoryDir"
