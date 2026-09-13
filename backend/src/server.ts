import { createApp } from './app.js';
import { env } from './config/env.js';
import { logger } from './config/logger.js';
import { prisma } from './config/prisma.js';
import { ensureBootstrap } from './services/bootstrap.js';

async function main() {
  await prisma.$connect();
  await ensureBootstrap();
  const app = createApp();
  app.listen(env.port, () => logger.info(`Gamya Mobility API listening on :${env.port}${env.apiPrefix}`));
}

main().catch((e) => { logger.error(e); process.exit(1); });

process.on('SIGTERM', async () => { await prisma.$disconnect(); process.exit(0); });
