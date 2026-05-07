param(
    [string[]]$SourceUrls = @(
        "https://apsattv.com/ssungusa.m3u",
        "https://i.mjh.nz/PlutoTV/all.m3u8",
        "https://www.apsattv.com/rok.m3u",
        "https://www.apsattv.com/lg.m3u",
        "https://www.apsattv.com/vizio.m3u",
        "https://www.apsattv.com/redbox.m3u",
        "https://www.apsattv.com/distro.m3u",
        "https://www.apsattv.com/xiaomi.m3u",
        "https://www.apsattv.com/xumo.m3u",
        "https://www.apsattv.com/localnow.m3u",
        "https://od.lk/s/MzJfMTY2NzU4NDVf/Free2ViewTV-2021-Master.m3u",
        "https://raw.githubusercontent.com/Free-TV/IPTV/master/playlist.m3u8",
        "https://tvpass.org/playlist/m3u",
        "https://raw.githubusercontent.com/iptv-org/iptv/master/streams/index.m3u",
        "https://iptv-org.github.io/iptv/index.m3u",
        "https://iptv-org.github.io/iptv/categories/news.m3u",
        "https://iptv-org.github.io/iptv/categories/documentary.m3u",
        "https://iptv-org.github.io/iptv/countries/us.m3u",
        "https://iptv-org.github.io/iptv/countries/uk.m3u",
        "https://iptv-org.github.io/iptv/countries/pk.m3u"
    ),
    [string[]]$Regions = @("US", "UK", "PK"),
    [int]$TimeoutSec = 8,
    [string]$InputCsv = "channels/channels.csv"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $InputCsv)) {
    throw "Input file not found: $InputCsv"
}

function Normalize-Region {
    param([string]$Raw)

    $value = "$Raw".Trim().ToUpperInvariant()
    if ($value -in @("GB", "UK", "GBR", "UNITED KINGDOM")) { return "UK" }
    if ($value -in @("US", "USA", "UNITED STATES", "UNITED STATES OF AMERICA")) { return "US" }
    if ($value -in @("PK", "PAK", "PAKISTAN", "ISLAMIC REPUBLIC OF PAKISTAN")) { return "PK" }
    return $null
}

function Resolve-Region {
    param(
        [hashtable]$Meta,
        [string]$SourceUrl,
        [string]$ChannelName
    )

    $countryRaw = ""
    if ($Meta.ContainsKey("tvg-country")) {
        $countryRaw = "$($Meta["tvg-country"])"
    }

    if (-not [string]::IsNullOrWhiteSpace($countryRaw)) {
        $countryParts = $countryRaw -split "[|,;/]"
        foreach ($part in $countryParts) {
            $region = Normalize-Region -Raw $part
            if ($region) { return $region }
        }
    }

    $tvgId = "$($Meta["tvg-id"])".Trim().ToLowerInvariant()
    if ($tvgId -match "\.uk($|@)") { return "UK" }
    if ($tvgId -match "\.us($|@)") { return "US" }
    if ($tvgId -match "\.pk($|@)") { return "PK" }

    $src = "$SourceUrl".ToLowerInvariant()
    if ($src -match "(country|countries)/us\.m3u|usa|ssungusa") { return "US" }
    if ($src -match "(country|countries)/uk\.m3u|playlist_uk|gb") { return "UK" }
    if ($src -match "(country|countries)/pk\.m3u|pakistan|\bpk\b") { return "PK" }

    if ($src -match "apsattv\.com|mjh\.nz|tvpass\.org") {
        $name = "$ChannelName".ToUpperInvariant()
        if ($name -match "\bUK\b|\bGB\b|BRITAIN|BRITISH|LONDON") {
            return "UK"
        }
        if ($name -match "\bPK\b|PAKISTAN|KARACHI|ISLAMABAD|LAHORE") {
            return "PK"
        }
        return "US"
    }

    return $null
}

function Parse-Attributes {
    param([string]$Extinf)

    $map = @{}
    $matches = [regex]::Matches($Extinf, '([a-zA-Z0-9_-]+)="([^"]*)"')
    foreach ($m in $matches) {
        $map[$m.Groups[1].Value.ToLowerInvariant()] = $m.Groups[2].Value
    }

    $name = ""
    if ($Extinf -match ",[\s]*(.*)$") {
        $name = $Extinf -replace "^.*?,", ""
    }

    $map["name"] = "$name".Trim()
    return $map
}

function Test-StreamUrl {
    param(
        [string]$Url,
        [int]$ProbeTimeoutSec
    )

    $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Get, $Url)
    $request.Headers.TryAddWithoutValidation("Range", "bytes=0-1024") | Out-Null

    $response = $null
    try {
        $response = $script:ProbeClient.SendAsync($request, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
        $statusCode = [int]$response.StatusCode
        if ($statusCode -in 200, 206) {
            return [PSCustomObject]@{ ok = $true; status = [string]$statusCode; error = "" }
        }
        return [PSCustomObject]@{ ok = $false; status = [string]$statusCode; error = "Non-success status" }
    }
    catch [System.OperationCanceledException] {
        return [PSCustomObject]@{ ok = $false; status = ""; error = "The operation timed out." }
    }
    catch {
        $status = ""
        $exception = $_.Exception
        if ($null -ne $exception -and $exception.PSObject.Properties.Name -contains "StatusCode" -and $null -ne $exception.StatusCode) {
            $status = [string][int]$exception.StatusCode
        }
        return [PSCustomObject]@{ ok = $false; status = $status; error = $exception.Message }
    }
    finally {
        if ($null -ne $response) {
            $response.Dispose()
        }
        $request.Dispose()
    }
}

function New-ChannelId {
    param(
        [string]$Name,
        [string]$Region,
        [hashtable]$Taken
    )

    $base = ("$Name".ToLowerInvariant() -replace "[^a-z0-9]+", "_" -replace "^_+|_+$", "")
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

$regionAllow = @{}
foreach ($r in $Regions) {
    $normalized = Normalize-Region -Raw $r
    if ($normalized) { $regionAllow[$normalized] = $true }
}

$rows = Import-Csv -Path $InputCsv
$existingUrl = @{}
$existingId = @{}
$existingTvg = @{}
foreach ($row in $rows) {
    $url = "$($row.stream_url)".Trim()
    if (-not [string]::IsNullOrWhiteSpace($url)) { $existingUrl[$url] = $true }

    $id = "$($row.id)".Trim()
    if (-not [string]::IsNullOrWhiteSpace($id)) { $existingId[$id] = $true }

    $tvg = "$($row.tvg_id)".Trim().ToUpperInvariant()
    if (-not [string]::IsNullOrWhiteSpace($tvg)) { $existingTvg[$tvg] = $true }
}

$added = New-Object System.Collections.Generic.List[Object]
$seenCandidateUrl = @{}
$utcNow = [DateTime]::UtcNow.ToString("o")

$probeHandler = [System.Net.Http.HttpClientHandler]::new()
$probeHandler.AllowAutoRedirect = $true
$probeHandler.MaxAutomaticRedirections = 5
$script:ProbeClient = [System.Net.Http.HttpClient]::new($probeHandler)
$script:ProbeClient.Timeout = [TimeSpan]::FromSeconds([System.Math]::Max($TimeoutSec, 1))
$script:ProbeClient.DefaultRequestHeaders.TryAddWithoutValidation("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)") | Out-Null
$script:ProbeClient.DefaultRequestHeaders.TryAddWithoutValidation("Accept", "*/*") | Out-Null

foreach ($source in $SourceUrls) {
    try {
        $resp = Invoke-WebRequest -Uri $source -TimeoutSec 20 -MaximumRedirection 5 -ErrorAction Stop
        $contentObj = $resp.Content
        if ($contentObj -is [byte[]]) {
            $content = [System.Text.Encoding]::UTF8.GetString($contentObj)
        }
        else {
            $content = [string]$contentObj
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
        if ([string]::IsNullOrWhiteSpace($line)) { continue }

        if ($line.StartsWith("#EXTINF", [System.StringComparison]::OrdinalIgnoreCase)) {
            $pendingExtinf = $line
            continue
        }

        if ($line.StartsWith("#")) {
            continue
        }

        if (-not ($line -match "^https?://")) {
            continue
        }

        if (-not $pendingExtinf) {
            continue
        }

        $meta = Parse-Attributes -Extinf $pendingExtinf
        $pendingExtinf = $null

        $region = Resolve-Region -Meta $meta -SourceUrl $source -ChannelName "$($meta["name"])"
        if (-not $region) { continue }
        if (-not $regionAllow.ContainsKey($region)) { continue }

        $streamUrl = $line
        if ($existingUrl.ContainsKey($streamUrl) -or $seenCandidateUrl.ContainsKey($streamUrl)) {
            continue
        }

        $tvgId = "$($meta["tvg-id"])".Trim()
        if (-not [string]::IsNullOrWhiteSpace($tvgId)) {
            $tvgKey = $tvgId.ToUpperInvariant()
            if ($existingTvg.ContainsKey($tvgKey)) {
                continue
            }
        }

        $probe = Test-StreamUrl -Url $streamUrl -ProbeTimeoutSec $TimeoutSec
        if (-not $probe.ok) {
            continue
        }

        $name = "$($meta["name"])".Trim()
        if ([string]::IsNullOrWhiteSpace($name)) {
            $name = "Unknown Channel"
        }

        $group = "$($meta["group-title"])".Trim()
        if ([string]::IsNullOrWhiteSpace($group)) {
            $group = "General"
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
            group_title         = $group
            stream_url          = $streamUrl
            enabled             = "true"
            last_checked_ok     = "true"
            last_checked_at_utc = $utcNow
            last_status         = "$($probe.status)"
            last_error          = ""
        }

        $added.Add($row) | Out-Null
        $seenCandidateUrl[$streamUrl] = $true
        $existingUrl[$streamUrl] = $true
        if (-not [string]::IsNullOrWhiteSpace($tvgId)) {
            $existingTvg[$tvgId.ToUpperInvariant()] = $true
        }
    }
}

try {
    if ($added.Count -eq 0) {
        Write-Host "No new working channels found for selected regions."
        exit 0
    }

    $merged = @($rows) + @($added.ToArray())
    $merged | Export-Csv -Path $InputCsv -NoTypeInformation -Encoding UTF8

    Write-Host "Added channels: $($added.Count)"
    Write-Host "Updated CSV: $InputCsv"
}
finally {
    $script:ProbeClient.Dispose()
    $probeHandler.Dispose()
}