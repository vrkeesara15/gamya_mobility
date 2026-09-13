import type { Request } from 'express';

export interface PageParams { page: number; pageSize: number; skip: number; take: number; }

export function pageParams(req: Request, defaultSize = 10, max = 200): PageParams {
  const page = Math.max(1, Number(req.query.page ?? 1) || 1);
  const pageSize = Math.min(max, Math.max(1, Number(req.query.pageSize ?? defaultSize) || defaultSize));
  return { page, pageSize, skip: (page - 1) * pageSize, take: pageSize };
}

export function paged<T>(items: T[], total: number, p: PageParams) {
  return { items, total, page: p.page, pageSize: p.pageSize, totalPages: Math.max(1, Math.ceil(total / p.pageSize)) };
}

export const str = (v: unknown): string | undefined => (typeof v === 'string' && v.trim() !== '' && v !== 'all' && v !== 'ALL' ? v.trim() : undefined);
