# Supabase Storage Bucket Setup: user-documents

## Manual Setup Required

Supabase Storage buckets need to be created manually through the Supabase Dashboard. Follow these steps:

## Steps to Create Bucket

1. **Open Supabase Dashboard**
   - Go to: https://supabase.com/dashboard
   - Select your project

2. **Navigate to Storage**
   - Click on "Storage" in the left sidebar
   - Click "New bucket"

3. **Create Bucket**
   - **Bucket name**: `user-documents`
   - **Public bucket**: ✅ **UNCHECKED** (Private bucket - users can only access their own documents)
   - **File size limit**: 50 MB (or as needed)
   - **Allowed MIME types**: `application/pdf` (optional, for security)

4. **Configure RLS Policies**

   After creating the bucket, run the SQL migration file:
   
   **Option 1: Via Supabase Dashboard (Recommended)**
   - Go to SQL Editor in Supabase Dashboard
   - Open file: `db/migrations/2025-12-09_setup_user_documents_rls_policies.sql`
   - Copy and paste the entire SQL script
   - Click "Run" to execute

   **Option 2: Via Supabase CLI**
   ```bash
   npx supabase migration up
   ```

   The SQL script will automatically create all 4 RLS policies:
   - Users can upload their own documents (INSERT)
   - Users can view their own documents (SELECT)
   - Users can delete their own documents (DELETE)
   - Users can update their own documents (UPDATE)

## Storage Path Structure

Documents are organized by:
```
{userId}/{documentType}/{year}/{month}/{fileName}
```

Example:
```
abc123/invoice/2025/12/Invois_DEL-2512-0020-792453_20251209.pdf
abc123/claim_statement/2025/12/Claim_CL-2025-001_20251209.pdf
```

## Document Types

- `invoice` - Regular invoices
- `thermal_invoice` - Thermal printer invoices
- `receipt_a5` - A5 receipts
- `claim_statement` - Consignment claim statements
- `purchase_order` - Purchase orders
- `profit_loss_report` - Profit & Loss reports

## Notes

- Documents are automatically backed up when PDFs are generated
- Each user can only access their own documents (enforced by RLS)
- Documents are organized by type and date for easy management
- Free tier includes 1 GB storage (sufficient for thousands of PDFs)

