import { api } from "encore.dev/api";

import { supabaseInsert, supabaseUpdate } from "../../pkg/supabase";
import {
  UpsertVendorRequest,
  VendorListResponse,
  VendorResponse,
} from "./types";
import { normalizeVendorPayload } from "./utils";

export const createVendor = api<UpsertVendorRequest, VendorResponse>(
  {
    method: "POST",
    path: "/vendors/create",
  },
  async ({ vendor }) => {
    await supabaseInsert("vendors", normalizeVendorPayload(vendor) as any);
    return { vendor };
  }
);

export const updateVendor = api<UpsertVendorRequest, VendorResponse>(
  {
    method: "POST",
    path: "/vendors/update",
  },
  async ({ vendor }) => {
    await supabaseUpdate("vendors", { id: vendor.id }, normalizeVendorPayload(vendor) as any);
    return { vendor };
  }
);

export const listVendors = api(
  {
    method: "GET",
    path: "/vendors/list",
  },
  async (): Promise<VendorListResponse> => {
    // TODO(p1): fetch and filter vendor list from Supabase
    return { vendors: [] };
  }
);

