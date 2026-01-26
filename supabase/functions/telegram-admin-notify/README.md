# Telegram Admin Notification

Edge Function untuk hantar notifikasi ke Telegram group admin.

## Notifications yang disokong

| Type | Bila dihantar |
|------|---------------|
| `new_user` | User baru mendaftar |
| `upgrade_pro` | User upgrade ke Pro (payment success) |
| `payment_success` | Pembayaran berjaya |
| `payment_failed` | Pembayaran gagal |
| `trial_started` | Trial dimulakan |
| `subscription_expired` | Langganan tamat |

## Setup Environment Variables

Tambah di Supabase Dashboard → Settings → Edge Functions → Secrets:

```
TELEGRAM_BOT_TOKEN=8234966712:AAG24hYiTyfwRJ0PvWtQ9BMX66VkuaHzjhc
TELEGRAM_CHAT_ID=-3826457022
```

## Deploy

```bash
supabase functions deploy telegram-admin-notify
```

## Test Manual

```bash
curl -X POST https://YOUR_PROJECT.supabase.co/functions/v1/telegram-admin-notify \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" \
  -d '{
    "type": "new_user",
    "data": {
      "user_email": "test@example.com",
      "user_name": "Test User"
    }
  }'
```

## Integrasi

Function ini dipanggil oleh:
- `send-welcome-email` - bila user baru register
- `bcl-webhook` - bila payment success/failed
