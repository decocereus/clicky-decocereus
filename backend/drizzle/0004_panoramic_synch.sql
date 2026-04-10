CREATE TYPE "public"."launch_trial_status" AS ENUM('inactive', 'active', 'armed', 'paywalled', 'unlocked');--> statement-breakpoint
CREATE TABLE "launch_trial_state" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" text NOT NULL,
	"status" "launch_trial_status" DEFAULT 'inactive' NOT NULL,
	"initial_credits" integer NOT NULL,
	"remaining_credits" integer NOT NULL,
	"setup_completed_at" timestamp with time zone,
	"trial_activated_at" timestamp with time zone,
	"last_credit_consumed_at" timestamp with time zone,
	"welcome_prompt_delivered_at" timestamp with time zone,
	"paywall_activated_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE UNIQUE INDEX "launch_trial_state_user_id_idx" ON "launch_trial_state" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "launch_trial_state_status_idx" ON "launch_trial_state" USING btree ("status");