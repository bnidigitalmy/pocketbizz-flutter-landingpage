import { api, APIError, type Header } from "encore.dev/api";

import { resolveAuthContext } from "../../pkg/auth";
import { createInventoryBatchFromGRNItem } from "../purchase/utils";
import type { CreateGRNItemInput } from "../purchase/types";
import type {
  AssignProductRequest,
  CreateSupplierPORequest,
  CreateSupplierRequest,
  DeleteSupplierRequest,
  InventoryBatchSummary,
  ReceiveSupplierPORequest,
  ReceiveSupplierPOResponse,
  Supplier,
  SupplierListResponse,
  SupplierPO,
  SupplierPOItem,
  SupplierPOResponse,
  SupplierProduct,
  SupplierProductsResponse,
  SupplierResponse,
  UpdateSupplierRequest,
} from "./types";
import {
  PURCHASE_ORDERS_TABLE,
  PURCHASE_ORDER_ITEMS_TABLE,
  SUPPLIER_PRODUCTS_TABLE,
  SUPPLIERS_TABLE,
  ensurePositiveNumber,
  ensureProductOwnership,
  ensureSupplierOwnership,
  fetchSupplierPOById,
  generateReference,
  mapSupplier,
  mapSupplierPO,
  mapSupplierProduct,
  sanitizeString,
} from "./utils";

interface AuthorizedOnly {
  authorization: Header<"Authorization">;
}

const normalizeSupplierPayload = (input: {
  name?: string;
  phone?: string;
  address?: string;
  commission?: number;
}) => {
  const name = sanitizeString(input.name);
  if (!name) {
    throw APIError.invalidArgument("Supplier name is required");
  }
  const commission = Number(input.commission ?? 0);
  if (!Number.isFinite(commission) || commission < 0) {
    throw APIError.invalidArgument("Commission must be zero or greater");
  }
  return {
    name,
    phone: sanitizeString(input.phone) ?? null,
    address: sanitizeString(input.address) ?? null,
    commission,
  };
};

const normalizePOItems = (items: CreateSupplierPORequest["items"]) => {
  if (!Array.isArray(items) || !items.length) {
    throw APIError.invalidArgument("At least one PO item is required");
  }
  return items.map((item, index) => {
    const productId = sanitizeString(item.stockItemId);
    if (!productId) {
      throw APIError.invalidArgument(`items[${index}].stockItemId is required`);
    }
    const qty = ensurePositiveNumber(item.qty, `items[${index}].qty`);
    const unit = sanitizeString(item.unit);
    if (!unit) {
      throw APIError.invalidArgument(`items[${index}].unit is required`);
    }
    const unitPrice = Number(item.unitPrice ?? 0);
    if (!Number.isFinite(unitPrice) || unitPrice < 0) {
      throw APIError.invalidArgument(`items[${index}].unitPrice must be zero or greater`);
    }
    return {
      productId,
      qty,
      unit,
      unitPrice,
    };
  });
};

export const createSupplier = api<CreateSupplierRequest, SupplierResponse>(
  { method: "POST", path: "/suppliers/create" },
  async ({ authorization, supplier }) => {
    const { client, ownerId } = resolveAuthContext(authorization);
    const normalized = normalizeSupplierPayload(supplier);

    const { data, error } = await client
      .from(SUPPLIERS_TABLE)
      .insert({
        business_owner_id: ownerId,
        name: normalized.name,
        phone: normalized.phone,
        address: normalized.address,
        commission: normalized.commission,
      })
      .select("*")
      .single();

    if (error) {
      throw APIError.internal(error.message);
    }

    return { success: true, data: { supplier: mapSupplier(data) } };
  }
);

export const updateSupplier = api<UpdateSupplierRequest, SupplierResponse>(
  { method: "POST", path: "/suppliers/update" },
  async ({ authorization, supplier }) => {
    const { client, ownerId } = resolveAuthContext(authorization);
    const supplierId = sanitizeString(supplier.id);
    if (!supplierId) {
      throw APIError.invalidArgument("supplier.id is required");
    }
    await ensureSupplierOwnership(client, ownerId, supplierId);

    const updates = normalizeSupplierPayload({
      name: supplier.name,
      phone: supplier.phone,
      address: supplier.address,
      commission: supplier.commission,
    });

    const { data, error } = await client
      .from(SUPPLIERS_TABLE)
      .update({
        name: updates.name,
        phone: updates.phone,
        address: updates.address,
        commission: updates.commission,
        updated_at: new Date().toISOString(),
      })
      .eq("business_owner_id", ownerId)
      .eq("id", supplierId)
      .select("*")
      .single();

    if (error) {
      throw APIError.internal(error.message);
    }

    return { success: true, data: { supplier: mapSupplier(data) } };
  }
);

export const deleteSupplier = api<DeleteSupplierRequest, SupplierResponse>(
  { method: "POST", path: "/suppliers/delete" },
  async ({ authorization, id }) => {
    const { client, ownerId } = resolveAuthContext(authorization);
    const supplierId = sanitizeString(id);
    if (!supplierId) {
      throw APIError.invalidArgument("id is required");
    }
    await ensureSupplierOwnership(client, ownerId, supplierId);
    const { error } = await client
      .from(SUPPLIERS_TABLE)
      .delete()
      .eq("business_owner_id", ownerId)
      .eq("id", supplierId);
    if (error) {
      throw APIError.internal(error.message);
    }
    return { success: true };
  }
);

export const listSuppliers = api<AuthorizedOnly, SupplierListResponse>(
  { method: "GET", path: "/suppliers/list" },
  async ({ authorization }) => {
    const { client, ownerId } = resolveAuthContext(authorization);
    const { data, error } = await client
      .from(SUPPLIERS_TABLE)
      .select("*")
      .eq("business_owner_id", ownerId)
      .order("created_at", { ascending: false });

    if (error) {
      throw APIError.internal(error.message);
    }

    return {
      success: true,
      data: { suppliers: (data ?? []).map((row) => mapSupplier(row)) },
    };
  }
);

export const assignProduct = api<AssignProductRequest, SupplierProductsResponse>(
  { method: "POST", path: "/suppliers/assign-product" },
  async ({ authorization, supplierId, productId, commission }) => {
    const { client, ownerId } = resolveAuthContext(authorization);
    const normalizedSupplierId = sanitizeString(supplierId);
    const normalizedProductId = sanitizeString(productId);
    if (!normalizedSupplierId || !normalizedProductId) {
      throw APIError.invalidArgument("supplierId and productId are required");
    }
    await ensureSupplierOwnership(client, ownerId, normalizedSupplierId);
    await ensureProductOwnership(client, ownerId, normalizedProductId);

    const { data, error } = await client
      .from(SUPPLIER_PRODUCTS_TABLE)
      .upsert(
        {
          business_owner_id: ownerId,
          supplier_id: normalizedSupplierId,
          product_id: normalizedProductId,
          commission: Number(commission ?? 0),
        },
        { onConflict: "supplier_id,product_id" }
      )
      .select(
        "id, product_id, commission, created_at, updated_at, products!inner(name)"
      )
      .single();

    if (error) {
      throw APIError.internal(error.message);
    }

    const mapped: SupplierProduct = {
      id: data.id,
      productId: data.product_id,
      productName: (data.products as any)?.name ?? "Product",
      commission: Number(data.commission ?? 0),
      createdAt: data.created_at,
      updatedAt: data.updated_at,
    };

    return { success: true, data: { products: [mapped] } };
  }
);

interface SupplierProductsRequest extends AuthorizedOnly {
  id: string;
}

export const supplierProducts = api<SupplierProductsRequest, SupplierProductsResponse>(
  { method: "GET", path: "/suppliers/:id/products" },
  async ({ authorization, id }) => {
    const { client, ownerId } = resolveAuthContext(authorization);
    const supplierId = sanitizeString(id);
    if (!supplierId) {
      throw APIError.invalidArgument("id is required");
    }
    await ensureSupplierOwnership(client, ownerId, supplierId);

    const { data, error } = await client
      .from(SUPPLIER_PRODUCTS_TABLE)
      .select(
        "id, product_id, commission, created_at, updated_at, products!inner(name)"
      )
      .eq("business_owner_id", ownerId)
      .eq("supplier_id", supplierId)
      .order("created_at", { ascending: false });

    if (error) {
      throw APIError.internal(error.message);
    }

    const mapped = (data ?? []).map((row) =>
      mapSupplierProduct({
        id: row.id,
        product_id: row.product_id,
        product_name: (row.products as any)?.name ?? "Product",
        commission: row.commission,
        created_at: row.created_at,
        updated_at: row.updated_at,
      })
    );

    return { success: true, data: { products: mapped } };
  }
);

export const createSupplierPO = api<CreateSupplierPORequest, SupplierPOResponse>(
  { method: "POST", path: "/suppliers/po/create" },
  async ({ authorization, supplierId, items, notes }) => {
    const { client, ownerId } = resolveAuthContext(authorization);
    const normalizedSupplierId = sanitizeString(supplierId);
    if (!normalizedSupplierId) {
      throw APIError.invalidArgument("supplierId is required");
    }
    await ensureSupplierOwnership(client, ownerId, normalizedSupplierId);
    const normalizedItems = normalizePOItems(items);
    for (const item of normalizedItems) {
      await ensureProductOwnership(client, ownerId, item.productId);
    }

    const totalValue = normalizedItems.reduce(
      (sum, item) => sum + item.qty * item.unitPrice,
      0
    );
    const reference = generateReference("SPO");

    const { data: poRow, error: poError } = await client
      .from(PURCHASE_ORDERS_TABLE)
      .insert({
        business_owner_id: ownerId,
        supplier_id: normalizedSupplierId,
        reference,
        status: "pending",
        total_value: Number(totalValue.toFixed(2)),
        notes: sanitizeString(notes) ?? null,
      })
      .select("*")
      .single();

    if (poError) {
      throw APIError.internal(poError.message);
    }

    const poId = poRow.id as string;
    const itemPayload = normalizedItems.map((item) => ({
      po_id: poId,
      product_id: item.productId,
      description: null,
      qty_ordered: item.qty,
      qty_received: 0,
      unit: item.unit,
      unit_price: item.unitPrice,
      total_price: Number((item.qty * item.unitPrice).toFixed(4)),
    }));

    const { error: itemsError } = await client
      .from(PURCHASE_ORDER_ITEMS_TABLE)
      .insert(itemPayload);
    if (itemsError) {
      throw APIError.internal(itemsError.message);
    }

    const { order, items: poItems } = await fetchSupplierPOById(client, ownerId, poId);
    return {
      success: true,
      data: { purchaseOrder: mapSupplierPO(order, poItems) },
    };
  }
);

export const receiveSupplierPO = api<ReceiveSupplierPORequest, ReceiveSupplierPOResponse>(
  { method: "POST", path: "/suppliers/po/receive" },
  async ({ authorization, poId }) => {
    const { client, ownerId } = resolveAuthContext(authorization);
    const normalizedPoId = sanitizeString(poId);
    if (!normalizedPoId) {
      throw APIError.invalidArgument("poId is required");
    }

    const { order, items } = await fetchSupplierPOById(client, ownerId, normalizedPoId);
    if (order.status === "received") {
      throw APIError.failedPrecondition("Purchase order already received");
    }

    const inventoryResults: InventoryBatchSummary[] = [];
    for (const item of items) {
      const payload: CreateGRNItemInput = {
        product_id: item.product_id ?? undefined,
        ingredient_id: undefined,
        qty_received: item.qty_ordered,
        unit: item.unit ?? "unit",
        unit_price: item.unit_price ?? 0,
      };
      const batch = await createInventoryBatchFromGRNItem(client, ownerId, payload);
      inventoryResults?.push(batch);

      const { error: updateItemError } = await client
        .from(PURCHASE_ORDER_ITEMS_TABLE)
        .update({
          qty_received: item.qty_ordered,
          updated_at: new Date().toISOString(),
        })
        .eq("id", item.id);
      if (updateItemError) {
        throw APIError.internal(updateItemError.message);
      }
    }

    const { error: updatePoError } = await client
      .from(PURCHASE_ORDERS_TABLE)
      .update({
        status: "received",
        updated_at: new Date().toISOString(),
      })
      .eq("id", normalizedPoId);

    if (updatePoError) {
      throw APIError.internal(updatePoError.message);
    }

    const refreshed = await fetchSupplierPOById(client, ownerId, normalizedPoId);
    // TODO: support partial receipts and shopping list reconciliation.
    return {
      success: true,
      data: {
        purchaseOrder: mapSupplierPO(refreshed.order, refreshed.items),
        inventoryBatches: inventoryResults ?? [],
      },
    };
  }
);

