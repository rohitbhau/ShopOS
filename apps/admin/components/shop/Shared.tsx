'use client';
import { useEffect, useRef, type ReactNode } from 'react';
import { ArrowUpRight, Box, Coffee, Cookie, Droplets, Milk, Package, ShoppingBag, Sparkles, Wheat, X } from 'lucide-react';
import { dayKey, money, round, type Invoice, type Product, type ShopState } from '../../src/shop-store';

export function ProductArt({ product, small = false }: { product: Product; small?: boolean }) {
  const category = product.category.toLowerCase();
  const Icon = /grain|staple/.test(category) ? Wheat : /beverage/.test(category) ? Coffee : /dairy/.test(category) ? Milk : /snack/.test(category) ? Cookie : /personal/.test(category) ? Sparkles : /cooking/.test(category) ? Droplets : Package;
  const tone = /grain|staple/.test(category) ? 'sand' : /beverage/.test(category) ? 'brown' : /dairy/.test(category) ? 'blue' : /snack/.test(category) ? 'orange' : /personal/.test(category) ? 'lavender' : 'green';
  return <span className={`product-art ${tone} ${small ? 'small' : ''}`} aria-hidden="true"><Icon size={small ? 21 : 35} strokeWidth={1.4} /></span>;
}
export function Empty({ title, message, action }: { title: string; message: string; action?: ReactNode }) {
  return <div className="shop-empty"><span><ShoppingBag size={28} strokeWidth={1.4} /></span><h3>{title}</h3><p>{message}</p>{action}</div>;
}
export function Modal({ title, description, children, onClose, wide = false }: { title: string; description?: string; children: ReactNode; onClose: () => void; wide?: boolean }) {
  const ref = useRef<HTMLDialogElement>(null);
  useEffect(() => { const dialog = ref.current; dialog?.showModal(); return () => dialog?.close(); }, []);
  return <dialog ref={ref} className={`shop-dialog ${wide ? 'wide' : ''}`} onCancel={onClose} onClick={event => { if (event.target === event.currentTarget) { const bounds = event.currentTarget.getBoundingClientRect(); if (event.clientX < bounds.left || event.clientX > bounds.right || event.clientY < bounds.top || event.clientY > bounds.bottom) onClose(); } }}>
    <header className="dialog-heading"><div><h2>{title}</h2>{description && <p>{description}</p>}</div><button className="icon-button" aria-label="Close dialog" onClick={onClose}><X size={20} /></button></header>{children}
  </dialog>;
}
export function Badge({ type, children }: { type: 'green' | 'amber' | 'red' | 'neutral'; children: ReactNode }) { return <span className={`shop-badge ${type}`}>{children}</span>; }
export const shortInvoice = (invoice: Invoice) => `INV-${invoice.invoice_number.split('-').at(-1)}`;
export const displayDate = (date: string) => new Date(date).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric', timeZone: 'Asia/Kolkata' });
export function InvoiceTable({ invoices, open }: { invoices: Invoice[]; open: (invoice: Invoice) => void }) {
  return <div className="shop-table-scroll"><table className="shop-table"><thead><tr><th>Invoice</th><th>Customer</th><th>Date</th><th>Payment</th><th>Status</th><th className="align-right">Amount</th><th><span className="sr-only">Open</span></th></tr></thead><tbody>{invoices.map(invoice => <tr key={invoice.id}>
    <td><button className="text-button strong" title={invoice.invoice_number} onClick={() => open(invoice)}>{shortInvoice(invoice)}</button></td><td><div className="person-cell"><span className="initials">{(invoice.customer_name || 'Walk in').split(' ').map(word => word[0]).slice(0, 2).join('')}</span>{invoice.customer_name || 'Walk-in customer'}</div></td>
    <td className="muted-text">{displayDate(invoice.created_at)}</td><td><span className="capitalize">{invoice.payment_mode}</span></td><td><Badge type={invoice.payment_mode === 'credit' ? 'amber' : 'green'}>{invoice.payment_mode === 'credit' ? 'Credit sale' : 'Paid'}</Badge></td><td className="align-right strong">{money(invoice.total)}</td><td><button className="icon-button" aria-label={`Open ${shortInvoice(invoice)}`} onClick={() => open(invoice)}><ArrowUpRight size={17} /></button></td>
  </tr>)}</tbody></table></div>;
}
export function SalesChart({ invoices, days = 7 }: { invoices: Invoice[]; days?: number }) {
  const points = Array.from({ length: days }, (_, index) => { const date = new Date(); date.setDate(date.getDate() - days + 1 + index); return { date, value: invoices.filter(i => dayKey(i.created_at) === dayKey(date)).reduce((sum, i) => sum + i.total, 0) }; });
  const highest = Math.max(...points.map(p => p.value), 1), max = Math.ceil(highest / 500) * 500;
  const coordinates = points.map((p, index) => ({ x: 52 + index * 652 / Math.max(days - 1, 1), y: 192 - p.value / max * 160 }));
  const path = coordinates.map((p, i) => `${i ? 'L' : 'M'} ${p.x} ${p.y}`).join(' ');
  return <div className="sales-chart"><svg viewBox="0 0 728 240" role="img" aria-label={`${days}-day sales chart. Total ${money(points.reduce((sum, point) => sum + point.value, 0))}`}>
    <defs><linearGradient id="sales-fill" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stopColor="#1a7954" stopOpacity=".15" /><stop offset="100%" stopColor="#1a7954" stopOpacity="0" /></linearGradient></defs>
    {[0, 1, 2, 3, 4].map(i => <g key={i}><line x1="52" x2="704" y1={32 + i * 40} y2={32 + i * 40} stroke="#edf0ed" strokeDasharray="4 5" /><text x="39" y={36 + i * 40} textAnchor="end">{max * (4 - i) / 4 >= 1000 ? `${(max * (4 - i) / 4000).toFixed(1)}k` : Math.round(max * (4 - i) / 4)}</text></g>)}
    <path d={`${path} L 704 192 L 52 192 Z`} fill="url(#sales-fill)" /><path d={path} fill="none" stroke="#23855b" strokeWidth="3" strokeLinejoin="round" strokeLinecap="round" />
    {coordinates.map((p, i) => <g key={i}><circle cx={p.x} cy={p.y} r="4" fill="#fff" stroke="#23855b" strokeWidth="2"><title>{displayDate(points[i].date.toISOString())}: {money(points[i].value)}</title></circle>{(days <= 7 || i % 5 === 0 || i === days - 1) && <text x={p.x} y="222" textAnchor="middle">{points[i].date.toLocaleDateString('en-IN', { weekday: days <= 7 ? 'short' : undefined, day: days > 7 ? 'numeric' : undefined, month: days > 7 ? 'short' : undefined })}</text>}</g>)}
  </svg></div>;
}
export function Receipt({ state, invoice }: { state: ShopState; invoice: Invoice }) {
  const shop = state.shop;
  const cityLine = [shop.city, shop.state, shop.pincode].filter(Boolean).join(', ');
  return <article className={`receipt ${shop.paper === '80mm' ? 'thermal' : ''}`} id="shopos-receipt">
    <div className="receipt-brand">
      {shop.logo ? <img src={shop.logo} alt={shop.name} className="receipt-logo" /> : <Box size={30} />}
      <div>
        <h2>{shop.name}</h2>
        {shop.tagline && <p className="receipt-tagline">{shop.tagline}</p>}
        {shop.address && <p>{shop.address}</p>}
        {cityLine && <p>{cityLine}</p>}
        {shop.phone && <p>Phone: {shop.phone}</p>}
        {shop.whatsapp && shop.whatsapp !== shop.phone && <p>WhatsApp: {shop.whatsapp}</p>}
        {shop.gstin && <p>GSTIN: {shop.gstin}</p>}
      </div>
    </div>
    <div className="receipt-divider" />
    <div className="receipt-meta">
      <div><span className="eyebrow">INVOICE</span><strong>{invoice.invoice_number}</strong><p>{displayDate(invoice.created_at)}</p></div>
      <div><span className="eyebrow">BILL TO</span><strong>{invoice.customer_name || 'Walk-in customer'}</strong><p>{invoice.payment_mode.toUpperCase()} · {invoice.payment_mode === 'credit' ? 'Credit sale' : 'Paid'}</p></div>
    </div>
    <div className="shop-table-scroll"><table className="shop-table"><thead><tr><th>Item</th><th>Qty</th><th>Price</th><th>GST</th><th className="align-right">Amount</th></tr></thead><tbody>{invoice.items.map((line, index) => <tr key={index}><td>{line.product.name}</td><td>{line.quantity}</td><td>{money(line.product.price)}</td><td>{line.gst_rate}%</td><td className="align-right">{money(line.total)}</td></tr>)}</tbody></table></div>
    <div className="receipt-totals">
      <p><span>Subtotal</span><strong>{money(invoice.subtotal)}</strong></p>
      <p><span>Discount</span><strong>− {money(invoice.discount_amount)}</strong></p>
      <p><span>GST</span><strong>{money(invoice.tax_amount)}</strong></p>
      <p><span>CGST</span><span>{money(round(invoice.tax_amount / 2))}</span></p>
      <p><span>SGST</span><span>{money(invoice.tax_amount - round(invoice.tax_amount / 2))}</span></p>
      <p className="grand-total"><span>Total</span><strong>{money(invoice.total)}</strong></p>
    </div>
    <p className="receipt-thanks">Thank you for shopping with us!</p>
    {shop.upi_id && <p className="receipt-upi">Pay via UPI: {shop.upi_id}</p>}
  </article>;
}
export function download(filename: string, content: string, type = 'application/json') {
  const url = URL.createObjectURL(new Blob([content], { type })), anchor = document.createElement('a');
  anchor.href = url; anchor.download = filename; document.body.appendChild(anchor); anchor.click(); anchor.remove(); setTimeout(() => URL.revokeObjectURL(url), 1000);
}

