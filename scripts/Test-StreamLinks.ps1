param(
    [string[]]$Regions,
    [int]$TimeoutSec = 8,
    [string]$InputCsv = "channels/channels.csv",
    [string]$ReportCsv = "reports/stream-check-report.csv",
    [string]$ReportJson = "reports/stream-check-report.json"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $InputCsv)) {
    throw "Input file not found: $InputCsv"
}

$channels = Import-Csv -Path $InputCsv

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

    $channels = $channels | Where-Object {
        $region = "$($_.region)".Trim().ToUpperInvariant()
        $regionSet.ContainsKey($region)
    }
}

if (-not $channels -or $channels.Count -eq 0) {
    Write-Host "No channels matched. Nothing to validate."
    exit 0
}

New-Item -ItemType Directory -Path "reports" -Force | Out-Null

$probeHandler = [System.Net.Http.HttpClientHandler]::new()
$probeHandler.AllowAutoRedirect = $true
$probeHandler.MaxAutomaticRedirections = 5

$probeClient = [System.Net.Http.HttpClient]::new($probeHandler)
$probeClient.Timeout = [TimeSpan]::FromSeconds([System.Math]::Max($TimeoutSec, 1))
$probeClient.DefaultRequestHeaders.TryAddWithoutValidation("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)") | Out-Null
$probeClient.DefaultRequestHeaders.TryAddWithoutValidation("Accept", "*/*") | Out-Null

function Test-StreamUrl {
    param(
        [string]$Url,
        [System.Net.Http.HttpClient]$Client
    )

    $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Get, $Url)
    $request.Headers.TryAddWithoutValidation("Range", "bytes=0-1024") | Out-Null

    $response = $null
    try {
        $response = $Client.SendAsync($request, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
        $statusCode = [int]$response.StatusCode
        $ok = $statusCode -in 200, 206

        return [PSCustomObject]@{
            ok     = $ok
            status = [string]$statusCode
            error  = if ($ok) { "" } else { "Non-success status" }
        }
    }
    catch [System.OperationCanceledException] {
        return [PSCustomObject]@{
            ok     = $false
            status = ""
            error  = "The operation timed out."
        }
    }
    catch {
        $statusCode = ""
        $exception = $_.Exception
        if ($null -ne $exception -and $exception.PSObject.Properties.Name -contains "StatusCode" -and $null -ne $exception.StatusCode) {
            $statusCode = [string][int]$exception.StatusCode
        }

        return [PSCustomObject]@{
            ok     = $false
            status = $statusCode
            error  = $exception.Message
        }
    }
    finally {
        if ($null -ne $response) {
            $response.Dispose()
        }
        $request.Dispose()
    }
}

$now = [DateTime]::UtcNow.ToString("o")
$results = New-Object System.Collections.Generic.List[Object]

foreach ($ch in $channels) {
    $url = "$($ch.stream_url)".Trim()
    $ok = $false
    $status = ""
    $errorText = ""

    if ([string]::IsNullOrWhiteSpace($url)) {
        $errorText = "Empty stream_url"
    }
    else {
        $probe = Test-StreamUrl -Url $url -Client $probeClient
        $ok = $probe.ok
        $status = $probe.status
        $errorText = $probe.error
    }

    $results.Add([PSCustomObject]@{
        id              = $ch.id
        name            = $ch.name
        region          = $ch.region
        stream_url      = $url
        ok              = $ok
        status          = $status
        checked_at_utc  = $now
        error           = $errorText
    }) | Out-Null
}

$probeClient.Dispose()
$probeHandler.Dispose()

$results | Export-Csv -Path $ReportCsv -NoTypeInformation -Encoding UTF8
$results | ConvertTo-Json -Depth 4 | Out-File -FilePath $ReportJson -Encoding UTF8

# Update source CSV with latest validation metadata.
$allChannels = Import-Csv -Path $InputCsv
$byId = @{}
foreach ($r in $results) {
    $byId[$r.id] = $r
}

foreach ($c in $allChannels) {
    if ($byId.ContainsKey($c.id)) {
        $hit = $byId[$c.id]
        $c.last_checked_ok = if ($hit.ok) { "true" } else { "false" }
        $c.last_checked_at_utc = $hit.checked_at_utc
        $c.last_status = "$($hit.status)"
        $c.last_error = "$($hit.error)"
    }
}

$allChannels | Export-Csv -Path $InputCsv -NoTypeInformation -Encoding UTF8

$okCount = ($results | Where-Object { $_.ok }).Count
$total = $results.Count
Write-Host "Validation complete: $okCount/$total working"
Write-Host "CSV report: $ReportCsv"
Write-Host "JSON report: $ReportJson"
