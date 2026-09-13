import type { Request, Response, NextFunction } from 'express';
import { Prisma } from '@prisma/client';
import { HttpError } from '../utils/errors.js';
import { logger } from '../config/logger.js';

export function notFoundHandler(req: Request, res: Response) {
  res.status(404).json({ success: false, message: `Route ${req.method} ${req.originalUrl} not found` });
}

export function errorHandler(err: unknown, _req: Request, res: Response, _next: NextFunction) {
  if (err instanceof HttpError) {
    return res.status(err.status).json({ success: false, message: err.message, details: err.details });
  }
  if (err instanceof Prisma.PrismaClientKnownRequestError) {
    if (err.code === 'P2002') return res.status(409).json({ success: false, message: 'Duplicate value', details: err.meta });
    if (err.code === 'P2025') return res.status(404).json({ success: false, message: 'Record not found' });
  }
  if (err instanceof Error && err.name === 'MulterError') {
    return res.status(400).json({ success: false, message: err.message });
  }
  logger.error(err);
  const message = err instanceof Error ? err.message : 'Internal server error';
  res.status(500).json({ success: false, message });
}
