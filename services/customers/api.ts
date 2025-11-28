import { api } from "encore.dev/api";
import { Subscription } from "encore.dev/pubsub";

import { supabaseInsert } from "../../pkg/supabase";
import {
  CustomerListResponse,
  CustomerResponse,
  UpsertCustomerRequest,
} from "./types";
import { orderCreatedTopic, OrderCreatedEvent } from "../myshop/api";

export const createCustomer = api<UpsertCustomerRequest, CustomerResponse>(
  {
    method: "POST",
    path: "/customers/create",
  },
  async ({ customer }) => {
    await supabaseInsert("customers", customer as any);
    return { customer };
  }
);

export const listCustomers = api(
  {
    method: "GET",
    path: "/customers/list",
  },
  async (): Promise<CustomerListResponse> => {
    // TODO(p1): query customers scoped to current workspace/account
    return { customers: [] };
  }
);

const _notifyCustomerOnOrder = new Subscription(
  orderCreatedTopic,
  "notify-user-on-order",
  {
    handler: async (event: OrderCreatedEvent) => {
      // TODO(p2): push notification via upcoming notifications service
      return event;
    },
  }
);

