# Google Drive Sync Setup Guide

## Overview

Google Drive Sync membolehkan users untuk auto-backup documents penting (invoices, claims, receipts) ke Google Drive account masing-masing secara automatik.

## Architecture

### 1. OAuth Credentials Setup (One-time for App)

Setup OAuth credentials sekali untuk app di Google Cloud Console:

1. **Create Google Cloud Project**
   - Go to [Google Cloud Console](https://console.cloud.google.com/)
   - Create new project atau select existing project

2. **Enable Google Drive API**
   - Go to "APIs & Services" > "Library"
   - Search for "Google Drive API"
   - Click "Enable"

3. **Create OAuth 2.0 Credentials**
   - Go to "APIs & Services" > "Credentials"
   - Click "Create Credentials" > "OAuth client ID"
   - Application type: **Web application** (for Flutter web) atau **Android/iOS** (for mobile)
   - Add authorized redirect URIs:
     - For web: `http://localhost:3000` (development)
     - For mobile: Use package name (e.g., `com.pocketbizz.app`)
   - Save the **Client ID** and **Client Secret**

4. **Add Client ID to App**
   - Add Client ID to `GoogleSignIn` configuration in `google_drive_service.dart`
   - Or use environment variables for production

### 2. User Authentication Flow

Setiap user akan sign in dengan Google account mereka sendiri:

1. User click "Sync to Google Drive" atau enable auto-sync
2. App shows Google Sign-In dialog
3. User select Google account mereka
4. App gets access token untuk Google Drive API
5. Token stored securely (temporary, refresh as needed)

### 3. Auto-Sync Flow

Selepas document di-generate (invoice, claim, receipt):

1. PDF generated menggunakan existing PDF generators
2. Call `GoogleDriveService.autoSyncDocument()`
3. File uploaded ke Google Drive user
4. Sync log created dalam database
5. User boleh view sync logs di "Google Drive Sync" page

## Integration Example

### Example: Sync Invoice After Generation

```dart
import 'package:printing/printing.dart';
import '../drive_sync/services/google_drive_service.dart';

// After generating invoice PDF
Future<void> generateAndSyncInvoice(Sale sale) async {
  // 1. Generate PDF (existing code)
  final pdf = await generateInvoicePDF(sale);
  
  // 2. Show preview/print (existing code)
  await Printing.layoutPdf(
    onLayout: (format) async => pdf.save(),
  );
  
  // 3. Auto-sync to Google Drive (NEW)
  final driveService = GoogleDriveService();
  
  // Check if user is signed in, if not, prompt sign in
  if (!driveService.isSignedIn) {
    final signedIn = await driveService.signIn();
    if (!signedIn) {
      // User cancelled sign in, skip sync
      return;
    }
  }
  
  // Sync to Google Drive
  final fileName = 'Invoice_${sale.invoiceNumber}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
  final pdfBytes = await pdf.save();
  
  await driveService.autoSyncDocument(
    pdfData: Uint8List.fromList(pdfBytes),
    fileName: fileName,
    fileType: 'invoice',
    relatedEntityType: 'sale',
    relatedEntityId: sale.id,
  );
}
```

### Example: Sync Claim Statement

```dart
Future<void> generateAndSyncClaimStatement(ConsignmentClaim claim) async {
  // Generate PDF
  final pdf = await generateClaimStatementPDF(claim);
  final pdfBytes = await pdf.save();
  
  // Sync to Google Drive
  final driveService = GoogleDriveService();
  if (!driveService.isSignedIn) {
    await driveService.signIn();
  }
  
  final fileName = 'Claim_${claim.claimNumber}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
  
  await driveService.autoSyncDocument(
    pdfData: Uint8List.fromList(pdfBytes),
    fileName: fileName,
    fileType: 'claim_statement',
    relatedEntityType: 'claim',
    relatedEntityId: claim.id,
    vendorName: claim.vendorName,
  );
}
```

## File Organization in Google Drive

Files akan auto-organize dalam folders:

- **Invoices/** - All invoice PDFs
- **Claims/** - All claim statements
- **Receipts/** - All receipts

## User Privacy & Security

- ✅ Each user syncs to **their own Google Drive account**
- ✅ Data is **isolated** - users cannot access each other's files
- ✅ OAuth scopes limited to `drive.file` (only files created by app)
- ✅ RLS policies ensure users only see their own sync logs

## Next Steps

1. **Setup OAuth Credentials** (one-time)
2. **Add integration code** to PDF generation flows:
   - Invoices (`delivery_invoice_pdf_generator.dart`)
   - Claims (claim statement generation)
   - Receipts (if applicable)
3. **Test Google Sign-In flow**
4. **Test file upload**
5. **Verify sync logs** in app

## Troubleshooting

### User cannot sign in
- Check OAuth credentials are correct
- Verify redirect URIs match app configuration
- Check Google Cloud Console for API quotas

### Files not uploading
- Check user has granted Drive permissions
- Verify file size limits (Google Drive has limits)
- Check sync logs for error messages

### Sync logs not showing
- Verify RLS policies are working
- Check `business_owner_id` matches `auth.uid()`



