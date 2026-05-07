param(
    [string[]]$SourceUrls = @(
        "https://apsattv.com/ssungusa.m3u",
        "https://www.apsattv.com/rok.m3u",
        "https://www.apsattv.com/lg.m3u",
        "https://www.apsattv.com/vizio.m3u",
        "https://www.apsattv.com/redbox.m3u",
        "https://www.apsattv.com/distro.m3u",
        "https://www.apsattv.com/xiaomi.m3u",
        "https://www.apsattv.com/xumo.m3u",
        "https://www.apsattv.com/localnow.m3u",
        "https://raw.githubusercontent.com/Free-TV/IPTV/master/playlist.m3u8",
        "https://tvpass.org/playlist/m3u",
        "https://iptv-org.github.io/iptv/categories/news.m3u",
        "https://iptv-org.github.io/iptv/countries/us.m3u",
        "https://iptv-org.github.io/iptv/countries/uk.m3u"
    ),
    [int]$TimeoutSec = 10,
    [string]$InputCsv = "channels/channels.csv"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $InputCsv)) {
    throw "Missing CSV: $InputCsv"
}

function Normalize-Region {
    param([string]$Raw)

    $value = "$Raw".Trim().ToUpperInvariant()
    if ($value -in @("US", "USA", "UNITED STATES", "UNITED STATES OF AMERICA")) { return "US" }
    if ($value -in @("UK", "GB", "GBR", "UNITED KINGDOM")) { return "UK" }
    return $null
}

function Parse-Attributes {
    param([string]$Extinf)

    $map = @{}
    [regex]::Matches($Extinf, '([a-zA-Z0-9_-]+)="([^"]*)"') | ForEach-Object {
        $map[$_.Groups[1].Value.ToLowerInvariant()] = $_.Groups[2].Value
    }

    $name = ""
    if ($Extinf -match ',\s*(.*)$') {
        $name = $matches[1].Trim()
    }

    $map["name"] = $name
    return $map
}

function Resolve-Region {
    param(
        [hashtable]$Meta,
        [string]$SourceUrl,
        [string]$ChannelName
    )

    $countryRaw = "$($Meta["tvg-country"])"
    if (-not [string]::IsNullOrWhiteSpace($countryRaw)) {
        foreach ($part in ($countryRaw -split '[|,;/]')) {
            $region = Normalize-Region -Raw $part
            if ($region) { return $region }
        }
    }

    $tvgId = "$($Meta["tvg-id"])".Trim().ToLowerInvariant()
    if ($tvgId -match '\.us($|@)') { return "US" }
    if ($tvgId -match '\.uk($|@)') { return "UK" }

    $src = "$SourceUrl".ToLowerInvariant()
    if ($src -match '/countries/us\.m3u|ssungusa|localnow') { return "US" }
    if ($src -match '/countries/uk\.m3u|/gb') { return "UK" }

    $name = "$ChannelName"
    if ($name -match '(?i)\b(usa|u\.s\.?|united states|america)\b') { return "US" }
    if ($name -match '(?i)\b(uk|u\.k\.?|united kingdom|britain|british|england|scotland|wales)\b') { return "UK" }

    return $null
}

function Is-NewsCandidate {
    param(
        [string]$Name,
        [string]$GroupTitle
    )

    if ("$GroupTitle" -match '(?i)^news$|news|weather|business|finance') { return $true }
    if ("$Name" -match '(?i)\b(news|weather|business|finance|markets|headlines|journal|breaking)\b') { return $true }
    if ("$Name" -match '(?i)\b(BBC|CNN|MSNBC|CNBC|Bloomberg|Reuters|Euronews|France\s*24|Al\s*Jazeera|Sky\s*News|Newsmax|Scripps)\b') { return $true }
    return $false
}

function Test-StreamUrl {
    param(
        [string]$Url,
        [int]$ProbeTimeoutSec
    )

    try {
        $headers = @{
            "Range"      = "bytes=0-1024"
            "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
            "Accept"     = "*/*"
        }
        $resp = Invoke-WebRequest -Uri $Url -Method Get -Headers $headers -MaximumRedirection 5 -TimeoutSec $ProbeTimeoutSec -ErrorAction Stop
        if ($resp.StatusCode -in 200, 206) {
            return [PSCustomObject]@{ ok = $true; status = [string]$resp.StatusCode }
        }
        return [PSCustomObject]@{ ok = $false; status = [string]$resp.StatusCode }
    }
    catch {
        return [PSCustomObject]@{ ok = $false; status = "" }
    }
}

function New-ChannelId {
    param(
        [string]$Name,
        [string]$Region,
        [hashtable]$Taken
    )

    $base = ("$Name".ToLowerInvariant() -replace '[^a-z0-9]+', '_' -replace '^_+|_+$', '')
    if ([string]::IsNullOrWhiteSpace($base)) {
        $base = "channel"
    }

    $candidate = "{0}_{1}" -f $base, $Region.ToLowerInvariant()
    $index = 2
    while ($Taken.ContainsKey($candidate)) {
        $candidate = "{0}_{1}_{2}" -f $base, $Region.ToLowerInvariant(), $index
        $index++
    }

    $Taken[$candidate] = $true
    return $candidate
}

$rows = Import-Csv -Path $InputCsv
$existingUrl = @{}
$existingTvg = @{}
$existingId = @{}

foreach ($row in $rows) {
    $url = "$($row.stream_url)".Trim().ToLowerInvariant()
    if ($url) { $existingUrl[$url] = $true }

    $tvg = "$($row.tvg_id)".Trim().ToUpperInvariant()
    if ($tvg) { $existingTvg[$tvg] = $true }

    $id = "$($row.id)".Trim().ToLowerInvariant()
    if ($id) { $existingId[$id] = $true }
}

$added = New-Object System.Collections.Generic.List[object]
$utcNow = [DateTime]::UtcNow.ToString("o")

foreach ($source in $SourceUrls) {
    try {
        $resp = Invoke-WebRequest -Uri $source -TimeoutSec 30 -MaximumRedirection 5 -ErrorAction Stop
        if ($resp.Content -is [byte[]]) {
            $content = [System.Text.Encoding]::UTF8.GetString($resp.Content)
        }
        else {
            $content = [string]$resp.Content
        }
    }
    catch {
        Write-Host "SKIP source fetch failed: $source"
        continue
    }

    if ([string]::IsNullOrWhiteSpace($content)) {
        continue
    }

    $lines = $content -split "`r?`n"
    $pendingExtinf = $null

    foreach ($rawLine in $lines) {
        $line = "$rawLine".Trim()
        if (-not $line) { continue }

        if ($line.StartsWith("#EXTINF", [System.StringComparison]::OrdinalIgnoreCase)) {
            $pendingExtinf = $line
            continue
        }

        if ($line.StartsWith("#")) { continue }
        if (-not ($line -match '^https?://')) { continue }
        if (-not $pendingExtinf) { continue }

        $meta = Parse-Attributes -Extinf $pendingExtinf
        $pendingExtinf = $null

        $name = "$($meta["name"])".Trim()
        if ([string]::IsNullOrWhiteSpace($name)) {
            $name = "Unknown Channel"
        }

        $group = "$($meta["group-title"])".Trim()
        if (-not (Is-NewsCandidate -Name $name -GroupTitle $group)) {
            continue
        }

        $region = Resolve-Region -Meta $meta -SourceUrl $source -ChannelName $name
        if ($region -notin @("US", "UK")) {
            continue
        }

        $streamUrl = $line.Trim()
        if ($existingUrl.ContainsKey($streamUrl.ToLowerInvariant())) {
            continue
        }

        $tvgId = "$($meta["tvg-id"])".Trim()
        if (-not [string]::IsNullOrWhiteSpace($tvgId) -and $existingTvg.ContainsKey($tvgId.ToUpperInvariant())) {
            continue
        }

        $probe = Test-StreamUrl -Url $streamUrl -ProbeTimeoutSec $TimeoutSec
        if (-not $probe.ok) {
            continue
        }

        $logo = "$($meta["tvg-logo"])".Trim()
        $newId = New-ChannelId -Name $name -Region $region -Taken $existingId

        $row = [PSCustomObject]@{
            id                  = $newId
            name                = $name
            region              = $region
            language            = "English"
            tvg_id              = $tvgId
            tvg_logo            = $logo
            group_title         = "News"
            stream_url          = $streamUrl
            enabled             = "true"
            last_checked_ok     = "true"
            last_checked_at_utc = $utcNow
            last_status         = "$($probe.status)"
            last_error          = ""
        }

        $added.Add($row) | Out-Null
        $existingUrl[$streamUrl.ToLowerInvariant()] = $true
        if ($tvgId) { $existingTvg[$tvgId.ToUpperInvariant()] = $true }
    }
}

if ($added.Count -gt 0) {
    (@($rows) + @($added.ToArray())) | Export-Csv -Path $InputCsv -NoTypeInformation -Encoding UTF8
}

$added | Export-Csv -Path "reports/news-additions-us-uk.csv" -NoTypeInformation -Encoding UTF8

Write-Host "Added news channels: $($added.Count)"
if ($added.Count -gt 0) {
    $added | Group-Object region | Select-Object Name, Count | Sort-Object Name | Format-Table -AutoSize | Out-String | Write-Host
}
