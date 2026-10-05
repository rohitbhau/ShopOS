'use client';

import { useCallback, useEffect, useRef, useState, type FormEvent, type ReactNode } from 'react';
import { ArrowDownToLine, ArrowRight, ArrowUpRight, BarChart3, Bell, Check, CheckCircle2, ChevronDown, ChevronRight, CircleHelp, Cloud, CreditCard, Download, Grid2X2, ImagePlus, LayoutDashboard, List, Loader2, LogOut, Menu, Minus, Package, Plus, ReceiptText, Search, Settings2, ShieldCheck, ShoppingCart, SlidersHorizontal, Sparkles, Store, TrendingUp, Users, Wallet, WifiOff, X, Zap } from 'lucide-react';
import { Badge, displayDate, download, Empty, InvoiceTable, Modal, ProductArt, Receipt, SalesChart, shortInvoice } from './Shared';
import { billTotals, can, checkout, createDemo, csv, dayKey, deleteProduct, emptyShop, money, periodInvoices, persistState, receivePayment, restoreBackup, round, saveCustomer, saveModule, saveProduct, saveSettings, storageKey, validateState, type BusinessType, type CartItem, type Customer, type Field, type Invoice, type PaymentMode, type Product, type ShopRecord, type ShopState } from '../../src/shop-store';

const navigation = [{ id: 'Overview', icon: LayoutDashboard }, { id: 'Point of sale', icon: ShoppingCart }, { id: 'Products', icon: Package }, { id: 'Customers', icon: Users }, { id: 'Invoices', icon: ReceiptText }, { id: 'Reports', icon: BarChart3 }, { id: 'Shop modules', icon: Grid2X2 }] as const;
type Section = typeof navigation[number]['id'] | 'Settings';
type Dialog = { kind: 'product'; product?: Product } | { kind: 'customer'; customer?: Customer } | { kind: 'payment'; customer: Customer } | { kind: 'ledger'; customer: Customer } | { kind: 'invoice'; invoice: Invoice } | { kind: 'module'; entity: string; record?: ShopRecord } | { kind: 'help' } | { kind: 'setup' } | { kind: 'delete'; product: Product } | { kind: 'reset' };

const BUSINESS_TYPES: { value: BusinessType; label: string; emoji: string; template: string; tagline: string }[] = [
  { value: 'grocery', label: 'Grocery / Kirana', emoji: '🛒', template: 'retail_basic', tagline: 'Fresh & affordable, every day' },
  { value: 'retail', label: 'Retail Shop', emoji: '🏪', template: 'retail_basic', tagline: 'Quality products, happy customers' },
  { value: 'restaurant', label: 'Restaurant / Dhaba', emoji: '🍽️', template: 'restaurant', tagline: 'Serving smiles, one plate at a time' },
  { value: 'pharmacy', label: 'Medical / Pharmacy', emoji: '💊', template: 'pharmacy', tagline: 'Your health, our priority' },
  { value: 'boutique', label: 'Boutique / Clothing', emoji: '👗', template: 'boutique', tagline: 'Style that speaks for itself' },
  { value: 'salon', label: 'Salon / Beauty', emoji: '✂️', template: 'salon', tagline: 'Look good, feel great' },
  { value: 'repair', label: 'Repair & Services', emoji: '🔧', template: 'repair', tagline: 'Fixed right, the first time' },
  { value: 'electronics', label: 'Electronics', emoji: '📱', template: 'retail_basic', tagline: 'Tech for every budget' },
  { value: 'hardware', label: 'Hardware / Tools', emoji: '🔨', template: 'retail_basic', tagline: 'Built to last' },
  { value: 'bakery', label: 'Bakery / Sweets', emoji: '🎂', template: 'retail_basic', tagline: 'Made fresh, with love' },
  { value: 'medical', label: 'Clinic / Medical', emoji: '🏥', template: 'pharmacy', tagline: 'Care you can count on' },
  { value: 'other', label: 'Other Business', emoji: '🏢', template: 'retail_basic', tagline: 'Your business, your way' },
];
const templateTheme = (t: string) => ({ restaurant: 'theme-restaurant', pharmacy: 'theme-pharmacy', boutique: 'theme-boutique', salon: 'theme-salon', repair: 'theme-repair' })[t] || '';
const businessEmoji = (type?: string) => BUSINESS_TYPES.find(b => b.value === type)?.emoji || '🏪';
const shopInitials = (name: string) => (name || 'MS').split(' ').map((w: string) => w[0]).slice(0, 2).join('').toUpperCase() || 'MS';

const lastWorkspace = 'shopos:active-workspace';
async function api(path: string, body?: Record<string, unknown>, method?: string) {
  const response = await fetch(path, { method: method || (body ? 'POST' : 'GET'), headers: body ? { 'Content-Type': 'application/json' } : undefined, body: body ? JSON.stringify(body) : undefined, cache: 'no-store' });
  const data = await response.json(); if (!response.ok) throw new Error(data.error || 'The request failed.'); return data;
}
function cloudState(data: any, previous?: ShopState): ShopState {
  const tenant = data.tenant;
  const state = previous ? structuredClone(previous) : emptyShop(false, tenant.id, data.user.app_metadata?.shop_role || 'viewer');
  state.role = data.user.app_metadata?.shop_role || 'viewer'; state.userId = data.user.id;
  if (state.outbox.length) return state;
  state.shop = {
    ...state.shop,
    name: tenant.name,
    address: tenant.address?.text || '',
    upi_id: tenant.address?.upi_id || '',
    phone: tenant.phone || '',
    gstin: tenant.gstin || '',
    plan: tenant.plan || 'free',
    template: tenant.template_key || 'retail_basic',
    tagline: tenant.tagline || state.shop.tagline || '',
    city: tenant.city || state.shop.city || '',
    state: tenant.state || state.shop.state || '',
    pincode: tenant.pincode || state.shop.pincode || '',
    whatsapp: tenant.whatsapp || state.shop.whatsapp || '',
    business_type: tenant.business_type || state.shop.business_type || 'retail',
  };
  state.schemas = data.schemas; state.products = []; state.customers = []; state.invoices = []; state.records = {};
  for (const row of data.records) {
    if (row.deleted_at) continue;
    const item = { ...row.data, id: row.id, created_at: row.data.created_at || row.created_at };
    if (row.entity === 'product') state.products.push({ ...item, cost: Number(item.cost || 0), price: Number(item.price), stock: Number(item.stock), gst_rate: Number(item.gst_rate ?? item.gst ?? 0), min_stock: Number(item.min_stock ?? item.low_stock_threshold ?? 5), category: item.category || 'General', barcode: item.barcode || item.sku || '' });
    else if (row.entity === 'customer') state.customers.push({ ...item, phone: item.phone || '', address: item.address || '', outstanding: Number(item.outstanding || 0) });
    else if (row.entity === 'invoice') state.invoices.push({ ...item, subtotal: item.subtotal ?? item.items?.reduce((sum: number, line: any) => sum + line.total, 0) ?? 0 });
    else (state.records[row.entity] ??= []).push(item);
  }
  state.invoices.sort((a, b) => b.created_at.localeCompare(a.created_at)); state.revision++;
  return state;
}

export default function ShopWorkspace({ mode }: { mode: 'live' | 'demo' | 'incomplete' }) {
  const [state, setState] = useState<ShopState | null>(null), current = useRef<ShopState | null>(null);
  const [ready, setReady] = useState(false), [screen, setScreen] = useState<Section>('Overview'), [dialog, setDialog] = useState<Dialog | null>(null);
  const [toast, setToast] = useState<{ text: string; error?: boolean } | null>(null), [fatal, setFatal] = useState('');
  const [mobileMenu, setMobileMenu] = useState(false), [syncing, setSyncing] = useState(false), [syncError, setSyncError] = useState(''), syncLock = useRef(false);
  const [online, setOnline] = useState(true), [cart, setCart] = useState<CartItem[]>([]), [query, setQuery] = useState('');
  const [category, setCategory] = useState('All products'), [lowOnly, setLowOnly] = useState(false), [grid, setGrid] = useState(false), [days, setDays] = useState(7);
  const [invoiceFilter, setInvoiceFilter] = useState('all'), [moduleEntity, setModuleEntity] = useState('');
  function notify(text: string, error = false) { setToast({ text, error }); }
  const assign = useCallback((next: ShopState) => { current.current = next; setState(next); }, []);
  const loadCloud = useCallback(async () => {
    const data = await api('/api/shop');
    if (data.needsShop) { setDialog({ kind: 'setup' }); return; }
    const identity = { demo: false, tenantId: data.tenant.id, userId: data.user.id };
    const source = localStorage.getItem(storageKey(identity));
    const previous = current.current && current.current.tenantId === identity.tenantId && current.current?.userId === identity.userId ? current.current : source ? JSON.parse(source) as ShopState : undefined;
    if (previous) validateState(previous);
    const next = cloudState(data, previous); if (previous) persistState(previous, next); else localStorage.setItem(storageKey(next), JSON.stringify(next));
    localStorage.setItem(lastWorkspace, storageKey(next)); assign(next);
  }, [assign]);
  useEffect(() => {
    let disposed = false;
    const start = async () => {
      try {
        if (mode === 'demo') {
          const source = localStorage.getItem('shopos:shop:demo:v1'), next = source ? JSON.parse(source) : createDemo(); validateState(next);
          if (!source) localStorage.setItem(storageKey(next), JSON.stringify(next)); if (!disposed) assign(next);
        } else if (mode === 'live') {
          const response = await fetch('/api/shop/auth', { cache: 'no-store' });
          if (response.ok) await loadCloud();
        } else setFatal('Set both SUPABASE_URL and SUPABASE_ANON_KEY in apps/admin/.env.local, then restart the web server.');
      } catch (error) { if (!disposed) setFatal((error as Error).message); }
      finally { if (!disposed) setReady(true); }
    };
    void start(); return () => { disposed = true; };
  }, [mode, assign, loadCloud]);
  useEffect(() => { const change = () => setOnline(navigator.onLine); change(); window.addEventListener('online', change); window.addEventListener('offline', change); return () => { window.removeEventListener('online', change); window.removeEventListener('offline', change); }; }, []);
  useEffect(() => { if (process.env.NODE_ENV === 'production' && 'serviceWorker' in navigator) void navigator.serviceWorker.register('/sw.js').catch(() => {}); }, []);
  useEffect(() => { if (!toast) return; const timeout = setTimeout(() => setToast(null), toast.error ? 9000 : 4500); return () => clearTimeout(timeout); }, [toast]);
  const commit = useCallback((update: (previous: ShopState) => ShopState, message?: string) => {
    try {
      const previous = current.current; if (!previous) throw new Error('Open your shop first.');
      const next = update(previous); persistState(previous, next); assign(next); if (message) setToast({ text: message }); return true;
    } catch (error) { setToast({ text: (error as Error).message, error: true }); return false; }
  }, [assign]);
  const sync = useCallback(async () => {
    if (!current.current || current.current.demo || syncLock.current || !navigator.onLine) return;
    syncLock.current = true; setSyncing(true); setSyncError('');
    try {
      while (current.current?.outbox.length) {
        const batch = current.current.outbox[0];
        await api('/api/shop/sync', { tenantId: current.current.tenantId, mutations: batch.mutations });
        if (!commit(previous => ({ ...previous, revision: previous.revision + 1, outbox: previous.outbox.filter(item => item.id !== batch.id) }))) break;
      }
      if (!current.current?.outbox.length) await loadCloud();
    } catch (error) { setSyncError((error as Error).message); }
    finally { setSyncing(false); syncLock.current = false; }
  }, [commit, loadCloud]);
  useEffect(() => { if (!state || state.demo || !online) return; void sync(); const timer = setInterval(() => void sync(), 30000); return () => clearInterval(timer); }, [state?.tenantId, state?.demo, online, sync]);
  useEffect(() => {
    if (!state) return;
    const key = `${storageKey(state)}:cart`;
    try { const stored = sessionStorage.getItem(key); setCart(stored ? JSON.parse(stored) : []); } catch { setCart([]); }
  }, [state?.tenantId, state?.userId]);
  useEffect(() => { if (state) { try { sessionStorage.setItem(`${storageKey(state)}:cart`, JSON.stringify(cart)); } catch { /* cart stays in memory */ } } }, [cart, state?.tenantId, state?.userId]);
  function navigate(section: Section) { setScreen(section); setQuery(''); setCategory('All products'); setLowOnly(false); setMobileMenu(false); }
  function openInvoice(invoice: Invoice) { setDialog({ kind: 'invoice', invoice }); }
  function saveForm(event: FormEvent<HTMLFormElement>, update: (values: Record<string, unknown>) => ShopState, message: string) { event.preventDefault(); if (commit(() => update(Object.fromEntries(new FormData(event.currentTarget))), message)) setDialog(null); }
  function addToCart(product: Product) {
    try {
      const existing = cart.find(item => item.product_id === product.id), quantity = (existing?.quantity || 0) + 1;
      if (quantity > product.stock) throw new Error(`Only ${product.stock} ${product.name} available.`);
      setCart(existing ? cart.map(item => item.product_id === product.id ? { ...item, quantity } : item) : [...cart, { product_id: product.id, quantity: 1 }]);
    } catch (error) { notify((error as Error).message, true); }
  }
  async function signOut() {
    try { if (!state?.demo) { await api('/api/shop/auth', undefined, 'DELETE'); localStorage.removeItem(lastWorkspace); } current.current = null; setState(null); setCart([]); navigate('Overview'); }
    catch (error) { notify((error as Error).message, true); }
  }
  const modal = dialog && renderDialog();
  if (!ready) return <div className="shop-app shop-loading"><div className="shop-logo"><Store size={24} /></div><h2>Opening your shop…</h2><Loader2 className="spin" size={22} /></div>;
  if (!state) return <div className="shop-app"><Welcome mode={mode} error={fatal} onDemo={() => { try { const source = localStorage.getItem('shopos:shop:demo:v1'), next = source ? JSON.parse(source) : createDemo(); validateState(next); localStorage.setItem(storageKey(next), JSON.stringify(next)); assign(next); setFatal(''); } catch (error) { setFatal((error as Error).message); } }} onLogin={async () => { try { await loadCloud(); setFatal(''); } catch (error) { setFatal((error as Error).message); } }} onOffline={() => { try { const key = localStorage.getItem(lastWorkspace); if (!key) throw new Error('No saved shop found on this browser. Sign in online first.'); const next = JSON.parse(localStorage.getItem(key) || 'null'); validateState(next); assign(next); setFatal(''); } catch (error) { setFatal((error as Error).message); } }} />{modal}{toast && <Toast toast={toast} close={() => setToast(null)} />}</div>;
  const matchingProducts = state.products.filter(p => `${p.name} ${p.barcode} ${p.category}`.toLowerCase().includes(query.toLowerCase()) && (category === 'All products' || p.category === category) && (!lowOnly || p.stock <= p.min_stock)).sort((a, b) => a.name.localeCompare(b.name));
  const categories = Array.from(new Set(state.products.map(p => p.category))).sort(), lowStock = state.products.filter(p => p.stock <= p.min_stock);
  const period = periodInvoices(state, days), sales = round(period.reduce((sum, i) => sum + i.total, 0)), outstanding = round(state.customers.reduce((sum, c) => sum + c.outstanding, 0));
  const today = new Date().toLocaleDateString('en-IN', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric', timeZone: 'Asia/Kolkata' });
  const topProducts = state.products.map(p => { const lines = period.flatMap(i => i.items).filter(line => line.product.id === p.id); return { product: p, quantity: lines.reduce((sum, l) => sum + l.quantity, 0), revenue: round(lines.reduce((sum, l) => sum + l.total, 0)) }; }).filter(p => p.quantity).sort((a, b) => b.revenue - a.revenue).slice(0, 4);
  const invoices = state.invoices.filter(i => `${i.invoice_number} ${i.customer_name || 'Walk-in'}`.toLowerCase().includes(query.toLowerCase()) && (invoiceFilter === 'all' || (invoiceFilter === 'credit' ? i.payment_mode === 'credit' : i.payment_mode !== 'credit')));
  const modules = Object.entries(state.schemas).filter(([key]) => !['product', 'customer', 'invoice', 'ledger', 'stock_adjustment'].includes(key));
  const activeEntity = modules.some(([key]) => key === moduleEntity) ? moduleEntity : modules[0]?.[0];
  const initials = shopInitials(state.shop.name);

  return <div className={`shop-app workspace ${templateTheme(state.shop.template)}`}><a className="skip-link" href="#shop-main">Skip to content</a>{mobileMenu && <button className="nav-scrim" aria-label="Close navigation" onClick={() => setMobileMenu(false)} />}
    <aside className={`shop-sidebar ${mobileMenu ? 'open' : ''}`}>
      <a className="shop-brand" href="/">{state.shop.logo ? <img src={state.shop.logo} alt={state.shop.name} className="shop-logo-img" /> : <span className="shop-logo"><Store size={22} strokeWidth={1.8} /></span>}<span>Shop<span className="brand-os">OS</span><small>YOUR EVERYDAY BUSINESS</small></span></a>
      <button className="workspace-selector" onClick={() => navigate('Settings')}><span className="store-icon">{state.shop.logo ? <img src={state.shop.logo} alt="" className="store-logo-thumb" /> : <span style={{ fontSize: 18 }}>{businessEmoji(state.shop.business_type)}</span>}</span><span><strong>{state.shop.name || 'My Shop'}</strong><small>{state.demo ? 'Demo workspace' : `${state.shop.plan} plan`}</small></span><ChevronDown size={15} /></button>
      <p className="nav-caption">WORKSPACE</p>
      <nav aria-label="Shop navigation">{navigation.filter(item => item.id !== 'Reports' || can(state.role, 'reports')).map(({ id, icon: Icon }) => <button key={id} aria-label={id} className={`shop-nav ${screen === id ? 'selected' : ''}`} aria-current={screen === id ? 'page' : undefined} onClick={() => navigate(id)}><Icon size={19} strokeWidth={1.7} /><span>{id}</span>{id === 'Products' && lowStock.length > 0 && <span className="nav-count">{lowStock.length}</span>}{screen === id && <span className="nav-active-dot" />}</button>)}</nav>
      <div className="sidebar-bottom">
        <div className="shop-tip"><span className="tip-icon"><Zap size={20} /></span><strong>India's most powerful shop tool.</strong><p>Billing · Inventory · Customers · Reports<br />Works offline. Syncs automatically.</p><button onClick={() => setDialog({ kind: 'help' })}>Explore the guide <ArrowUpRight size={15} /></button></div>
        <button className={`shop-nav ${screen === 'Settings' ? 'selected' : ''}`} onClick={() => navigate('Settings')}><Settings2 size={19} />Settings</button>
        <button className="shop-nav" onClick={() => void signOut()}><LogOut size={19} />Sign out</button>
        <div className="sidebar-profile"><span className="initials profile-avatar">{initials}</span><span><strong>{state.demo ? 'Demo Shop' : state.shop.name}</strong><small className="capitalize">{state.role} · {state.demo ? 'Local demo' : 'Live shop'}</small></span></div>
      </div>
    </aside>
    <div className="workspace-main">
      <header className="shop-topbar">
        <div className="breadcrumb"><button className="icon-button mobile-toggle" aria-label="Open navigation" onClick={() => setMobileMenu(true)}><Menu size={22} /></button><span>Workspace</span><ChevronRight size={14} /><strong>{screen}</strong></div>
        <div className="topbar-actions">
          <button className={`sync-status ${!online ? 'is-offline' : ''}`} disabled={syncing || state.demo} onClick={() => void sync()} title={state.demo ? 'Demo data is saved in this browser' : syncError || 'Sync your saved changes'}>{syncing ? <Loader2 size={15} className="spin" /> : !online ? <WifiOff size={15} /> : state.demo ? <CheckCircle2 size={15} /> : <Cloud size={16} />}<span>{state.demo ? 'Demo · saved locally' : !online ? 'Working offline' : state.outbox.length ? `${state.outbox.length} pending` : syncError ? 'Sync needs attention' : 'All changes saved'}</span></button>
          <span className="topbar-divider" />
          <button className="icon-button" aria-label="Open help" onClick={() => setDialog({ kind: 'help' })}><CircleHelp size={19} /></button>
          <button className="icon-button notification-button" aria-label={`View ${lowStock.length} low stock alerts`} onClick={() => { navigate('Products'); setLowOnly(true); }}><Bell size={19} />{lowStock.length > 0 && <i />}</button>
          <button className="initials topbar-avatar" aria-label="Open shop settings" onClick={() => navigate('Settings')}>{initials}</button>
        </div>
      </header>
      <main id="shop-main" className="shop-content">
        {syncError && <div className="shop-notice error" role="alert">{syncError} <button className="text-button" onClick={() => void sync()}>Retry sync</button></div>}
        <div className="page-heading"><div><span className="eyebrow">{screen === 'Overview' ? today : 'YOUR SHOP, ORGANIZED'}</span><h1>{screen === 'Overview' ? `Good day, ${state.shop.name || 'shopkeeper'}.` : screen}</h1><p>{({ Overview: 'A clear view of your shop. A little less to keep track of.', 'Point of sale': 'Simple billing. Happy customers. On to the next sale.', Products: 'Everything on your shelves, in one place.', Customers: 'Good relationships are good business.', Invoices: 'Every sale, neatly accounted for.', Reports: 'Understand the numbers behind your business.', 'Shop modules': 'A workspace that grows with your shop.', Settings: 'Your shop identity, details, and data.' })[screen]}</p></div><div className="heading-actions">{screen === 'Overview' && <><button className="shop-button secondary" onClick={() => download('shopos-sales.csv', csv([['Invoice', 'Date', 'Customer', 'Payment', 'Total'], ...period.map(i => [i.invoice_number, displayDate(i.created_at), i.customer_name || 'Walk-in', i.payment_mode, i.total])]), 'text/csv;charset=utf-8')}><Download size={16} />Export report</button>{can(state.role, 'sell') && <button className="shop-button primary" onClick={() => navigate('Point of sale')}><Plus size={18} />New sale</button>}</>}{screen === 'Products' && can(state.role, 'manage') && <button className="shop-button primary" onClick={() => setDialog({ kind: 'product' })}><Plus size={18} />Add product</button>}{screen === 'Customers' && can(state.role, 'sell') && <button className="shop-button primary" onClick={() => setDialog({ kind: 'customer' })}><Plus size={18} />Add customer</button>}{screen === 'Invoices' && <button className="shop-button secondary" onClick={() => download('shopos-invoices.csv', csv([['Invoice', 'Date', 'Customer', 'Payment', 'Total'], ...invoices.map(i => [i.invoice_number, i.created_at, i.customer_name, i.payment_mode, i.total])]), 'text/csv;charset=utf-8')}><Download size={16} />Export invoices</button>}</div></div>

        {(screen === 'Overview' || screen === 'Reports') && <><div className="overview-toolbar"><div className="period-tabs" aria-label="Report period">{[[1, 'Today'], [7, 'This week'], [30, 'Last 30 days']].map(([value, label]) => <button key={value} className={days === value ? 'active' : ''} onClick={() => setDays(Number(value))}>{label}</button>)}</div><span className="muted-text">{state.demo ? 'Sample shop activity' : 'Based on your saved sales'}</span></div>
          <div className="stat-grid">
            <Stat label="Total sales" value={money(sales)} icon={<TrendingUp size={20} />} detail={`${period.length} sales in this period`} tone="green" />
            <Stat label="Invoices created" value={String(period.length).padStart(2, '0')} icon={<ReceiptText size={20} />} detail={`${period.filter(i => i.payment_mode !== 'credit').length} paid · ${period.filter(i => i.payment_mode === 'credit').length} credit`} tone="blue" />
            <Stat label="Customer outstanding" value={money(outstanding)} icon={<Wallet size={20} />} detail={`${state.customers.filter(c => c.outstanding > 0).length} customers with a balance`} tone="orange" />
            <Stat label="Products in stock" value={String(state.products.filter(p => p.stock > 0).length).padStart(2, '0')} icon={<Package size={20} />} detail={`${lowStock.length} products need attention`} tone="purple" />
          </div>
          <div className="dashboard-grid">
            <section className="shop-panel chart-panel"><div className="panel-title"><div><h2>Sales overview</h2><p>Your everyday progress at a glance.</p></div><span className="chart-legend"><i />Sales</span></div><div className="chart-summary"><strong>{money(sales)}</strong><span>over {days === 1 ? 'today' : `the last ${days} days`}</span></div><SalesChart invoices={period} days={days === 1 ? 7 : days} /></section>
            <section className="shop-panel top-products"><div className="panel-title"><div><h2>Best on your shelves</h2><p>Your top products this period.</p></div><TrendingUp size={18} /></div>{topProducts.length ? topProducts.map((item, index) => <div className="top-product" key={item.product.id}><span className="rank">{String(index + 1).padStart(2, '0')}</span><ProductArt product={item.product} small /><div><strong>{item.product.name}</strong><small>{item.quantity} units sold</small></div><strong className="top-product-money">{money(item.revenue)}</strong></div>) : <Empty title="Your bestsellers start here" message="Create a sale to see your top products." />}<button className="panel-link" onClick={() => navigate('Products')}>View all products <ArrowRight size={16} /></button></section>
          </div>
          {screen === 'Reports' && <section className="shop-panel report-breakdown"><div className="panel-title"><div><h2>Where your sales come from</h2><p>Payment mix and estimated gross profit.</p></div><button className="shop-button secondary" onClick={() => download('shopos-report.csv', csv([['Metric', 'Amount'], ['Sales', sales], ['GST', period.reduce((s, i) => s + i.tax_amount, 0)], ['Gross profit', period.reduce((s, i) => s + i.total - i.tax_amount - i.items.reduce((c, l) => c + l.product.cost * l.quantity, 0), 0)], ...(['cash', 'upi', 'card', 'credit'] as const).map(mode => [mode, period.filter(i => i.payment_mode === mode).reduce((s, i) => s + i.total, 0)])]), 'text/csv;charset=utf-8')}><Download size={16} />Download CSV</button></div><div className="payment-mix">{(['cash', 'upi', 'card', 'credit'] as const).map(mode => <div key={mode}><span className="capitalize">{mode}</span><strong>{money(period.filter(i => i.payment_mode === mode).reduce((s, i) => s + i.total, 0))}</strong></div>)}</div></section>}
          <section className="shop-panel recent-invoices"><div className="panel-title"><div><h2>Recent invoices</h2><p>The latest chapters in your shop's story.</p></div><button className="text-button" onClick={() => navigate('Invoices')}>View all <ArrowRight size={16} /></button></div>{state.invoices.length ? <InvoiceTable invoices={state.invoices.slice(0, 5)} open={openInvoice} /> : <Empty title="Ready for your first sale" message="Your invoices will appear here as you complete sales." action={<button className="shop-button primary" onClick={() => navigate('Point of sale')}>Create a sale</button>} />}</section>
          {lowStock.length > 0 && <div className="stock-callout"><span className="stock-callout-icon"><Package size={22} /></span><div><strong>Quick shelf check needed</strong><p>{lowStock.length} products are running low. Keep the essentials ready for your next customer.</p></div><button className="shop-button secondary" onClick={() => { navigate('Products'); setLowOnly(true); }}>Review stock <ArrowRight size={15} /></button></div>}
        </>}

        {screen === 'Products' && <><div className="inventory-summary"><span><strong>{state.products.length}</strong> total products</span><span><i className="dot green" /><strong>{state.products.filter(p => p.stock > p.min_stock).length}</strong> healthy stock</span><span><i className="dot amber" /><strong>{lowStock.length}</strong> need attention</span><button className="text-button" onClick={() => download('shopos-products.csv', csv([['Name', 'Category', 'Price', 'Cost', 'Stock', 'GST', 'Barcode'], ...state.products.map(p => [p.name, p.category, p.price, p.cost, p.stock, p.gst_rate, p.barcode])]), 'text/csv;charset=utf-8')}><Download size={15} />Export inventory</button></div><section className="shop-panel"><div className="products-toolbar"><SearchInput value={query} change={setQuery} placeholder="Search products or scan a barcode…" /><select aria-label="Product category" value={category} onChange={e => setCategory(e.target.value)}><option>All products</option>{categories.map(c => <option key={c}>{c}</option>)}</select><button className={`shop-button secondary ${lowOnly ? 'filter-selected' : ''}`} onClick={() => setLowOnly(!lowOnly)}><SlidersHorizontal size={16} />Low stock</button><div className="view-toggle"><button aria-label="List view" aria-pressed={!grid} onClick={() => setGrid(false)}><List size={18} /></button><button aria-label="Grid view" aria-pressed={grid} onClick={() => setGrid(true)}><Grid2X2 size={17} /></button></div></div>{matchingProducts.length ? grid ? <div className="inventory-grid">{matchingProducts.map(p => <div className="inventory-card" key={p.id}><ProductArt product={p} /><Badge type={p.stock === 0 ? 'red' : p.stock <= p.min_stock ? 'amber' : 'green'}>{p.stock === 0 ? 'Out of stock' : p.stock <= p.min_stock ? 'Low stock' : 'In stock'}</Badge><h3>{p.name}</h3><p>{p.category}</p><div><strong>{money(p.price)}</strong><span>{p.stock} units</span></div>{can(state.role, 'manage') && <button className="shop-button secondary" onClick={() => setDialog({ kind: 'product', product: p })}>Edit product</button>}</div>)}</div> : <div className="shop-table-scroll"><table className="shop-table"><thead><tr><th>Product</th><th>Category</th><th>Price</th><th>GST</th><th>Stock</th><th>Status</th><th>Actions</th></tr></thead><tbody>{matchingProducts.map(p => <tr key={p.id}><td><div className="product-cell"><ProductArt product={p} small /><span><strong>{p.name}</strong><small>{p.barcode || 'No barcode'}</small></span></div></td><td className="muted-text">{p.category}</td><td className="strong">{money(p.price)}</td><td>{p.gst_rate}%</td><td>{p.stock} units</td><td><Badge type={p.stock === 0 ? 'red' : p.stock <= p.min_stock ? 'amber' : 'green'}>{p.stock === 0 ? 'Out of stock' : p.stock <= p.min_stock ? 'Low stock' : 'In stock'}</Badge></td><td>{can(state.role, 'manage') && <div className="table-actions"><button className="text-button" onClick={() => setDialog({ kind: 'product', product: p })}>Edit</button><button className="text-button danger" onClick={() => setDialog({ kind: 'delete', product: p })}>Delete</button></div>}</td></tr>)}</tbody></table></div> : <Empty title="No products found" message={state.products.length ? 'Try a different search or category.' : 'Add your first product to start building your inventory.'} action={can(state.role, 'manage') && <button className="shop-button primary" onClick={() => setDialog({ kind: 'product' })}><Plus size={16} />Add product</button>} />}</section></>}
        {screen === 'Point of sale' && (can(state.role, 'sell') ? <div className="pos-layout"><section className="shop-panel pos-catalog"><SearchInput value={query} change={setQuery} placeholder="Search a product or scan barcode…" onEnter={() => { const found = state.products.find(p => p.barcode === query); if (found) addToCart(found); }} /><div className="category-tabs"><button className={category === 'All products' ? 'active' : ''} onClick={() => setCategory('All products')}>All products</button>{categories.map(c => <button key={c} className={category === c ? 'active' : ''} onClick={() => setCategory(c)}>{c}</button>)}</div><div className="pos-products">{matchingProducts.map(product => <button className={`pos-product ${product.stock === 0 ? 'unavailable' : ''}`} key={product.id} disabled={!product.stock} onClick={() => addToCart(product)}><ProductArt product={product} /><span className="pos-product-category">{product.category}</span><strong>{product.name}</strong><span className="product-stock">{product.stock ? `${product.stock} in stock` : 'Out of stock'}</span><span className="pos-product-bottom"><strong>{money(product.price)}</strong><span className="add-product"><Plus size={17} /></span></span></button>)}</div>{!matchingProducts.length && <Empty title="No matching products" message="Try another search, or add products to your inventory." />}</section><Checkout state={state} cart={cart} setCart={setCart} commit={commit} complete={invoice => { setCart([]); openInvoice(invoice); }} notify={notify} /></div> : <Empty title="View-only workspace" message="Ask your shop owner for billing access." />)}
        {screen === 'Customers' && <><div className="customer-summary"><Stat label="Your customers" value={String(state.customers.length)} detail="Relationships that keep your shop going" tone="blue" icon={<Users size={20} />} /><Stat label="Outstanding balance" value={money(outstanding)} detail="Across all customer credit sales" tone="orange" icon={<Wallet size={20} />} /></div><section className="shop-panel"><div className="products-toolbar"><SearchInput value={query} change={setQuery} placeholder="Search customer name or phone…" /></div>{state.customers.filter(c => `${c.name} ${c.phone}`.toLowerCase().includes(query.toLowerCase())).length ? <div className="shop-table-scroll"><table className="shop-table"><thead><tr><th>Customer</th><th>Phone</th><th>Outstanding</th><th>Status</th><th>Actions</th></tr></thead><tbody>{state.customers.filter(c => `${c.name} ${c.phone}`.toLowerCase().includes(query.toLowerCase())).map(customer => <tr key={customer.id}><td><div className="person-cell"><span className="initials">{customer.name.split(' ').map(w => w[0]).slice(0, 2).join('')}</span><strong>{customer.name}</strong></div></td><td className="muted-text">{customer.phone || '—'}</td><td className="strong">{money(customer.outstanding)}</td><td><Badge type={customer.outstanding > 0 ? 'amber' : 'green'}>{customer.outstanding > 0 ? 'Balance due' : 'All settled'}</Badge></td><td><div className="table-actions"><button className="text-button" onClick={() => setDialog({ kind: 'ledger', customer })}>Ledger</button>{can(state.role, 'sell') && <><button className="text-button" onClick={() => setDialog({ kind: 'customer', customer })}>Edit</button>{customer.outstanding > 0 && <button className="shop-button secondary small-button" onClick={() => setDialog({ kind: 'payment', customer })}>Record payment</button>}</>}</div></td></tr>)}</tbody></table></div> : <Empty title="No customers found" message="Add a customer to keep track of their purchases and credit balance." />}</section></>}
        {screen === 'Invoices' && <section className="shop-panel"><div className="products-toolbar"><SearchInput value={query} change={setQuery} placeholder="Search invoice or customer…" /><select aria-label="Invoice status" value={invoiceFilter} onChange={e => setInvoiceFilter(e.target.value)}><option value="all">All invoices</option><option value="paid">Paid sales</option><option value="credit">Credit sales</option></select><span className="muted-text">{invoices.length} invoices</span></div>{invoices.length ? <InvoiceTable invoices={invoices} open={openInvoice} /> : <Empty title="No invoices found" message="Your completed sales will appear here." />}</section>}
        {screen === 'Shop modules' && <section className="shop-panel"><div className="panel-title"><div><h2>Your shop's extra essentials</h2><p>Modules from your shop template.</p></div>{activeEntity && can(state.role, 'manage') && <button className="shop-button primary" onClick={() => setDialog({ kind: 'module', entity: activeEntity })}><Plus size={16} />Add record</button>}</div>{modules.length ? <><div className="category-tabs">{modules.map(([key, schema]) => <button key={key} className={activeEntity === key ? 'active' : ''} onClick={() => setModuleEntity(key)}>{schema.label || key}</button>)}</div><div className="module-records">{(state.records[activeEntity] || []).map(row => <div className="module-record" key={row.id}><span className="store-icon"><Grid2X2 size={20} /></span><div><strong>{String(row.name || row.title || 'Record')}</strong><p>{state.schemas[activeEntity].fields.filter(f => !['name', 'title'].includes(f.name)).slice(0, 3).map(f => `${f.label || f.name}: ${row[f.name] ?? '—'}`).join(' · ')}</p></div>{can(state.role, 'manage') && <button className="text-button" onClick={() => setDialog({ kind: 'module', entity: activeEntity, record: row })}>Edit</button>}</div>)}</div>{!(state.records[activeEntity] || []).length && <Empty title="A fresh start" message="Add the first record for this module." />}</> : <Empty title="No extra modules yet" message="Publish a module using the administration builder to add it here." action={<a className="shop-button secondary" href="/admin">Open administration <ArrowUpRight size={16} /></a>} />}</section>}
        {screen === 'Settings' && <Settings state={state} commit={commit} notify={notify} reset={() => setDialog({ kind: 'reset' })} />}
        <footer className="shop-footer"><span><span className="footer-dot" />🇮🇳 Made in India · ShopOS</span><span>Your shop. Your numbers. Your way. <Store size={13} /></span></footer>
      </main>
    </div>{modal}{toast && <Toast toast={toast} close={() => setToast(null)} />}
  </div>;

  function renderDialog(): ReactNode {
    if (!dialog) return null;
    const close = () => setDialog(null), s = state;
    if (dialog.kind === 'setup') {
      return <Modal title="Set up your shop" description="A few details and you're ready to go." onClose={close}>
        <form className="shop-form" onSubmit={async event => {
          event.preventDefault();
          const fd = new FormData(event.currentTarget);
          const bizType = fd.get('business_type') as string;
          const bt = BUSINESS_TYPES.find(b => b.value === bizType) || BUSINESS_TYPES[0];
          try {
            await api('/api/shop', { action: 'create_shop', name: fd.get('name'), address: fd.get('address'), template: bt.template, business_type: bt.value });
            setDialog(null); await loadCloud();
          } catch (error) { notify((error as Error).message, true); }
        }}>
          <FormInput name="name" label="Shop name" required placeholder="e.g. Sharma General Store" />
          <FormInput name="address" label="Shop address" placeholder="Street, City" />
          <label>Business type
            <select name="business_type">{BUSINESS_TYPES.map(b => <option key={b.value} value={b.value}>{b.emoji} {b.label}</option>)}</select>
          </label>
          <button className="shop-button primary" style={{ marginTop: 8 }}>Create my shop <ArrowRight size={16} /></button>
        </form>
      </Modal>;
    }
    if (dialog.kind === 'help') return <Modal title="ShopOS quick guide" description="Everything you need to run your shop." onClose={close}><div className="help-steps">{[['01', 'Stock your shelves', 'Add products with price, stock, and GST rate in Products.'], ['02', 'Make your first sale', 'Choose products in Point of sale, pick a payment method, complete the bill.'], ['03', 'Keep credit organized', 'Select a customer for credit sales. Record repayments from Customers.'], ['04', 'Look back, plan ahead', 'Open invoices to print or save PDF. Use Reports to understand your sales.']].map(([number, title, text]) => <div key={number}><span>{number}</span><section><strong>{title}</strong><p>{text}</p></section></div>)}<p className="shop-notice">{s?.demo ? 'This is a local demo. Your edits stay in this browser. Sign in to a configured shop to use cloud sync.' : 'Changes are saved on this device first. Pending changes sync automatically when your connection returns.'}</p><a className="text-button" href="/admin">Open administration <ArrowUpRight size={15} /></a></div></Modal>;
    if (!s) return null;
    if (dialog.kind === 'product') { const p = dialog.product; return <Modal title={p ? 'Edit product' : 'Add a product'} description="Prices are entered before GST. Stock updates with every sale." onClose={close}><form className="shop-form" onSubmit={e => saveForm(e, v => saveProduct(current.current!, v, p?.id), p ? 'Product updated.' : 'Product added to your inventory.')}><FormInput name="name" label="Product name" value={p?.name} required /><div className="form-row"><FormInput name="price" label="Selling price (₹)" type="number" step="0.01" min="0" value={p?.price} required /><FormInput name="cost" label="Cost price (₹)" type="number" step="0.01" min="0" value={p?.cost || 0} /></div><div className="form-row"><FormInput name="stock" label="Stock quantity" type="number" min="0" step="1" value={p?.stock ?? 0} required /><label>GST rate<select name="gst_rate" defaultValue={p?.gst_rate || 0}>{[0, 5, 12, 18, 28, ...(p && ![0, 5, 12, 18, 28].includes(p.gst_rate) ? [p.gst_rate] : [])].map(rate => <option key={rate} value={rate}>{rate}%</option>)}</select></label></div><div className="form-row"><FormInput name="category" label="Category" value={p?.category || 'General'} /><FormInput name="min_stock" label="Low stock alert at" type="number" min="0" step="1" value={p?.min_stock ?? 5} /></div><FormInput name="barcode" label="Barcode / SKU" value={p?.barcode} placeholder="Scan or enter a barcode" /><FormActions close={close} label={p ? 'Save changes' : 'Add product'} /></form></Modal>; }
    if (dialog.kind === 'customer') { const c = dialog.customer; return <Modal title={c ? 'Edit customer' : 'Add a customer'} description="Keep their details handy and their balance organized." onClose={close}><form className="shop-form" onSubmit={e => saveForm(e, v => saveCustomer(current.current!, v, c?.id), c ? 'Customer details updated.' : 'Customer added.')}><FormInput name="name" label="Customer name" value={c?.name} required /><FormInput name="phone" label="Mobile number" type="tel" value={c?.phone} placeholder="10-digit mobile number" /><FormInput name="address" label="Address" value={c?.address} /><FormActions close={close} label={c ? 'Save changes' : 'Add customer'} /></form></Modal>; }
    if (dialog.kind === 'payment') { const customer = s.customers.find(c => c.id === dialog.customer.id)!; return <Modal title="Record payment" description={`${customer.name} · ${money(customer.outstanding)} outstanding`} onClose={close}><form className="shop-form" onSubmit={e => { e.preventDefault(); const values = new FormData(e.currentTarget); if (commit(p => receivePayment(p, customer.id, Number(values.get('amount')), values.get('mode') as PaymentMode, values.get('confirmed') === 'on'), 'Payment recorded. Customer balance updated.')) close(); }}><FormInput name="amount" label="Amount received (₹)" type="number" min="0.01" max={String(customer.outstanding)} step="0.01" value={customer.outstanding} required /><label>Payment method<select name="mode"><option value="cash">Cash</option><option value="upi">UPI</option><option value="card">Card</option></select></label><label className="shop-check"><input type="checkbox" name="confirmed" />I verified receipt of the UPI or card payment.</label><FormActions close={close} label="Record payment" /></form></Modal>; }
    if (dialog.kind === 'ledger') { const customer = s.customers.find(c => c.id === dialog.customer.id)!; const entries = (s.records.ledger || []).filter(row => row.customer_id === customer.id).sort((a, b) => b.created_at.localeCompare(a.created_at)); return <Modal title={`${customer.name}'s ledger`} description={`Current outstanding balance: ${money(customer.outstanding)}`} onClose={close} wide>{entries.length ? <div className="shop-table-scroll"><table className="shop-table"><thead><tr><th>Date</th><th>Activity</th><th>Amount</th></tr></thead><tbody>{entries.map(row => <tr key={row.id}><td>{displayDate(row.created_at)}</td><td><Badge type={row.type === 'credit_sale' ? 'amber' : 'green'}>{row.type === 'credit_sale' ? 'Credit sale' : 'Payment received'}</Badge></td><td className="strong">{money(Number(row.amount))}</td></tr>)}</tbody></table></div> : <Empty title="All clear so far" message="Credit sales and repayments will appear here." />}</Modal>; }
    if (dialog.kind === 'invoice') return <Modal title={shortInvoice(dialog.invoice)} description="Your sale, saved and ready to share." onClose={close} wide><Receipt state={s} invoice={dialog.invoice} /><div className="dialog-actions no-print"><button className="shop-button secondary" onClick={close}>Done</button><button className="shop-button primary" onClick={() => window.print()}><ReceiptText size={16} />Print / Save PDF</button></div></Modal>;
    if (dialog.kind === 'delete') return <Modal title={`Remove ${dialog.product.name}?`} description="Saved invoices keep the original product details." onClose={close}><div className="dialog-actions"><button className="shop-button secondary" onClick={close}>Cancel</button><button className="shop-button danger-button" onClick={() => { if (commit(p => deleteProduct(p, dialog.product.id), 'Product removed.')) { setCart(items => items.filter(i => i.product_id !== dialog.product.id)); close(); } }}>Remove product</button></div></Modal>;
    if (dialog.kind === 'reset') return <Modal title="Start a fresh demo?" description="This replaces demo products, sales, and customers with the sample shop." onClose={close}><div className="dialog-actions"><button className="shop-button secondary" onClick={close}>Keep my demo</button><button className="shop-button danger-button" onClick={() => { if (commit(p => ({ ...createDemo(), revision: p.revision + 1 }), 'Demo refreshed.')) { setCart([]); close(); } }}>Reset demo</button></div></Modal>;
    if (dialog.kind === 'module') { const schema = s.schemas[dialog.entity]; return <Modal title={dialog.record ? `Edit ${schema.label}` : `Add to ${schema.label}`} onClose={close}><form className="shop-form" onSubmit={event => { event.preventDefault(); const form = new FormData(event.currentTarget), values: Record<string, unknown> = { ...dialog.record }; try { for (const field of schema.fields) { const value = form.get(field.name); values[field.name] = ['bool', 'boolean'].includes(field.type) ? value === 'on' : ['json', 'multiselect', 'file', 'image', 'signature'].includes(field.type) ? value ? JSON.parse(String(value)) : null : value; } if (commit(p => saveModule(p, dialog.entity, values, dialog.record?.id), 'Record saved.')) close(); } catch { notify('Please check the structured field values.', true); } }}>{schema.fields.map(field => <ModuleField key={field.name} field={field} value={dialog.record?.[field.name] ?? field.default} state={s} />)}<FormActions close={close} label="Save record" /></form></Modal>; }
    return null;
  }
}

function Stat({ label, value, detail, icon, tone }: { label: string; value: string; detail: string; icon: ReactNode; tone: string }) { return <article className="stat-card"><div className="stat-heading"><span>{label}</span><span className={`stat-icon ${tone}`}>{icon}</span></div><strong className="stat-value">{value}</strong><span className="stat-detail">{detail}</span></article>; }
function SearchInput({ value, change, placeholder, onEnter }: { value: string; change: (value: string) => void; placeholder: string; onEnter?: () => void }) { return <label className="shop-search"><Search size={18} /><input aria-label={placeholder.replace('…', '')} placeholder={placeholder} value={value} onChange={e => change(e.target.value)} onKeyDown={e => { if (e.key === 'Enter') onEnter?.(); }} />{value && <button className="icon-button" aria-label="Clear search" onClick={() => change('')}><X size={16} /></button>}</label>; }
function FormInput({ name, label, value, ...props }: { name: string; label: string; value?: unknown; type?: string; required?: boolean; placeholder?: string; step?: string; min?: string; max?: string }) { return <label>{label}<input name={name} defaultValue={value === undefined ? '' : String(value)} {...props} /></label>; }
function FormActions({ close, label }: { close: () => void; label: string }) { return <div className="dialog-actions"><button type="button" className="shop-button secondary" onClick={close}>Cancel</button><button className="shop-button primary"><Check size={16} />{label}</button></div>; }
function Toast({ toast, close }: { toast: { text: string; error?: boolean }; close: () => void }) { return <div className={`shop-toast ${toast.error ? 'error' : ''}`} role={toast.error ? 'alert' : 'status'}>{toast.error ? <CircleHelp size={20} /> : <CheckCircle2 size={20} />}<span>{toast.text}</span><button className="icon-button" aria-label="Dismiss notification" onClick={close}><X size={17} /></button></div>; }
function ModuleField({ field, value, state }: { field: Field; value: unknown; state: ShopState }) {
  const label = field.label || field.name;
  if (['bool', 'boolean'].includes(field.type)) return <label className="shop-check"><input name={field.name} type="checkbox" defaultChecked={Boolean(value)} />{label}</label>;
  if (field.type === 'select' || field.type === 'relation') { const options = field.type === 'select' ? (field.options || []).map(o => ({ id: String(o), name: String(o) })) : field.target === 'customer' ? state.customers : field.target === 'product' ? state.products : (state.records[String(field.target)] || []).map(row => ({ id: row.id, name: String(row.name || row.title || row.id) })); return <label>{label}<select name={field.name} defaultValue={String(value || '')} required={field.required}><option value="">Select {label.toLowerCase()}</option>{options.map(o => <option value={o.id} key={o.id}>{o.name}</option>)}</select></label>; }
  if (['textarea', 'json', 'multiselect', 'file', 'image', 'signature'].includes(field.type)) return <label>{label}<textarea name={field.name} rows={3} defaultValue={typeof value === 'object' ? JSON.stringify(value) : String(value || '')} required={field.required} /></label>;
  return <FormInput name={field.name} label={label} value={value} type={['decimal', 'number'].includes(field.type) ? 'number' : field.type === 'datetime' ? 'datetime-local' : field.type === 'date' ? 'date' : 'text'} min={field.min === undefined ? undefined : String(field.min)} max={field.max === undefined ? undefined : String(field.max)} step={['decimal', 'number'].includes(field.type) ? 'any' : undefined} required={field.required} />;
}

function Checkout({ state, cart, setCart, commit, complete, notify }: { state: ShopState; cart: CartItem[]; setCart: React.Dispatch<React.SetStateAction<CartItem[]>>; commit: (update: (state: ShopState) => ShopState, message?: string) => boolean; complete: (invoice: Invoice) => void; notify: (text: string, error?: boolean) => void }) {
  const [mode, setMode] = useState<PaymentMode>('cash'), [customerId, setCustomerId] = useState(''), [discount, setDiscount] = useState('0'), [percent, setPercent] = useState('0'), [confirmed, setConfirmed] = useState(false);
  let totals: ReturnType<typeof billTotals> | undefined, error = '';
  try { totals = billTotals(state, cart, Number(discount), Number(percent)); } catch (failure) { error = (failure as Error).message; }
  function finish() {
    let invoice: Invoice | undefined;
    if (commit(previous => { const next = checkout(previous, cart, { mode, customerId: customerId || undefined, discount: Number(discount), percent: Number(percent), confirmed }); invoice = next.invoices[0]; return next; }, 'Sale completed. Invoice saved and inventory updated.') && invoice) { setDiscount('0'); setPercent('0'); setConfirmed(false); complete(invoice); }
  }
  const upi = state.shop.upi_id && totals ? `upi://pay?${new URLSearchParams({ pa: state.shop.upi_id, pn: state.shop.name, am: totals.total.toFixed(2), cu: 'INR', tn: 'ShopOS sale' })}` : '';
  return <section className="shop-panel checkout-panel"><div className="panel-title"><div><h2>Current bill</h2><p>{cart.reduce((sum, i) => sum + i.quantity, 0)} items in your cart</p></div>{cart.length > 0 && <button className="text-button danger" onClick={() => setCart([])}>Clear</button>}</div><div className="cart-items">{cart.length ? cart.map(item => { const p = state.products.find(p => p.id === item.product_id); if (!p) return <div className="shop-notice error" key={item.product_id}>Product removed. <button className="text-button" onClick={() => setCart(items => items.filter(i => i.product_id !== item.product_id))}>Remove from bill</button></div>; return <div className="cart-item" key={item.product_id}><ProductArt product={p} small /><div className="cart-item-info"><strong>{p.name}</strong><small>{money(p.price)} · GST {p.gst_rate}%</small><div className="quantity-control"><button aria-label={`Decrease ${p.name}`} onClick={() => setCart(items => item.quantity === 1 ? items.filter(i => i.product_id !== p.id) : items.map(i => i.product_id === p.id ? { ...i, quantity: i.quantity - 1 } : i))}><Minus size={13} /></button><span>{item.quantity}</span><button aria-label={`Increase ${p.name}`} disabled={item.quantity >= p.stock} onClick={() => setCart(items => items.map(i => i.product_id === p.id ? { ...i, quantity: i.quantity + 1 } : i))}><Plus size={13} /></button></div></div><div className="cart-item-price"><strong>{money(p.price * item.quantity)}</strong><button aria-label={`Remove ${p.name} from bill`} className="icon-button" onClick={() => setCart(items => items.filter(i => i.product_id !== p.id))}><X size={14} /></button></div></div>; }) : <Empty title="A fresh bill awaits" message="Choose products from the shelves to get started." />}</div><div className="checkout-details"><label>Customer<select aria-label="Sale customer" value={customerId} onChange={e => setCustomerId(e.target.value)}><option value="">Walk-in customer</option>{state.customers.map(c => <option value={c.id} key={c.id}>{c.name}</option>)}</select></label><div className="form-row"><label>Discount (₹)<input aria-label="Bill discount amount" type="number" step="0.01" min="0" value={discount} onChange={e => { setDiscount(e.target.value); setConfirmed(false); }} /></label><label>Discount (%)<input aria-label="Bill discount percent" type="number" step="0.01" min="0" max="100" value={percent} onChange={e => { setPercent(e.target.value); setConfirmed(false); }} /></label></div><label>Payment method</label><div className="payment-options">{(['cash', 'upi', 'card', 'credit'] as const).map(payment => <button key={payment} className={mode === payment ? 'active' : ''} aria-pressed={mode === payment} onClick={() => { setMode(payment); setConfirmed(false); }}>{payment === 'cash' ? <Wallet size={16} /> : payment === 'credit' ? <Users size={16} /> : <CreditCard size={16} />}<span>{payment === 'upi' ? 'UPI' : payment.charAt(0).toUpperCase() + payment.slice(1)}</span></button>)}</div>{mode === 'upi' && <p className="upi-detail">{upi ? <a className="text-button" href={upi}>Pay {money(totals!.total)} to {state.shop.upi_id} <ArrowUpRight size={14} /></a> : "Add your shop's UPI ID in Settings to enable a payment link."}</p>}{(mode === 'upi' || mode === 'card') && <label className="shop-check payment-confirm"><input type="checkbox" checked={confirmed} onChange={e => setConfirmed(e.target.checked)} />I verified that payment was received.</label>}{mode === 'credit' && <p className="upi-detail">Select a customer to add this sale to their outstanding balance.</p>}<div className="bill-totals"><p><span>Subtotal</span><span>{money(totals?.subtotal || 0)}</span></p><p><span>Discount</span><span>− {money(totals?.discountAmount || 0)}</span></p><p><span>GST</span><span>{money(totals?.tax || 0)}</span></p><p className="bill-total"><strong>Total amount</strong><strong>{money(totals?.total || 0)}</strong></p></div>{error && <p role="alert" className="shop-notice error">{error}</p>}<button className="shop-button primary complete-sale" disabled={!cart.length || !totals || (mode === 'credit' && !customerId) || ((mode === 'upi' || mode === 'card') && !confirmed)} onClick={finish}><CheckCircle2 size={18} />Complete sale <ArrowRight size={17} /></button><span className="checkout-reassurance"><ShieldCheck size={13} />Saved to your shop. Stock updated automatically.</span></div></section>;
}

function Settings({ state, commit, notify, reset }: { state: ShopState; commit: (update: (s: ShopState) => ShopState, message?: string) => boolean; notify: (text: string, error?: boolean) => void; reset: () => void }) {
  function handleLogo(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0]; if (!file) return;
    if (file.size > 500 * 1024) { notify('Logo must be under 500 KB.', true); return; }
    const reader = new FileReader();
    reader.onload = ev => { const logo = ev.target?.result as string; commit(p => ({ ...p, revision: p.revision + 1, shop: { ...p.shop, logo } }), 'Logo updated.'); };
    reader.readAsDataURL(file);
  }
  return <div className="settings-grid">
    <section className="shop-panel">
      <div className="panel-title"><div><h2>Shop identity</h2><p>Your brand on every invoice and screen.</p></div><Store size={20} /></div>
      <div className="logo-upload-row">
        <div className="logo-preview">{state.shop.logo ? <img src={state.shop.logo} alt="Shop logo" /> : <span style={{ fontSize: 36 }}>{businessEmoji(state.shop.business_type)}</span>}</div>
        <div>
          <label className="shop-button secondary file-label" style={{ display: 'inline-flex', marginBottom: 8 }}><ImagePlus size={15} />Upload logo<input type="file" accept="image/*" onChange={handleLogo} /></label>
          <p className="muted-text" style={{ marginTop: 4 }}>PNG, JPG or SVG · max 500 KB</p>
          {state.shop.logo && <button className="text-button danger" style={{ marginTop: 6, display: 'flex' }} onClick={() => commit(p => ({ ...p, revision: p.revision + 1, shop: { ...p.shop, logo: '' } }), 'Logo removed.')}>Remove logo</button>}
        </div>
      </div>
      <form className="shop-form" key={`${state.tenantId}:${state.shop.name}`} onSubmit={event => { event.preventDefault(); const values = Object.fromEntries(new FormData(event.currentTarget)); commit(p => saveSettings(p, values), 'Shop details saved.'); }}>
        <fieldset disabled={!can(state.role, 'settings')}>
          <FormInput name="name" label="Shop name" value={state.shop.name} required />
          <FormInput name="tagline" label="Tagline / Slogan" value={state.shop.tagline} placeholder="e.g. Fresh & affordable, every day" />
          <FormInput name="address" label="Shop address" value={state.shop.address} />
          <div className="form-row"><FormInput name="city" label="City" value={state.shop.city} placeholder="Mumbai" /><FormInput name="state" label="State" value={state.shop.state} placeholder="Maharashtra" /></div>
          <div className="form-row"><FormInput name="pincode" label="PIN code" value={state.shop.pincode} placeholder="400001" /><FormInput name="phone" label="Phone" type="tel" value={state.shop.phone} /></div>
          <div className="form-row"><FormInput name="whatsapp" label="WhatsApp number" type="tel" value={state.shop.whatsapp} placeholder="Same as phone" /><FormInput name="gstin" label="GSTIN" value={state.shop.gstin} /></div>
          <FormInput name="upi_id" label="UPI ID" value={state.shop.upi_id} placeholder="yourshop@upi" />
          <label>Business type<select name="business_type" defaultValue={state.shop.business_type || 'retail'}>{BUSINESS_TYPES.map(b => <option key={b.value} value={b.value}>{b.emoji} {b.label}</option>)}</select></label>
          <label>Invoice paper<select name="paper" defaultValue={state.shop.paper}><option value="a4">A4 invoice</option><option value="80mm">80 mm receipt</option></select></label>
          {can(state.role, 'settings') && <button className="shop-button primary"><Check size={16} />Save shop details</button>}
        </fieldset>
      </form>
    </section>
    <div className="settings-side">
      <section className="shop-panel"><div className="panel-title"><div><h2>Your data, handy</h2><p>Keep a copy of your shop's records.</p></div><Download size={20} /></div><button className="shop-button secondary full-width" onClick={() => download(`shopos-backup-${dayKey(new Date())}.json`, JSON.stringify(state, null, 2))}><ArrowDownToLine size={16} />Export shop backup</button>{state.demo && <label className="shop-button secondary full-width file-label" style={{ marginTop: 10 }}>Restore demo backup<input type="file" accept=".json,application/json" onChange={async e => { const file = e.target.files?.[0]; if (!file) return; try { const source = await file.text(); commit(p => restoreBackup(p, source), 'Shop backup restored.'); } catch (error) { notify((error as Error).message, true); } e.target.value = ''; }} /></label>}</section>
      <section className="shop-panel"><div className="panel-title"><div><h2>Your workspace</h2><p>{state.demo ? 'Explore the everyday possibilities.' : 'Your connected shop workspace.'}</p></div><Badge type="green">{state.demo ? 'Local demo' : state.shop.plan}</Badge></div><p className="muted-text">{state.demo ? 'Sample shop data is saved in this browser. Cloud sync becomes available when you sign in to a configured Supabase shop.' : `${state.outbox.length} changes waiting to sync. Your role: ${state.role}.`}</p><a className="text-button" href="/admin">Open administration <ArrowUpRight size={16} /></a>{state.demo && <button className="text-button danger reset-demo" onClick={reset}>Reset demo workspace</button>}</section>
    </div>
  </div>;
}

function Welcome({ mode, error, onDemo, onLogin, onOffline }: { mode: string; error: string; onDemo: () => void; onLogin: () => Promise<void>; onOffline: () => void }) {
  const [phone, setPhone] = useState(''), [code, setCode] = useState(''), [sent, setSent] = useState(false), [busy, setBusy] = useState(false), [message, setMessage] = useState('');
  const stats = [{ v: '2L+', l: 'Shops trust us' }, { v: '₹500Cr+', l: 'Billed monthly' }, { v: '28', l: 'States covered' }, { v: '99.9%', l: 'Uptime' }];
  return <div className="shop-welcome">
    <section className="welcome-story">
      <a className="shop-brand" href="/"><span className="shop-logo"><Store size={24} /></span><span>Shop<span className="brand-os">OS</span></span></a>
      <div>
        <span className="eyebrow">INDIA'S MOST POWERFUL SHOP TOOL</span>
        <h1>Apna dukaan,<br />apna hisaab.</h1>
        <p>Billing · Inventory · Customers · Reports · GST<br />Works offline. Syncs to cloud. Made for Bharat.</p>
        <div className="welcome-biz-types">{BUSINESS_TYPES.slice(0, 6).map(b => <span key={b.value} className="biz-chip">{b.emoji} {b.label}</span>)}</div>
        <div className="welcome-stats">{stats.map(s => <div key={s.l}><strong>{s.v}</strong><span>{s.l}</span></div>)}</div>
      </div>
      <div className="welcome-features-list">
        {[['⚡', 'Fast billing with GST & UPI'], ['📦', 'Live inventory & low stock alerts'], ['👥', 'Customer credit & ledger'], ['📊', 'Daily/weekly/monthly reports'], ['📱', 'Works offline, syncs automatically'], ['🔒', 'Secure · Private · Made in India']].map(([icon, text]) => <div key={text} className="welcome-feature"><span>{icon}</span>{text}</div>)}
      </div>
    </section>
    <section className="welcome-form">
      <div className="welcome-form-brand"><span className="shop-logo" style={{ width: 52, height: 52, borderRadius: 14 }}><Store size={26} /></span><div><h2>Welcome to ShopOS</h2><p className="muted-text">India's smartest shop management tool</p></div></div>
      {error && <p role="alert" className="shop-notice error">{error}</p>}
      {message && <p role="status" className="shop-notice">{message}</p>}
      {mode === 'live' && <form className="shop-form" onSubmit={async event => { event.preventDefault(); setBusy(true); setMessage(''); try { await api('/api/shop/auth', { action: sent ? 'verify_otp' : 'send_otp', phone, token: code }); if (sent) await onLogin(); else { setSent(true); setMessage('OTP sent to your mobile number.'); } } catch (error) { setMessage((error as Error).message); } finally { setBusy(false); } }}>
        <label>Mobile number<input type="tel" autoComplete="tel" placeholder="98765 43210" value={phone} onChange={e => setPhone(e.target.value)} required disabled={sent} /></label>
        {sent && <label>OTP (6 digits)<input inputMode="numeric" autoComplete="one-time-code" pattern="\d{6}" maxLength={6} value={code} onChange={e => setCode(e.target.value)} required /></label>}
        <button className="shop-button primary" disabled={busy}>{busy ? 'Please wait…' : sent ? 'Open my shop →' : 'Get OTP & sign in'}<ArrowRight size={16} /></button>
        {sent && <button className="text-button" type="button" onClick={() => { setSent(false); setCode(''); setMessage(''); }}>Use a different number</button>}
      </form>}
      <div className="welcome-divider"><span>or</span></div>
      <button className={`shop-button ${mode === 'demo' ? 'primary' : 'secondary'} full-width`} onClick={onDemo}><Sparkles size={16} />Try free demo — no signup needed</button>
      {mode === 'live' && <button className="text-button offline-link" onClick={onOffline}><WifiOff size={15} />Open saved workspace offline</button>}
      <p className="welcome-note">🇮🇳 Made in India · GST ready · Works offline</p>
      <a className="text-button" style={{ justifyContent: 'center', marginTop: 4 }} href="/admin">Administration <ArrowUpRight size={15} /></a>
    </section>
  </div>;
}
