import {
  index,
  integer,
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

export const nativeAuthHandoffStatusEnum = pgEnum("native_auth_handoff_status", [
  "started",
  "authenticated",
  "exchanged",
  "expired",
])

export const launchTrialStatusEnum = pgEnum("launch_trial_status", [
  "inactive",
  "active",
  "armed",
  "paywalled",
  "unlocked",
])

export const webCompanionSessionStatusEnum = pgEnum(
  "web_companion_session_status",
  ["active", "ended", "expired"],
)

export const webCompanionTurnRoleEnum = pgEnum("web_companion_turn_role", [
  "user",
  "assistant",
  "system",
])

export const webCompanionTriggerTypeEnum = pgEnum(
  "web_companion_trigger_type",
  ["bootstrap", "event", "message", "fallback"],
)

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

export const nativeAuthHandoffs = pgTable(
  "native_auth_handoff",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    state: text("state").notNull(),
    code: text("code"),
    sessionToken: text("session_token"),
    status: nativeAuthHandoffStatusEnum("status").default("started").notNull(),
    userId: text("user_id"),
    returnScheme: text("return_scheme").notNull(),
    browserUrl: text("browser_url"),
    callbackUrl: text("callback_url"),
    requestedAt: timestamp("requested_at", { withTimezone: true }).defaultNow().notNull(),
    authenticatedAt: timestamp("authenticated_at", { withTimezone: true }),
    exchangedAt: timestamp("exchanged_at", { withTimezone: true }),
    expiresAt: timestamp("expires_at", { withTimezone: true }).notNull(),
    metadata: jsonb("metadata"),
  },
  (table) => ({
    stateIndex: uniqueIndex("native_auth_handoff_state_idx").on(table.state),
    codeIndex: uniqueIndex("native_auth_handoff_code_idx").on(table.code),
    statusIndex: index("native_auth_handoff_status_idx").on(table.status),
  }),
)

export const launchTrialStates = pgTable(
  "launch_trial_state",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    userId: text("user_id").notNull(),
    status: launchTrialStatusEnum("status").default("inactive").notNull(),
    initialCredits: integer("initial_credits").notNull(),
    remainingCredits: integer("remaining_credits").notNull(),
    setupCompletedAt: timestamp("setup_completed_at", { withTimezone: true }),
    trialActivatedAt: timestamp("trial_activated_at", { withTimezone: true }),
    lastCreditConsumedAt: timestamp("last_credit_consumed_at", { withTimezone: true }),
    welcomePromptDeliveredAt: timestamp("welcome_prompt_delivered_at", { withTimezone: true }),
    paywallActivatedAt: timestamp("paywall_activated_at", { withTimezone: true }),
    createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
    updatedAt: timestamp("updated_at", { withTimezone: true }).defaultNow().notNull(),
  },
  (table) => ({
    userIdIndex: uniqueIndex("launch_trial_state_user_id_idx").on(table.userId),
    statusIndex: index("launch_trial_state_status_idx").on(table.status),
  }),
)

export const webVisitors = pgTable(
  "web_visitor",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    anonymousId: text("anonymous_id").notNull(),
    userId: text("user_id"),
    userAgent: text("user_agent"),
    locale: text("locale"),
    referrerSource: text("referrer_source"),
    firstSeenAt: timestamp("first_seen_at", { withTimezone: true }).defaultNow().notNull(),
    lastSeenAt: timestamp("last_seen_at", { withTimezone: true }).defaultNow().notNull(),
  },
  (table) => ({
    anonymousIdIndex: uniqueIndex("web_visitor_anonymous_id_idx").on(table.anonymousId),
    lastSeenAtIndex: index("web_visitor_last_seen_at_idx").on(table.lastSeenAt),
  }),
)

export const webCompanionSessions = pgTable(
  "web_companion_session",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    visitorId: uuid("visitor_id")
      .notNull()
      .references(() => webVisitors.id, {
        onDelete: "cascade",
      }),
    openclawThreadId: text("openclaw_thread_id"),
    path: text("path").notNull(),
    entrySectionId: text("entry_section_id"),
    currentSectionId: text("current_section_id"),
    status: webCompanionSessionStatusEnum("status").default("active").notNull(),
    metadata: jsonb("metadata"),
    startedAt: timestamp("started_at", { withTimezone: true }).defaultNow().notNull(),
    lastActiveAt: timestamp("last_active_at", { withTimezone: true }).defaultNow().notNull(),
    endedAt: timestamp("ended_at", { withTimezone: true }),
  },
  (table) => ({
    visitorIdIndex: index("web_companion_session_visitor_id_idx").on(table.visitorId),
    statusLastActiveIndex: index("web_companion_session_status_last_active_idx").on(
      table.status,
      table.lastActiveAt,
    ),
  }),
)

export const webCompanionEvents = pgTable(
  "web_companion_event",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    sessionId: uuid("session_id")
      .notNull()
      .references(() => webCompanionSessions.id, {
        onDelete: "cascade",
      }),
    eventType: text("event_type").notNull(),
    sectionId: text("section_id"),
    payload: jsonb("payload"),
    createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
  },
  (table) => ({
    sessionCreatedIndex: index("web_companion_event_session_created_idx").on(
      table.sessionId,
      table.createdAt,
    ),
  }),
)

export const webCompanionTurns = pgTable(
  "web_companion_turn",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    sessionId: uuid("session_id")
      .notNull()
      .references(() => webCompanionSessions.id, {
        onDelete: "cascade",
      }),
    role: webCompanionTurnRoleEnum("role").notNull(),
    triggerType: webCompanionTriggerTypeEnum("trigger_type").notNull(),
    currentSectionId: text("current_section_id"),
    text: text("text").notNull(),
    actions: jsonb("actions"),
    metadata: jsonb("metadata"),
    createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
  },
  (table) => ({
    sessionCreatedIndex: index("web_companion_turn_session_created_idx").on(
      table.sessionId,
      table.createdAt,
    ),
  }),
)
