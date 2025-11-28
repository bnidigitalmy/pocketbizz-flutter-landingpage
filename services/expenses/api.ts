import crypto from "node:crypto";

import { api, APIError } from "encore.dev/api";
import { CronJob } from "encore.dev/cron";
import { Subscription, Topic } from "encore.dev/pubsub";

import {
  supabaseInsert,
  supabaseQuery,
  supabaseSelect,
  supabaseUpdate,
  supabaseUploadFile,
} from "../../pkg/supabase";
import {
  AddExpenseRequest,
  AddExpenseResponse,
  ExpenseListResponse,
  ExpenseReceiptUploadedEvent,
  UploadOCRRequest,
  UploadOCRResponse,
} from "./types";
import {
  DEFAULT_OWNER_ID,
  EXPENSES_TABLE,
  ExpenseRow,
  OCR_TABLE,
  RECEIPTS_BUCKET,
  buildExpenseInsertPayload,
  buildReceiptStoragePath,
  mapExpenseRow,
} from "./utils";

const performPlaceholderOCR = (filePath: string) => {
  const amount = Number((Math.random() * 200 + 5).toFixed(2));
  return {
    amount,
    category: "UNCATEGORIZED",
    currency: "MYR",
    expenseDate: new Date().toISOString().slice(0, 10),
    notes: `OCR import from ${filePath}`,
  };
};

export const expenseReceiptUploadedTopic =
  new Topic<ExpenseReceiptUploadedEvent>("expense-receipt-uploaded", {
    deliveryGuarantee: "at-least-once",
  });

export const addExpense = api<AddExpenseRequest, AddExpenseResponse>(
  {
    method: "POST",
    path: "/expenses/add",
  },
  async ({ expense }) => {
    await supabaseInsert(
      EXPENSES_TABLE,
      buildExpenseInsertPayload({
        ownerId: DEFAULT_OWNER_ID,
        category: expense.category,
        amount: expense.amount,
        currency: expense.currency,
        expenseDate: expense.expenseDate,
        notes: expense.notes,
        vendorId: expense.vendorId,
        ocrReceiptId: expense.ocrReceiptId,
      })
    );
    return { expense };
  }
);

export const uploadReceipt = api<UploadOCRRequest, UploadOCRResponse>(
  {
    method: "POST",
    path: "/expenses/upload-receipt",
  },
  async ({ ownerId, fileName, contentType, data }) => {
    const normalizedOwner = ownerId?.trim() || DEFAULT_OWNER_ID;
    const cleanedFileName = fileName?.trim();
    if (!cleanedFileName) {
      throw APIError.invalidArgument("fileName is required");
    }
    if (!data) {
      throw APIError.invalidArgument("data (base64) is required");
    }

    const storagePath = buildReceiptStoragePath(
      normalizedOwner,
      cleanedFileName
    );

    await supabaseUploadFile({
      bucket: RECEIPTS_BUCKET,
      path: storagePath,
      file: Buffer.from(data, "base64"),
      contentType: contentType ?? "application/octet-stream",
    });

    const receiptId = crypto.randomUUID();
    await supabaseInsert(OCR_TABLE, {
      id: receiptId,
      owner_id: normalizedOwner,
      file_path: storagePath,
      status: "pending",
    });

    await expenseReceiptUploadedTopic.publish({
      receiptId,
      ownerId: normalizedOwner,
      filePath: storagePath,
      contentType,
    });

    return { receiptId, status: "pending" };
  }
);

export const listExpenses = api(
  {
    method: "GET",
    path: "/expenses/list",
  },
  async (): Promise<ExpenseListResponse> => {
    const rows = await supabaseSelect<ExpenseRow>(EXPENSES_TABLE, (query) =>
      query.order("expense_date", { ascending: false }).limit(100)
    );
    return {
      expenses: rows.map(mapExpenseRow),
    };
  }
);

export const ocrCleanup = api(
  {
    method: "POST",
    path: "/ocr/cleanup",
  },
  async (): Promise<{ removed: number }> => {
    // TODO(p2): remove expired OCR artifacts from storage
    return { removed: 0 };
  }
);

const _ocrCleanupCron = new CronJob("ocr-cleanup", {
  title: "OCR artifact cleanup",
  every: "24h",
  endpoint: ocrCleanup,
});

const _processReceiptSubscription = new Subscription(
  expenseReceiptUploadedTopic,
  "expense-save-from-ocr",
  {
    handler: async (event: ExpenseReceiptUploadedEvent) => {
      const ocrResult = performPlaceholderOCR(event.filePath);

      const expenseRow = await supabaseQuery<ExpenseRow>(async (client) => {
        const { data, error } = await client
          .from(EXPENSES_TABLE)
          .insert(
            buildExpenseInsertPayload({
              ownerId: event.ownerId,
              category: ocrResult.category,
              amount: ocrResult.amount,
              currency: ocrResult.currency,
              expenseDate: ocrResult.expenseDate,
              notes: ocrResult.notes,
              ocrReceiptId: event.receiptId,
            })
          )
          .select("*")
          .single();

        if (error) {
          throw APIError.internal(error.message);
        }
        return data as ExpenseRow;
      });

      await supabaseUpdate(
        OCR_TABLE,
        { id: event.receiptId },
        {
          status: "completed",
          amount: ocrResult.amount,
          currency: ocrResult.currency,
          expense_date: ocrResult.expenseDate,
          detected_text: "Placeholder OCR output",
        } as any
      );

      return mapExpenseRow(expenseRow);
    },
  }
);

