# Firebase Vertex AI Setup for Gemini

## Current Status
✅ `firebase_vertexai: ^0.2.2+1` package installed  
✅ Service code updated to use Firebase Vertex AI  
❌ Need to enable Vertex AI API in Google Cloud Console

## Step 1: Enable Vertex AI API

1. **Open Google Cloud Console**:
   - Go to: https://console.cloud.google.com/
   - Select your Firebase project from the dropdown

2. **Enable Vertex AI API**:
   - Click this direct link: https://console.cloud.google.com/apis/library/aiplatform.googleapis.com
   - Or manually navigate to: **APIs & Services** → **Library**
   - Search for "Vertex AI API"
   - Click **ENABLE**

3. **Enable Generative Language API** (if needed):
   - Go to: https://console.cloud.google.com/apis/library/generativelanguage.googleapis.com
   - Click **ENABLE**

## Step 2: Verify Firebase Project Setup

Your app should already have:
- ✅ Firebase initialized in `main.dart`
- ✅ `firebase_core` package installed
- ✅ `google-services.json` (Android) or `GoogleService-Info.plist` (iOS)

## Step 3: Test the Integration

After enabling the APIs:

1. **Restart your Flutter app** (full restart, not hot reload):
   ```bash
   flutter run
   ```

2. **Test invoice scanning**:
   - Open the app
   - Navigate to Purchased Entries
   - Tap the scan icon
   - Choose "Take Photo" or "Choose from Gallery"
   - Select an invoice image

## Expected Behavior

**Success**: You should see "Processing Invoice" dialog with "Powered by Gemini AI" badge, then the invoice data populated in the purchase entry form.

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
