import {
  index,
  jsonb,
  pgEnum,
  pgTable,
  text,
  timestamp,
  uniqueIndex,
  uuid,
} from "drizzle-orm/pg-core"

export const entitlementStatusEnum = pgEnum("entitlement_status", [
  "inactive",
  "active",
  "revoked",
  "refunded",
])

export const billingProviderEnum = pgEnum("billing_provider", ["polar"])

export const checkoutStatusEnum = pgEnum("checkout_status", [
  "created",
  "completed",
  "expired",
  "canceled",
])

export const webhookProcessingStatusEnum = pgEnum("webhook_processing_status", [
  "received",
  "processed",
  "failed",
])

export const polarCustomerLinks = pgTable(
  "polar_customer_link",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    userId: text("user_id").notNull(),
    polarCustomerId: text("polar_customer_id").notNull(),
    emailAtLinkTime: text("email_at_link_time"),
    createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
    updatedAt: timestamp("updated_at", { withTimezone: true }).defaultNow().notNull(),
  },
  (table) => ({
    userIdIndex: uniqueIndex("polar_customer_link_user_id_idx").on(table.userId),
    polarCustomerIdIndex: uniqueIndex("polar_customer_link_customer_id_idx").on(table.polarCustomerId),
  }),
)

export const entitlements = pgTable(
  "entitlement",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    userId: text("user_id").notNull(),
    productKey: text("product_key").notNull(),
    status: entitlementStatusEnum("status").notNull(),
    source: billingProviderEnum("source").notNull(),
    grantedAt: timestamp("granted_at", { withTimezone: true }),
    refreshedAt: timestamp("refreshed_at", { withTimezone: true }).defaultNow().notNull(),
    expiresAt: timestamp("expires_at", { withTimezone: true }),
    rawReference: text("raw_reference"),
    metadata: jsonb("metadata"),
    createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
    updatedAt: timestamp("updated_at", { withTimezone: true }).defaultNow().notNull(),
  },
  (table) => ({
    userProductIndex: uniqueIndex("entitlement_user_product_idx").on(table.userId, table.productKey),
    userStatusIndex: index("entitlement_user_status_idx").on(table.userId, table.status),
  }),
)

export const billingWebhookEvents = pgTable(
  "billing_webhook_event",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    provider: billingProviderEnum("provider").notNull(),
    eventId: text("event_id").notNull(),
    eventType: text("event_type").notNull(),
    payload: jsonb("payload"),
    receivedAt: timestamp("received_at", { withTimezone: true }).defaultNow().notNull(),
    processedAt: timestamp("processed_at", { withTimezone: true }),
    status: webhookProcessingStatusEnum("status").default("received").notNull(),
    lastError: text("last_error"),
  },
  (table) => ({
    providerEventIndex: uniqueIndex("billing_webhook_provider_event_idx").on(table.provider, table.eventId),
  }),
)

export const checkoutSessionAudits = pgTable(
  "checkout_session_audit",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    userId: text("user_id").notNull(),
    provider: billingProviderEnum("provider").notNull(),
    providerCheckoutId: text("provider_checkout_id"),
    productKey: text("product_key").notNull(),
    status: checkoutStatusEnum("status").default("created").notNull(),
    createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
    completedAt: timestamp("completed_at", { withTimezone: true }),
    metadata: jsonb("metadata"),
  },
  (table) => ({
    userCreatedIndex: index("checkout_session_audit_user_created_idx").on(table.userId, table.createdAt),
  }),
)
