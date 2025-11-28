import { api } from "encore.dev/api";
import { Topic } from "encore.dev/pubsub";

import { supabaseInsert } from "../../pkg/supabase";
import {
  CreateOrderRequest,
  OrderCreatedEvent,
  OrderListResponse,
  OrderResponse,
} from "./types";
import { generateOrderReference } from "./utils";

export type { OrderCreatedEvent } from "./types";

export const orderCreatedTopic = new Topic<OrderCreatedEvent>("myshop-order", {
  deliveryGuarantee: "at-least-once",
});

export const createOrder = api<CreateOrderRequest, OrderResponse>(
  {
    method: "POST",
    path: "/myshop/order",
  },
  async ({ order }) => {
    const reference = generateOrderReference(order);
    await supabaseInsert("myshop_orders", { ...order, reference } as any);

    await orderCreatedTopic.publish({
      orderId: order.id,
      customerId: order.customerId,
      total: order.total,
    });

    return { order: { ...order, reference } };
  }
);

export const listOrders = api(
  {
    method: "GET",
    path: "/myshop/orders",
  },
  async (): Promise<OrderListResponse> => {
    // TODO(p1): fetch orders with pagination and filtering
    return { orders: [] };
  }
);

