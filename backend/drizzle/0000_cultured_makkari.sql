CREATE TYPE "public"."billing_provider" AS ENUM('polar');--> statement-breakpoint
CREATE TYPE "public"."checkout_status" AS ENUM('created', 'completed', 'expired', 'canceled');--> statement-breakpoint
CREATE TYPE "public"."entitlement_status" AS ENUM('inactive', 'active', 'revoked', 'refunded');--> statement-breakpoint
CREATE TYPE "public"."webhook_processing_status" AS ENUM('received', 'processed', 'failed');--> statement-breakpoint
CREATE TABLE "billing_webhook_event" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"provider" "billing_provider" NOT NULL,
	"event_id" text NOT NULL,
	"event_type" text NOT NULL,
	"payload" jsonb,
	"received_at" timestamp with time zone DEFAULT now() NOT NULL,
	"processed_at" timestamp with time zone,
	"status" "webhook_processing_status" DEFAULT 'received' NOT NULL,
	"last_error" text
);
--> statement-breakpoint
CREATE TABLE "checkout_session_audit" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" text NOT NULL,
	"provider" "billing_provider" NOT NULL,
	"provider_checkout_id" text,
	"product_key" text NOT NULL,
	"status" "checkout_status" DEFAULT 'created' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"completed_at" timestamp with time zone,
	"metadata" jsonb
);
--> statement-breakpoint
CREATE TABLE "entitlement" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" text NOT NULL,
	"product_key" text NOT NULL,
	"status" "entitlement_status" NOT NULL,
	"source" "billing_provider" NOT NULL,
	"granted_at" timestamp with time zone,
	"refreshed_at" timestamp with time zone DEFAULT now() NOT NULL,
	"expires_at" timestamp with time zone,
	"raw_reference" text,
	"metadata" jsonb,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "polar_customer_link" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" text NOT NULL,
	"polar_customer_id" text NOT NULL,
	"email_at_link_time" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE UNIQUE INDEX "billing_webhook_provider_event_idx" ON "billing_webhook_event" USING btree ("provider","event_id");--> statement-breakpoint
CREATE INDEX "checkout_session_audit_user_created_idx" ON "checkout_session_audit" USING btree ("user_id","created_at");--> statement-breakpoint
CREATE UNIQUE INDEX "entitlement_user_product_idx" ON "entitlement" USING btree ("user_id","product_key");--> statement-breakpoint
CREATE INDEX "entitlement_user_status_idx" ON "entitlement" USING btree ("user_id","status");--> statement-breakpoint
CREATE UNIQUE INDEX "polar_customer_link_user_id_idx" ON "polar_customer_link" USING btree ("user_id");--> statement-breakpoint
CREATE UNIQUE INDEX "polar_customer_link_customer_id_idx" ON "polar_customer_link" USING btree ("polar_customer_id");