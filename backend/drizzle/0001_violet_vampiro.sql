CREATE TYPE "public"."native_auth_handoff_status" AS ENUM('started', 'authenticated', 'exchanged', 'expired');--> statement-breakpoint
CREATE TABLE "native_auth_handoff" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"state" text NOT NULL,
	"code" text,
	"status" "native_auth_handoff_status" DEFAULT 'started' NOT NULL,
	"user_id" text,
	"return_scheme" text NOT NULL,
	"browser_url" text,
	"callback_url" text,
	"requested_at" timestamp with time zone DEFAULT now() NOT NULL,
	"authenticated_at" timestamp with time zone,
	"exchanged_at" timestamp with time zone,
	"expires_at" timestamp with time zone NOT NULL,
	"metadata" jsonb
);
--> statement-breakpoint
CREATE UNIQUE INDEX "native_auth_handoff_state_idx" ON "native_auth_handoff" USING btree ("state");--> statement-breakpoint
CREATE UNIQUE INDEX "native_auth_handoff_code_idx" ON "native_auth_handoff" USING btree ("code");--> statement-breakpoint
CREATE INDEX "native_auth_handoff_status_idx" ON "native_auth_handoff" USING btree ("status");