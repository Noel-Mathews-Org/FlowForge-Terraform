-- ============================================================
-- FlowForge Managed Identity DB Role Setup
-- Run this AFTER Terraform applies the pgaadauth extension
-- ============================================================

-- Setup flowforge-dev
\c flowforge-dev

SELECT * FROM pgaadauth_create_principal('mi-flowforge-app-dev', false, false);
GRANT CONNECT ON DATABASE "flowforge-dev" TO "mi-flowforge-app-dev";
GRANT USAGE ON SCHEMA public TO "mi-flowforge-app-dev";
GRANT ALL ON ALL TABLES IN SCHEMA public TO "mi-flowforge-app-dev";
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO "mi-flowforge-app-dev";
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO "mi-flowforge-app-dev";
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO "mi-flowforge-app-dev";

SELECT * FROM pgaadauth_create_principal('mi-ai-dev-m9mp04', false, false);
GRANT CONNECT ON DATABASE "flowforge-dev" TO "mi-ai-dev-m9mp04";
GRANT USAGE ON SCHEMA public TO "mi-ai-dev-m9mp04";
GRANT ALL ON ALL TABLES IN SCHEMA public TO "mi-ai-dev-m9mp04";
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO "mi-ai-dev-m9mp04";
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO "mi-ai-dev-m9mp04";
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO "mi-ai-dev-m9mp04";

-- Setup flowforge-prod
\c flowforge-prod

SELECT * FROM pgaadauth_create_principal('mi-flowforge-app-prod', false, false);
GRANT CONNECT ON DATABASE "flowforge-prod" TO "mi-flowforge-app-prod";
GRANT USAGE ON SCHEMA public TO "mi-flowforge-app-prod";
GRANT ALL ON ALL TABLES IN SCHEMA public TO "mi-flowforge-app-prod";
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO "mi-flowforge-app-prod";
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO "mi-flowforge-app-prod";
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO "mi-flowforge-app-prod";

SELECT * FROM pgaadauth_create_principal('mi-ai-prod-m9mp04', false, false);
GRANT CONNECT ON DATABASE "flowforge-prod" TO "mi-ai-prod-m9mp04";
GRANT USAGE ON SCHEMA public TO "mi-ai-prod-m9mp04";
GRANT ALL ON ALL TABLES IN SCHEMA public TO "mi-ai-prod-m9mp04";
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO "mi-ai-prod-m9mp04";
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO "mi-ai-prod-m9mp04";
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO "mi-ai-prod-m9mp04";

