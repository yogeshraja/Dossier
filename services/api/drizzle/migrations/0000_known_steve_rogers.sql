CREATE TABLE `cases` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`public_id` text NOT NULL,
	`dossier_public_id` text NOT NULL,
	`user_public_id` text NOT NULL,
	`kiosk_public_id` text,
	`title` text NOT NULL,
	`category` text NOT NULL,
	`status` text DEFAULT 'intake' NOT NULL,
	`total_amount` real DEFAULT 0 NOT NULL,
	`paid_amount` real DEFAULT 0 NOT NULL,
	`created_at` text NOT NULL,
	`updated_at` text NOT NULL
);
--> statement-breakpoint
CREATE UNIQUE INDEX `cases_public_id_unique` ON `cases` (`public_id`);--> statement-breakpoint
CREATE INDEX `idx_cases_dossier` ON `cases` (`dossier_public_id`);--> statement-breakpoint
CREATE INDEX `idx_cases_status` ON `cases` (`status`);--> statement-breakpoint
CREATE TABLE `dossiers` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`public_id` text NOT NULL,
	`user_public_id` text NOT NULL,
	`kiosk_public_id` text,
	`full_name` text NOT NULL,
	`mobile` text,
	`aadhaar_ref` text,
	`pan_ref` text,
	`metadata_json` text,
	`created_at` text NOT NULL,
	`updated_at` text NOT NULL
);
--> statement-breakpoint
CREATE UNIQUE INDEX `dossiers_public_id_unique` ON `dossiers` (`public_id`);--> statement-breakpoint
CREATE INDEX `idx_dossiers_user` ON `dossiers` (`user_public_id`);--> statement-breakpoint
CREATE INDEX `idx_dossiers_mobile` ON `dossiers` (`mobile`);--> statement-breakpoint
CREATE TABLE `kiosks` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`public_id` text NOT NULL,
	`name` text NOT NULL,
	`owner_public_id` text NOT NULL,
	`address` text,
	`phone` text,
	`upi_vpa` text,
	`license_key` text,
	`status` text DEFAULT 'active' NOT NULL,
	`is_active` integer DEFAULT 1 NOT NULL,
	`is_suspended` integer DEFAULT 0 NOT NULL,
	`suspended_at` text,
	`suspended_reason` text,
	`deleted_at` text,
	`created_at` text NOT NULL,
	`updated_at` text NOT NULL
);
--> statement-breakpoint
CREATE UNIQUE INDEX `kiosks_public_id_unique` ON `kiosks` (`public_id`);--> statement-breakpoint
CREATE UNIQUE INDEX `kiosks_license_key_unique` ON `kiosks` (`license_key`);--> statement-breakpoint
CREATE INDEX `idx_kiosks_public_id` ON `kiosks` (`public_id`);--> statement-breakpoint
CREATE INDEX `idx_kiosks_owner` ON `kiosks` (`owner_public_id`);--> statement-breakpoint
CREATE INDEX `idx_kiosks_status` ON `kiosks` (`status`);--> statement-breakpoint
CREATE TABLE `otp_verifications` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`public_id` text NOT NULL,
	`mobile` text NOT NULL,
	`otp_hash` text NOT NULL,
	`expires_at` text NOT NULL,
	`attempts` integer DEFAULT 0 NOT NULL,
	`is_verified` integer DEFAULT 0 NOT NULL,
	`created_at` text NOT NULL
);
--> statement-breakpoint
CREATE UNIQUE INDEX `otp_verifications_public_id_unique` ON `otp_verifications` (`public_id`);--> statement-breakpoint
CREATE INDEX `idx_otp_mobile` ON `otp_verifications` (`mobile`);--> statement-breakpoint
CREATE INDEX `idx_otp_expires` ON `otp_verifications` (`expires_at`);--> statement-breakpoint
CREATE TABLE `sessions` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`public_id` text NOT NULL,
	`user_public_id` text NOT NULL,
	`token` text NOT NULL,
	`expires_at` text NOT NULL,
	`created_at` text NOT NULL
);
--> statement-breakpoint
CREATE UNIQUE INDEX `sessions_public_id_unique` ON `sessions` (`public_id`);--> statement-breakpoint
CREATE UNIQUE INDEX `sessions_token_unique` ON `sessions` (`token`);--> statement-breakpoint
CREATE INDEX `idx_sessions_token` ON `sessions` (`token`);--> statement-breakpoint
CREATE INDEX `idx_sessions_user` ON `sessions` (`user_public_id`);--> statement-breakpoint
CREATE TABLE `sync_items` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`public_id` text NOT NULL,
	`user_public_id` text NOT NULL,
	`kiosk_public_id` text,
	`entity_type` text NOT NULL,
	`entity_id` text NOT NULL,
	`action` text NOT NULL,
	`payload` text NOT NULL,
	`client_timestamp` text NOT NULL,
	`server_timestamp` text NOT NULL
);
--> statement-breakpoint
CREATE UNIQUE INDEX `sync_items_public_id_unique` ON `sync_items` (`public_id`);--> statement-breakpoint
CREATE INDEX `idx_sync_user_time` ON `sync_items` (`user_public_id`,`server_timestamp`);--> statement-breakpoint
CREATE INDEX `idx_sync_kiosk_time` ON `sync_items` (`kiosk_public_id`,`server_timestamp`);--> statement-breakpoint
CREATE TABLE `users` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`public_id` text NOT NULL,
	`kiosk_public_id` text,
	`name` text NOT NULL,
	`email` text,
	`mobile` text,
	`is_mobile_verified` integer DEFAULT 0 NOT NULL,
	`role` text DEFAULT 'operator' NOT NULL,
	`pin_hash` text NOT NULL,
	`password_hash` text,
	`auth_provider` text DEFAULT 'local',
	`google_id` text,
	`avatar_url` text,
	`status` text DEFAULT 'active' NOT NULL,
	`is_active` integer DEFAULT 1 NOT NULL,
	`is_suspended` integer DEFAULT 0 NOT NULL,
	`suspended_at` text,
	`suspended_reason` text,
	`deleted_at` text,
	`created_at` text NOT NULL,
	`updated_at` text NOT NULL
);
--> statement-breakpoint
CREATE UNIQUE INDEX `users_public_id_unique` ON `users` (`public_id`);--> statement-breakpoint
CREATE INDEX `idx_users_public_id` ON `users` (`public_id`);--> statement-breakpoint
CREATE INDEX `idx_users_email` ON `users` (`email`);--> statement-breakpoint
CREATE INDEX `idx_users_mobile` ON `users` (`mobile`);--> statement-breakpoint
CREATE INDEX `idx_users_kiosk` ON `users` (`kiosk_public_id`);--> statement-breakpoint
CREATE INDEX `idx_users_status` ON `users` (`status`);