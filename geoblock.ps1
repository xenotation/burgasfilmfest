<# 
 Cloudflare Stream – create a geo-restricted playback token (allow BG only)
 This script contains your API token in plain text. Keep it private.
#>

# --- Your values (hardcoded) ---
$AccountId    = "a62ad6ad4ab61db8ab438ecc2b8c7930"
$ApiToken     = "PIN7GGpIdk7buD-W69bb2AO2-8jRpwjrmFcMsila"   # <-- your API token
$CustomerCode = "ojfdlxwm7xyjwjmt"
$VideoUid     = "a721db22c82be661373fe61c3b6552ed"

# Playback token lifetime (seconds). Max 86400 (24h).
$TtlSeconds = 2 * 60 * 60  # 2 hours

# Build request for /stream/<video_uid>/token
$exp  = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() + [int64]$TtlSeconds
$uri  = "https://api.cloudflare.com/client/v4/accounts/$AccountId/stream/$VideoUid/token"
$hdrs = @{
  "Authorization" = "Bearer $ApiToken"
  "Content-Type"  = "application/json"
}
$body = @{
  exp = [int64]$exp
  accessRules = @(
    @{ type = "ip.geoip.country"; country = @("BG"); action = "allow" },
    @{ type = "any";               action  = "block" }
  )
} | ConvertTo-Json -Depth 6

# Call API
try {
  $resp = Invoke-RestMethod -Method POST -Uri $uri -Headers $hdrs -Body $body
} catch {
  Write-Error "Request to Cloudflare failed: $($_.Exception.Message)"
  if ($_.Exception.Response -and $_.Exception.Response.GetResponseStream()) {
    $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
    Write-Error ("API response: " + $reader.ReadToEnd())
  }
  exit 1
}

if (-not $resp.success) {
  Write-Error ("Cloudflare API returned errors: " + ($resp.errors | ConvertTo-Json -Depth 6))
  exit 1
}

$token = $resp.result.token
if ([string]::IsNullOrWhiteSpace($token)) {
  Write-Error "No playback token returned. Check API token permissions and inputs."
  exit 1
}

# Tokenized playback URLs (token replaces the UID in the path)
$iframeUrl = "https://customer-$CustomerCode.cloudflarestream.com/$token/iframe?preload=true&autoplay=true"
$hlsUrl    = "https://customer-$CustomerCode.cloudflarestream.com/$token/manifest/video.m3u8"
$dashUrl   = "https://customer-$CustomerCode.cloudflarestream.com/$token/manifest/video.mpd"

"`nToken (JWT):`n$token`n"
"Embed (iframe):"
$iframeUrl
"`nHLS:"
$hlsUrl
"`nDASH:"
$dashUrl

# Also save to a file for easy copy/paste later
$out = @()
$out += "Token (JWT):"
$out += $token
$out += ""
$out += "Embed (iframe):"
$out += $iframeUrl
$out += ""
$out += "HLS:"
$out += $hlsUrl
$out += ""
$out += "DASH:"
$out += $dashUrl
$out | Set-Content -LiteralPath ".\stream_token_output.txt" -NoNewline:$false -Encoding UTF8

""
"Saved output to stream_token_output.txt"
