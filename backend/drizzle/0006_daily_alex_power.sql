CREATE TYPE "public"."rate_limit_scope" AS ENUM('web_companion_sessions', 'web_companion_events', 'web_companion_messages', 'web_companion_transcribe');--> statement-breakpoint
CREATE TABLE "rate_limit_window" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"scope" "rate_limit_scope" NOT NULL,
	"key" text NOT NULL,
	"window_start" timestamp with time zone NOT NULL,
	"count" integer DEFAULT 1 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE UNIQUE INDEX "rate_limit_window_scope_key_window_idx" ON "rate_limit_window" USING btree ("scope","key","window_start");--> statement-breakpoint
CREATE INDEX "rate_limit_window_scope_updated_at_idx" ON "rate_limit_window" USING btree ("scope","updated_at");