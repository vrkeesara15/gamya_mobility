import dayjs from 'dayjs';
import { prisma } from '../config/prisma.js';

const pad = (n: number, w: number) => String(n).padStart(w, '0');

export async function nextSupervisorCode() {
  const c = await prisma.supervisor.count();
  return `SUP${pad(c + 1, 3)}`;
}
export async function nextDriverCode() {
  const c = await prisma.driver.count();
  return `DRV${pad(c + 1, 3)}`;
}
export async function nextAdhocCode(date = new Date()) {
  const d = dayjs(date).format('YYYYMMDD');
  const c = await prisma.adhocRequest.count({ where: { code: { startsWith: `ADH-${d}-` } } });
  return `ADH-${d}-${pad(c + 1, 3)}`;
}
export async function nextBookingCode(date = new Date()) {
  const d = dayjs(date).format('YYYYMMDD');
  const c = await prisma.booking.count({ where: { code: { startsWith: `BK-${d}-` } } });
  return `BK-${d}-${pad(c + 1, 3)}`;
}
export async function nextTripCode(date = new Date()) {
  const d = dayjs(date).format('YYYYMMDD');
  const c = await prisma.trip.count({ where: { code: { startsWith: `GM${d}` } } });
  return `GM${d}${pad(c + 1, 2)}`;
}
export async function nextSettlementCode() {
  const c = await prisma.settlement.count();
  return `STL-${dayjs().format('YYYYMM')}-${pad(c + 1, 4)}`;
}
export async function nextInvoiceCode() {
  const c = await prisma.invoice.count();
  return `INV-${dayjs().format('YYYYMM')}-${pad(c + 1, 4)}`;
}
