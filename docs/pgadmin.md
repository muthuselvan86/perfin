# Local pgAdmin console

Run commands from the perfin-v2 repository root.

```bash
npm run pgadmin:up
npm run pgadmin:status
npm run pgadmin:logs
npm run pgadmin:down
```

Open http://localhost:5050. Sign in using PGADMIN_DEFAULT_EMAIL and PGADMIN_DEFAULT_PASSWORD from your local .env. These credentials are for the console, not PostgreSQL. A random local console password was added during setup; do not commit .env.

Expand Servers > Local development > Perfin V2 Local. Enter the perfin_app database password from DATABASE_URL when prompted (URL-decode the password if necessary). The server is preconfigured with host db, port 5432, and database perfin. No database password is stored in servers.json.

Browse Databases > perfin > Schemas > public > Tables. Use Query Tool for SQL. Apply schema changes through reviewed Prisma migrations, rather than manually editing table definitions in pgAdmin.

The console binds only to 127.0.0.1:5050. The tools profile keeps it optional. pgadmin:up also starts PostgreSQL if needed; pgadmin:down stops only pgAdmin. Existing db:down stops the Compose stack. Named volumes preserve database data and pgAdmin settings; do not use down -v to stop services.

The console login is initialized on first startup. Changing the .env password after initialization does not change an existing pgAdmin user's password; use pgAdmin's password-change flow. Server definitions are also imported on initial setup.

Reference: https://www.pgadmin.org/docs/pgadmin4/9.17/container_deployment.html

For the full npm, Prisma, Docker, and database inspection reference, see [commands.md](commands.md).
