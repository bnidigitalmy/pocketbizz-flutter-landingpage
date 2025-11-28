import { Topic } from "encore.dev/pubsub";

export interface BookingCreatedEvent {
  bookingId: string;
  businessOwnerId: string;
  status: string;
}

export interface BookingStatusUpdatedEvent {
  bookingId: string;
  businessOwnerId: string;
  status: string;
}

export const OnBookingCreated = new Topic<BookingCreatedEvent>("booking-created", {
  deliveryGuarantee: "at-least-once",
});
export const OnBookingStatusUpdated = new Topic<BookingStatusUpdatedEvent>(
  "booking-status-updated",
  { deliveryGuarantee: "at-least-once" }
);

