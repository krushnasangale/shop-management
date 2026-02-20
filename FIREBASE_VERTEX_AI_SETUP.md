# Firebase AI (Gemini 2.0) Setup Guide

## Current Status
✅ `firebase_ai: ^3.8.0` package installed  
✅ Service code using Firebase Vertex AI with Gemini 2.0  
✅ Auto-retry logic with exponential backoff  
⚠️ **Required**: Enable Vertex AI API in Google Cloud Console

## Step 1: Enable Vertex AI API

1. **Open Google Cloud Console**:
   - Go to: https://console.cloud.google.com/
   - Select your Firebase project: `shop-management-42ce1`

2. **Enable Vertex AI API**:
   - Direct link: https://console.cloud.google.com/apis/library/aiplatform.googleapis.com
   - Or navigate: **APIs & Services** → **Library**
   - Search for "Vertex AI API"
   - Click **ENABLE**
   - Wait 2-5 minutes for activation

3. **Enable Billing** (Required even for free tier):
   - Go to: https://console.firebase.google.com/
   - Select your project
   - Settings → Usage and billing
   - Upgrade to **Blaze (Pay as you go)** plan

## Step 2: Firebase Authentication

The app uses **Firebase Authentication** (no API keys needed):
- ✅ Firebase Auth handles authentication automatically
- ✅ No `.env` files or API keys required
- ✅ Uses: `FirebaseAI.vertexAI(auth: FirebaseAuth.instance)`

## Step 3: Test Invoice Scanning

1. **Restart your app** (full restart):
   ```bash
   flutter run
   ```

2. **Scan an invoice**:
   - Navigate to **Purchased Entries**
   - Tap the scan (➕) button
   - Choose:
     - **Camera** (Mobile only) - Capture invoice photo
     - **Gallery** - Select from photos
     - **PDF** - Select PDF invoice (supports up to 5 pages)

## Features

### Multi-Page PDF Support
- ✅ Supports 1-5 page invoices
- ✅ Auto-limits to 15,000 characters
- ✅ Extracts data from all pages

### Discount Handling
- ✅ Extracts base unit price (before discount)
- ✅ Handles discount columns correctly
- ✅ Stores original prices for accurate inventory tracking

### Auto-Retry
- ✅ 3 retry attempts with exponential backoff (2s, 4s, 8s)
- ✅ Handles rate limiting automatically
- ✅ Smart text limiting to avoid quota issues

## Pricing

**Free Tier** (Very Generous):
- 1,500 requests/day - FREE
- 15 requests/minute
- 1M requests/month - FREE

**Paid Tier** (Gemini 2.0 Flash):
- Input: $0.075 per 1M tokens (~750K words)
- Images: $0.00025 per image
- Output: $0.30 per 1M tokens

**Cost per invoice scan**: ~$0.0004 (less than 1/20th of a cent!)

## Troubleshooting

### "Too many requests" error:
- ✅ Auto-retry already implemented
- ⚠️ If scanning many invoices rapidly, wait 60 seconds

### "API not enabled" error:
- ❌ Enable Vertex AI API (see Step 1)
- ⏳ Wait 2-5 minutes after enabling

### "Billing not enabled" error:
- ❌ Enable Blaze plan in Firebase Console
- ℹ️ Free tier is sufficient for most businesses

## Model Information

- **Current Model**: `gemini-2.0-flash-exp`
- **Previous Models**: Gemini 1.5 retired Sep 24, 2025
- **Performance**: Fast, accurate, multi-language support
- **Languages**: English, Hindi, Marathi (mixed text supported)

**If you still get errors**:
- Check the console output for specific error messages
- Verify your Firebase project has billing enabled (Vertex AI requires billing)
- Make sure you're using a Firebase project, not just a standalone Google Cloud project

## Pricing (Firebase Vertex AI is Pay-as-you-go)

**Free Tier** (as of Feb 2026):
- Gemini 1.5 Flash: 15 RPM, 1,500 RPD, 1M tokens/min (FREE)
- After free quota: ~$0.05 per 1K requests

**Daily Usage Estimate for Your Shop**:
- 50 invoices/day = FREE (well within 1,500 limit)
- 1000 invoices/day = Still FREE

## Notes

- No API key needed - Firebase handles authentication automatically
- Uses your Firebase project's quota
- Billing must be enabled on your Google Cloud project (even for free tier)
- More secure than storing API keys

## Troubleshooting

**Error: "models/gemini-1.5-flash is not found"**
- Solution: Enable Vertex AI API (steps above)

**Error: "PERMISSION_DENIED"**
- Solution: Enable billing on your Firebase/GCP project

**Error: "Firebase not initialized"**
- Solution: Make sure `await Firebase.initializeApp()` runs before `GeminiService().initialize()`
