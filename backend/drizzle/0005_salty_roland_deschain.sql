CREATE TYPE "public"."web_companion_session_status" AS ENUM('active', 'ended', 'expired');--> statement-breakpoint
CREATE TYPE "public"."web_companion_trigger_type" AS ENUM('bootstrap', 'event', 'message', 'fallback');--> statement-breakpoint
CREATE TYPE "public"."web_companion_turn_role" AS ENUM('user', 'assistant', 'system');--> statement-breakpoint
CREATE TABLE "web_companion_event" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"session_id" uuid NOT NULL,
	"event_type" text NOT NULL,
	"section_id" text,
	"payload" jsonb,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "web_companion_session" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"visitor_id" uuid NOT NULL,
	"openclaw_thread_id" text,
	"path" text NOT NULL,
	"entry_section_id" text,
	"current_section_id" text,
	"status" "web_companion_session_status" DEFAULT 'active' NOT NULL,
	"metadata" jsonb,
	"started_at" timestamp with time zone DEFAULT now() NOT NULL,
	"last_active_at" timestamp with time zone DEFAULT now() NOT NULL,
	"ended_at" timestamp with time zone
);
--> statement-breakpoint
CREATE TABLE "web_companion_turn" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"session_id" uuid NOT NULL,
	"role" "web_companion_turn_role" NOT NULL,
	"trigger_type" "web_companion_trigger_type" NOT NULL,
	"current_section_id" text,
	"text" text NOT NULL,
	"actions" jsonb,
	"metadata" jsonb,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "web_visitor" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"anonymous_id" text NOT NULL,
	"user_id" text,
	"user_agent" text,
	"locale" text,
	"referrer_source" text,
	"first_seen_at" timestamp with time zone DEFAULT now() NOT NULL,
	"last_seen_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "web_companion_event" ADD CONSTRAINT "web_companion_event_session_id_web_companion_session_id_fk" FOREIGN KEY ("session_id") REFERENCES "public"."web_companion_session"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "web_companion_session" ADD CONSTRAINT "web_companion_session_visitor_id_web_visitor_id_fk" FOREIGN KEY ("visitor_id") REFERENCES "public"."web_visitor"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "web_companion_turn" ADD CONSTRAINT "web_companion_turn_session_id_web_companion_session_id_fk" FOREIGN KEY ("session_id") REFERENCES "public"."web_companion_session"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "web_companion_event_session_created_idx" ON "web_companion_event" USING btree ("session_id","created_at");--> statement-breakpoint
CREATE INDEX "web_companion_session_visitor_id_idx" ON "web_companion_session" USING btree ("visitor_id");--> statement-breakpoint
CREATE INDEX "web_companion_session_status_last_active_idx" ON "web_companion_session" USING btree ("status","last_active_at");--> statement-breakpoint
CREATE INDEX "web_companion_turn_session_created_idx" ON "web_companion_turn" USING btree ("session_id","created_at");--> statement-breakpoint
CREATE UNIQUE INDEX "web_visitor_anonymous_id_idx" ON "web_visitor" USING btree ("anonymous_id");--> statement-breakpoint
CREATE INDEX "web_visitor_last_seen_at_idx" ON "web_visitor" USING btree ("last_seen_at");