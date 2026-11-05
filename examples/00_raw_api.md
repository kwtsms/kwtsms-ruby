# Raw API — No Client Library

Call all 7 kwtSMS endpoints using only Ruby stdlib (`net/http` + `json`). No gems needed.

Use this when you want full control or don't need the `kwtsms` gem.

## Prerequisites

- Ruby 2.7+ (any version with `net/http` and `json`)
- A kwtSMS account with API credentials ([kwtsms.com](https://www.kwtsms.com))

## Step by Step

### 1. Copy the file

```bash
cp examples/00_raw_api.rb my_sms_script.rb
```

### 2. Set your credentials

Open the file and replace the configuration block at the top:

```ruby
USERNAME  = "your_username"   # Your kwtSMS API username
PASSWORD  = "your_password"   # Your kwtSMS API password
SENDER_ID = "KWT-SMS"         # Replace with your private sender ID
TEST_MODE = "1"               # "1" = test (queued, not delivered), "0" = live
```

> **Warning:** `KWT-SMS` is a shared test sender. Register your own sender ID before going live.

### 3. Run it

```bash
ruby my_sms_script.rb
```

This runs all 7 sections in order: balance, sender IDs, coverage, validate, send, status, and DLR.

### 4. Pick the sections you need

Each section is independent (except status and DLR which need a `msg-id` from send). Copy only what you need into your own code.

## The Helper Function

The `api_request` helper is the only shared code. It handles auth, HTTPS, JSON encoding/decoding, and network errors:

```ruby
def api_request(endpoint, params = {})
  uri  = URI("https://www.kwtsms.com/API/#{endpoint}/")
  body = { "username" => USERNAME, "password" => PASSWORD }.merge(params)

  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true

  req = Net::HTTP::Post.new(uri.path)
  req["Content-Type"] = "application/json"
  req["Accept"]       = "application/json"
  req.body = body.to_json

  res = http.request(req)
  JSON.parse(res.body)
rescue => e
  { "result" => "ERROR", "code" => "NETWORK", "description" => e.message }
end
```

Every call returns a Hash. Check `result["result"] == "OK"` for success, or read `result["code"]` and `result["description"]` for the error.

## Endpoints

| # | Endpoint | What it does | Required params |
|---|----------|-------------|-----------------|
| 1 | `POST /API/balance/` | Check credit balance | (none) |
| 2 | `POST /API/senderid/` | List your sender IDs | (none) |
| 3 | `POST /API/coverage/` | List active country prefixes | (none) |
| 4 | `POST /API/validate/` | Validate phone numbers | `mobile` (comma-separated) |
| 5 | `POST /API/send/` | Send SMS | `sender`, `mobile`, `message`, `test` |
| 6 | `POST /API/status/` | Check message queue status | `msgid` |
| 7 | `POST /API/dlr/` | Delivery report (international only) | `msgid` |

## Key Rules

- **Always POST** — never GET (credentials leak in server logs)
- **Always set both headers** — `Content-Type: application/json` and `Accept: application/json`
- **Phone numbers**: digits only, international format, no `+` or `00` prefix (e.g. `965XXXXXXXX`)
- **Multiple numbers** — comma-separated, max 200 per request
- **Test mode** — set `"test": "1"` during development; messages are queued but not delivered
- **Rate limit**: max 10 requests/second per IP; going well above that auto-blocks your IP
- **Duplicate SMS protection (ERR028)**: opt-in per account. When on, sending the same message to a number within the account's window (10 seconds by default) rejects the whole request, and nothing is charged

## Going Live Checklist

1. Replace `KWT-SMS` with your registered private sender ID
2. Set `TEST_MODE = "0"`
3. Store credentials in environment variables, not in source code
4. Add rate limiting and CAPTCHA if sending OTPs
5. Save `msg-id` from every send response for status tracking

## API Docs

- [API Documentation (PDF)](https://www.kwtsms.com/doc/KwtSMS.com_API_Documentation_v41.pdf)
- [Support Center](https://www.kwtsms.com/support.html)
- [FAQ](https://www.kwtsms.com/faq_all.php)
