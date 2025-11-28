import { Topic } from "encore.dev/pubsub";

export interface DriveFileSyncedEvent {
  logId: string;
  businessOwnerId: string;
  fileType: string;
}

export const OnDriveFileSynced = new Topic<DriveFileSyncedEvent>("drive-file-synced", {
  deliveryGuarantee: "at-least-once",
});

