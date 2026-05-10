param(
    [string]$OutputCandidates = "reports/official-more-candidates.csv",
    [string]$OutputValidation = "reports/official-more-validation.csv",
    [int]$MaxCandidates = 180,
    [int]$TimeoutSec = 12
)

$ErrorActionPreference = "Stop"

New-Item -ItemType Directory -Path "reports" -Force | Out-Null

$sources = @(
    "https://iptv-org.github.io/iptv/countries/us.m3u",
    "https://iptv-org.github.io/iptv/countries/uk.m3u",
    "https://iptv-org.github.io/iptv/countries/pk.m3u",
    "https://iptv-org.github.io/iptv/categories/news.m3u",
    "https://iptv-org.github.io/iptv/categories/movies.m3u",
    "https://iptv-org.github.io/iptv/categories/kids.m3u",
    "https://iptv-org.github.io/iptv/categories/music.m3u",
    "https://iptv-org.github.io/iptv/categories/documentary.m3u",
    "https://iptv-org.github.io/iptv/categories/entertainment.m3u",
    "https://iptv-org.github.io/iptv/categories/lifestyle.m3u"
)

$manualCandidates = @(
    [pscustomobject]@{ source = "Official FAST"; region = "US"; name = "Bon Appetit"; group = "Lifestyle"; url = "https://bonappetit-samsung.amagi.tv/playlist.m3u8"; logo = "https://i.imgur.com/PRgLwQw.png"; tvg_id = "BonAppetit.us" },
    [pscustomobject]@{ source = "Official FAST"; region = "US"; name = "America's Funniest Home Videos"; group = "Entertainment"; url = "https://d1mp1kdk5zi1ie.cloudfront.net/playlist.m3u8"; logo = ""; tvg_id = "AmericasFunniestHomeVideos.us" },
    [pscustomobject]@{ source = "Official FAST"; region = "US"; name = "Anger Management Channel"; group = "Entertainment"; url = "https://amg00353-lionsgatestudio-angermgmt-samsungau-o9jg9.amagi.tv/playlist/amg00353-lionsgatestudio-angermgmt-samsungau/playlist.m3u8"; logo = ""; tvg_id = "AngerManagementChannel.us" },
    [pscustomobject]@{ source = "Official FAST"; region = "US"; name = "Antiques Roadshow PBS"; group = "Documentary"; url = "https://amg00953-pbsusa-antiroadshow-xumo-x6ud5.amagi.tv/playlist.m3u8"; logo = ""; tvg_id = "AntiquesRoadshowPBS.us" },
    [pscustomobject]@{ source = "Official YouTube"; region = "US"; name = "NASA (YouTube Live)"; group = "Documentary"; url = "https://www.youtube.com/@NASA/live"; logo = "https://upload.wikimedia.org/wikipedia/commons/e/e5/NASA_logo.svg"; tvg_id = "NASAYouTube.us" },
    [pscustomobject]@{ source = "Official YouTube"; region = "US"; name = "FilmRise Movies (YouTube Live)"; group = "Movies"; url = "https://www.youtube.com/@FilmRiseMovies/live"; logo = "https://i.imgur.com/Sq8Vone.png"; tvg_id = "FilmRiseMoviesYouTube.us" },
    [pscustomobject]@{ source = "Official YouTube"; region = "US"; name = "Vevo (YouTube Live)"; group = "Music"; url = "https://www.youtube.com/@Vevo/live"; logo = "https://i.imgur.com/ClZyTV8.png"; tvg_id = "VevoYouTube.us" },
    [pscustomobject]@{ source = "Official YouTube"; region = "UK"; name = "BBC News (YouTube Live)"; group = "News"; url = "https://www.youtube.com/@BBCNews/live"; logo = "https://upload.wikimedia.org/wikipedia/commons/thumb/a/a2/BBC_News_2022_%28Alt%29.svg/512px-BBC_News_2022_%28Alt%29.svg.png"; tvg_id = "BBCNews.uk" },
    [pscustomobject]@{ source = "Official YouTube"; region = "UK"; name = "Sky News (YouTube Live)"; group = "News"; url = "https://www.youtube.com/@SkyNews/live"; logo = "https://upload.wikimedia.org/wikipedia/en/thumb/5/57/Sky_News_logo_2020.svg/512px-Sky_News_logo_2020.svg.png"; tvg_id = "SkyNews.uk" },
    [pscustomobject]@{ source = "Official FAST"; region = "UK"; name = "CNBC"; group = "News"; url = "https://amg01079-nbcuuk-amg01079c2-samsung-gb-1258.playouts.now.amagi.tv/playlist.m3u8"; logo = ""; tvg_id = "CNBC.uk" },
    [pscustomobject]@{ source = "Official FAST"; region = "UK"; name = "Tastemade"; group = "Lifestyle"; url = "https://tastemade-tdint-rakuten.amagi.tv/playlist.m3u8"; logo = "https://i.imgur.com/xP1Paz8.png"; tvg_id = "Tastemade.uk" },
    [pscustomobject]@{ source = "Official FAST"; region = "UK"; name = "Deadly Women"; group = "Documentary"; url = "https://d1mgh147xpmgs8.cloudfront.net/DeadlyWomen_GB.m3u8"; logo = ""; tvg_id = "DeadlyWomen.uk" },
    [pscustomobject]@{ source = "Official FAST"; region = "UK"; name = "Get.Factual"; group = "Documentary"; url = "https://d1nhni5l2n8hjt.cloudfront.net/gf.m3u8"; logo = ""; tvg_id = "GetFactual.uk" },
    [pscustomobject]@{ source = "Official FAST"; region = "UK"; name = "So Real"; group = "Lifestyle"; url = "https://all3media-soreal-1-gb.samsung.wurl.tv/playlist.m3u8"; logo = ""; tvg_id = "SoReal.uk" },
    [pscustomobject]@{ source = "Official YouTube"; region = "UK"; name = "DW Documentary (YouTube Live)"; group = "Documentary"; url = "https://www.youtube.com/@DWDocumentary/live"; logo = "https://upload.wikimedia.org/wikipedia/commons/thumb/8/8e/DW_%28English%29.svg/512px-DW_%28English%29.svg.png"; tvg_id = "DWDocumentaryYouTube.uk" },
    [pscustomobject]@{ source = "Official YouTube"; region = "PK"; name = "Geo News (YouTube Live)"; group = "News"; url = "https://www.youtube.com/@GeoNews/live"; logo = "https://i.imgur.com/3Qx6Wyk.png"; tvg_id = "GeoNews.pk" },
    [pscustomobject]@{ source = "Official YouTube"; region = "PK"; name = "Dunya News (YouTube Live)"; group = "News"; url = "https://www.youtube.com/@DunyaNews/live"; logo = "https://i.imgur.com/1PbtW0y.png"; tvg_id = "DunyaNews.pk" },
    [pscustomobject]@{ source = "Official YouTube"; region = "PK"; name = "Samaa TV (YouTube Live)"; group = "News"; url = "https://www.youtube.com/@samaatv/live"; logo = ""; tvg_id = "SamaaTV.pk" },
    [pscustomobject]@{ source = "Official YouTube"; region = "PK"; name = "Hum News (YouTube Live)"; group = "News"; url = "https://www.youtube.com/@HUMNewsPakistan/live"; logo = "https://i.imgur.com/SJyGfDu.png"; tvg_id = "HumNews.pk" },
    [pscustomobject]@{ source = "Official YouTube"; region = "PK"; name = "ARY Digital (YouTube Live)"; group = "Entertainment"; url = "https://www.youtube.com/@ARYDigitalasia/live"; logo = "https://i.imgur.com/jHXju79.png"; tvg_id = "ARYDigital.pk" },
    [pscustomobject]@{ source = "Official YouTube"; region = "PK"; name = "ARY Musik (YouTube Live)"; group = "Music"; url = "https://www.youtube.com/@arymusik/live"; logo = ""; tvg_id = "ARYMusikYouTube.pk" },
    [pscustomobject]@{ source = "Official YouTube"; region = "PK"; name = "Kids Zone Pakistan (YouTube Live)"; group = "Kids"; url = "https://www.youtube.com/@KidsZonePakistan/live"; logo = ""; tvg_id = "KidsZoneYouTube.pk" },
    [pscustomobject]@{ source = "Official YouTube"; region = "PK"; name = "Geo Kahani (YouTube Live)"; group = "Entertainment"; url = "https://www.youtube.com/@GeoKahani/live"; logo = ""; tvg_id = "GeoKahaniYouTube.pk" },
    [pscustomobject]@{ source = "Official YouTube"; region = "PK"; name = "Geo Super (YouTube Live)"; group = "Sports"; url = "https://www.youtube.com/@GeoSuper/live"; logo = ""; tvg_id = "GeoSuperYouTube.pk" },
    [pscustomobject]@{ source = "Official YouTube"; region = "PK"; name = "HUM TV (YouTube Live)"; group = "Entertainment"; url = "https://www.youtube.com/@HUMTV/live"; logo = ""; tvg_id = "HUMTVYouTube.pk" },
    [pscustomobject]@{ source = "Official YouTube"; region = "PK"; name = "HUM Masala (YouTube Live)"; group = "Lifestyle"; url = "https://www.youtube.com/@MasalaTVRecipes/live"; logo = ""; tvg_id = "HUMMasalaYouTube.pk" },
    [pscustomobject]@{ source = "Official YouTube"; region = "PK"; name = "BOL News (YouTube Live)"; group = "News"; url = "https://www.youtube.com/@BOLNewsOfficial/live"; logo = ""; tvg_id = "BOLNewsYouTube.pk" },
    [pscustomobject]@{ source = "Official YouTube"; region = "PK"; name = "Express News (YouTube Live)"; group = "News"; url = "https://www.youtube.com/@ExpressNewsOfficial/live"; logo = ""; tvg_id = "ExpressNewsYouTube.pk" },
    [pscustomobject]@{ source = "Official YouTube"; region = "PK"; name = "Aaj News (YouTube Live)"; group = "News"; url = "https://www.youtube.com/@AajNews/live"; logo = ""; tvg_id = "AajNewsYouTube.pk" }
)

function Get-ResponseText {
    param([object]$Response)

    if ($Response.Content -is [byte[]]) {
        return [Text.Encoding]::UTF8.GetString($Response.Content)
    }

    return [string]$Response.Content
}

function Get-AttrValue {
    param([string]$Text, [string]$Name)

    $match = [regex]::Match($Text, ('{0}="([^"]*)"' -f [regex]::Escape($Name)))
    if ($match.Success) { return $match.Groups[1].Value }
    return ""
}

function Get-Region {
    param([string]$Source, [string]$Extinf)

    $country = Get-AttrValue -Text $Extinf -Name "tvg-country"
    if ($country -match "(^|;)(UK|GB)($|;)") { return "UK" }
    if ($country -match "(^|;)US($|;)") { return "US" }
    if ($country -match "(^|;)PK($|;)") { return "PK" }
    if ($Source -match "/countries/us\.m3u") { return "US" }
    if ($Source -match "/countries/uk\.m3u") { return "UK" }
    if ($Source -match "/countries/pk\.m3u") { return "PK" }
    return ""
}

function Test-CandidateUrl {
    param([string]$Url)

    if ($Url -match "youtube\.com|youtu\.be") {
        try {
            $response = Invoke-WebRequest -UseBasicParsing -Uri $Url -TimeoutSec $TimeoutSec -MaximumRedirection 5
            $content = Get-ResponseText -Response $response
            $isLive = $content -match "isLiveNow|LIVE|watchEndpoint|hlsManifestUrl"
            return [pscustomobject]@{ ok = ([int]$response.StatusCode -eq 200 -and $isLive); status = [string][int]$response.StatusCode; error = if ($isLive) { "" } else { "YouTube page reachable but live markers not found" } }
        }
        catch {
            return [pscustomobject]@{ ok = $false; status = ""; error = $_.Exception.Message }
        }
    }

    try {
        $response = Invoke-WebRequest -UseBasicParsing -Headers @{ Range = "bytes=0-1024"; "User-Agent" = "Mozilla/5.0" } -Uri $Url -TimeoutSec $TimeoutSec
        $statusCode = [int]$response.StatusCode
        return [pscustomobject]@{ ok = ($statusCode -in 200, 206); status = [string]$statusCode; error = "" }
    }
    catch {
        return [pscustomobject]@{ ok = $false; status = ""; error = $_.Exception.Message }
    }
}

$existingRows = Import-Csv "channels/channels.csv"
$existingUrls = @{}
$existingIds = @{}
foreach ($row in $existingRows) {
    $existingIds[$row.id] = $true
    if (-not [string]::IsNullOrWhiteSpace($row.stream_url)) {
        $existingUrls[$row.stream_url.Trim()] = $true
    }
}

$parsed = New-Object System.Collections.Generic.List[object]
foreach ($source in $sources) {
    try {
        $response = Invoke-WebRequest -UseBasicParsing -Uri $source -TimeoutSec 60
        $content = Get-ResponseText -Response $response
    }
    catch {
        continue
    }

    $lines = $content -split "`r?`n"
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if (-not $lines[$i].StartsWith("#EXTINF")) { continue }
        if (($i + 1) -ge $lines.Count) { continue }

        $extinf = $lines[$i]
        $urlIndex = $i + 1
        while ($urlIndex -lt $lines.Count -and $lines[$urlIndex].Trim().StartsWith("#EXTVLCOPT")) {
            $urlIndex++
        }
        if ($urlIndex -ge $lines.Count) { continue }

        $url = $lines[$urlIndex].Trim()
        if ([string]::IsNullOrWhiteSpace($url) -or $url.StartsWith("#")) { continue }
        if ($url -match "youtube\.com|youtu\.be|twitch\.tv|\.mp4($|\?)") { continue }
        if ($existingUrls.ContainsKey($url)) { continue }

        $name = ($extinf -replace "^.*?,", "").Trim()
        $region = Get-Region -Source $source -Extinf $extinf
        if ([string]::IsNullOrWhiteSpace($region)) { continue }

        $group = Get-AttrValue -Text $extinf -Name "group-title"
        if (("$name $group") -match "(?i)relig|church|faith|qvc|hsn|shop|shopping|adult|xxx|radio") { continue }

        $logo = Get-AttrValue -Text $extinf -Name "tvg-logo"
        $tvgId = Get-AttrValue -Text $extinf -Name "tvg-id"

        $parsed.Add([pscustomobject]@{ source = $source; region = $region; name = $name; group = $group; url = $url; logo = $logo; tvg_id = $tvgId }) | Out-Null
    }
}

$popular = "ABC|CBS|NBC|PBS|FOX|CNN|Bloomberg|CNBC|Cheddar|Scripps|Newsmax|Court|Sky|BBC|ITV|Channel|GB News|Talk|GREAT|Now|Trace|Vevo|MTV|Nick|Cartoon|FilmRise|Movie|Movies|NASA|Nature|Documentary|Tastemade|Bon Appetit|Home|Food|Geo|ARY|Samaa|Dunya|Dawn|Hum|Express|PTV|Bol|Kids|Music"
$categoryMatch = "(?i)news|movies|kids|music|documentary|entertainment|lifestyle|general"

$combined = @($manualCandidates) + @($parsed | Where-Object { $_.name -match $popular -or $_.group -match $categoryMatch })
$candidates = @($combined | Sort-Object region, name, url -Unique | Select-Object -First $MaxCandidates)
$candidates | Export-Csv -Path $OutputCandidates -NoTypeInformation -Encoding UTF8

$results = foreach ($candidate in $candidates) {
    $probe = if ($existingUrls.ContainsKey($candidate.url.Trim())) {
        [pscustomobject]@{ ok = $false; status = "SKIP"; error = "Duplicate existing URL" }
    }
    else {
        Test-CandidateUrl -Url $candidate.url
    }

    [pscustomobject]@{
        region = $candidate.region
        name = $candidate.name
        group_title = $candidate.group
        ok = $probe.ok
        status = $probe.status
        error = $probe.error
        stream_url = $candidate.url
        tvg_id = $candidate.tvg_id
        tvg_logo = $candidate.logo
        source = $candidate.source
    }
}

$results | Export-Csv -Path $OutputValidation -NoTypeInformation -Encoding UTF8

$ok = @($results | Where-Object { $_.ok })
Write-Host "Candidates: $($candidates.Count)"
Write-Host "Validated OK: $($ok.Count)"
$ok | Sort-Object region, group_title, name | Format-Table region, group_title, name, status, source -AutoSize
