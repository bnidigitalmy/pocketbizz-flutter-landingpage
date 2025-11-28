import { Topic } from "encore.dev/pubsub";

export interface POCreatedEvent {
  po_id: string;
  business_owner_id: string;
}

export interface POApprovedEvent {
  po_id: string;
  business_owner_id: string;
}

export interface GRNCreatedEvent {
  grn_id: string;
  business_owner_id: string;
}

export const OnPOCreated = new Topic<POCreatedEvent>("OnPOCreated", {
  deliveryGuarantee: "at-least-once",
});
export const OnPOApproved = new Topic<POApprovedEvent>("OnPOApproved", {
  deliveryGuarantee: "at-least-once",
});
export const OnGRNCreated = new Topic<GRNCreatedEvent>("OnGRNCreated", {
  deliveryGuarantee: "at-least-once",
});

