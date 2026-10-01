'use client';

import { useCallback, useEffect, useState } from 'react';
import { BarChart3, Boxes, Flag, GitBranch, LayoutDashboard, MessageSquare, Settings, Store, Layers, LogOut, RefreshCw } from 'lucide-react';
import { planPrices, type Snapshot, type TenantDetail, type Plan } from '../../../packages/shared/shopos';
import { demoDetail, demoSnapshot, demoStorageKey, mutateDemo } from '../src/demo';
import Builder from './Builder';
import WorkflowEditor from './WorkflowEditor';

const navigation = [['Overview', LayoutDashboard], ['Tenants', Store], ['Low-code builder', Boxes], ['Workflows', GitBranch], ['Templates', Layers], ['Subscriptions', BarChart3], ['WhatsApp logs', MessageSquare], ['Feature flags', Flag], ['Settings', Settings]] as const;
type Command = (input: Record<string, unknown>) => Promise<void>;
export const money = (amount: number) => new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 2 }).format(amount);
export const date = (value?: string) => value ? new Date(value).toLocaleString() : '—';

export default function Console({ mode }: { mode: 'live' | 'demo' | 'incomplete' }) {
  const [identity, setIdentity] = useState('');
  const [section, setSection] = useState('Overview');
  const [snapshot, setSnapshot] = useState<Snapshot | null>(null);
  const [tenantId, setTenantId] = useState('');
  const [detail, setDetail] = useState<TenantDetail | null>(null);
  const [error, setError] = useState(''); const [notice, setNotice] = useState(''); const [busy, setBusy] = useState(false);
  const [query, setQuery] = useState(''); const [plan, setPlan] = useState(''); const [status, setStatus] = useState(''); const [type, setType] = useState('');
  const [readonly, setReadonly] = useState(false);
  const api = useCallback(async (input: Record<string, unknown>) => {
    const response = await fetch('/api/admin', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(input) });
    const data = await response.json();
    if (!response.ok) { if (response.status === 401 || response.status === 403) { setIdentity(''); setSnapshot(null); } throw new Error(data.error || 'The request failed.'); }
    return data;
  }, []);
  const refresh = useCallback(async () => {
    setBusy(true); setError('');
    try { const data = await api({ action: 'snapshot' }) as Snapshot; setSnapshot(data); setTenantId((previous) => data.tenants.some((tenant) => tenant.id === previous) ? previous : data.tenants[0]?.id ?? ''); }
    catch (failure) { setError((failure as Error).message); } finally { setBusy(false); }
  }, [api]);
  useEffect(() => {
    if (mode !== 'live') return;
    void fetch('/api/auth').then(async (response) => { if (response.ok) { const data = await response.json(); setIdentity(data.email ?? 'Super admin'); } }).catch(() => setError('Could not connect to the authentication service.'));
  }, [mode]);
  useEffect(() => { if (identity && mode === 'live') void refresh(); }, [identity, mode, refresh]);
  useEffect(() => {
    setDetail(null); setReadonly(false);
    if (!tenantId || !identity) return;
    if (mode === 'demo') { if (snapshot) setDetail(demoDetail(snapshot, tenantId)); return; }
    let cancelled = false;
    void api({ action: 'tenant_detail', tenant_id: tenantId }).then((data) => { if (!cancelled) setDetail(data); }).catch((failure) => { if (!cancelled) setError((failure as Error).message); });
    return () => { cancelled = true; };
  }, [tenantId, identity, mode, api, snapshot]);
  function openDemo() {
    try {
      const stored = localStorage.getItem(demoStorageKey);
      const data = stored ? JSON.parse(stored) as Snapshot : demoSnapshot();
      if (!Array.isArray(data.tenants) || !Array.isArray(data.entities)) throw new Error('Local demo data is invalid. Clear the ShopOS demo entry in browser storage.');
      setSnapshot(data); setTenantId(data.tenants[0]?.id ?? ''); setIdentity('Local demo'); setError('');
    } catch (failure) { setError((failure as Error).message); }
  }
  const command: Command = async (input) => {
    if (!snapshot) return;
    setError(''); setNotice(''); setBusy(true);
    try {
      const body = { tenant_id: tenantId, ...input };
      if (mode === 'demo') {
        const next = mutateDemo(snapshot, body); localStorage.setItem(demoStorageKey, JSON.stringify(next)); setSnapshot(next);
        setNotice('Saved to this browser’s local demo.');
      } else { const result = await api(body); await refresh(); setNotice(result.message || 'Saved successfully.'); }
    } catch (failure) { setError((failure as Error).message); throw failure; }
    finally { setBusy(false); }
  };
  async function signOut() {
    if (mode === 'live') { const response = await fetch('/api/auth', { method: 'DELETE' }); if (!response.ok) { setError('Sign-out failed. Please retry.'); return; } }
    setIdentity(''); setSnapshot(null); setDetail(null); setNotice('');
  }
  if (!identity) return <div className="login-shell"><section className="panel login"><div className="brand dark"><span className="brand-mark">S</span>ShopOS Admin</div><h1>Welcome back</h1><p className="muted">Operations, schemas, and shop support in one place.</p>{error && <p className="error" role="alert">{error}</p>}{mode === 'demo' ? <><p className="banner">Supabase is not configured. Explore sample data in a local demo. Edits are saved only in this browser.</p><button className="primary" onClick={openDemo}>Open local demo</button></> : mode === 'incomplete' ? <p className="error">The server configuration is incomplete. Set both SUPABASE_URL and SUPABASE_ANON_KEY, then restart.</p> : <form className="stack" onSubmit={async (event) => {
    event.preventDefault(); setBusy(true); setError(''); const form = new FormData(event.currentTarget);
    try { const response = await fetch('/api/auth', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email: form.get('email'), password: form.get('password') }) }); const data = await response.json(); if (!response.ok) throw new Error(data.error); setIdentity(data.email ?? 'Super admin'); }
    catch (failure) { setError((failure as Error).message); } finally { setBusy(false); }
  }}><label>Email<input required name="email" type="email" autoComplete="username" /></label><label>Password<input required name="password" type="password" autoComplete="current-password" /></label><button className="primary" disabled={busy}>{busy ? 'Signing in…' : 'Sign in'}</button><small className="muted">Use your provisioned super-admin account. Shop-owner accounts do not have console access.</small></form>}</section></div>;
  const selectedTenant = snapshot?.tenants.find((tenant) => tenant.id === tenantId);
  const apps = snapshot?.apps.filter((app) => app.tenant_id === tenantId) ?? [];
  const filtered = snapshot?.tenants.filter((tenant) => `${tenant.name} ${tenant.phone ?? ''}`.toLowerCase().includes(query.toLowerCase()) && (!plan || tenant.plan === plan) && (!status || tenant.is_active === (status === 'active')) && (!type || tenant.shop_type === type)) ?? [];
  const activeSubscriptions = snapshot?.subscriptions.filter((subscription) => subscription.status === 'active') ?? [];
  const mrr = activeSubscriptions.reduce((total, subscription) => total + planPrices[subscription.plan], 0);
  return <div className="admin-shell"><aside className="sidebar"><div className="brand"><span className="brand-mark">S</span>ShopOS Admin</div><nav aria-label="Main navigation">{navigation.map(([label, Icon]) => <button className={`nav-item ${section === label ? 'active' : ''}`} key={label} onClick={() => { setSection(label); setReadonly(false); }}><Icon size={17} />{label}</button>)}</nav><div className="sidebar-footer">{mode === 'demo' ? 'LOCAL DEMO' : 'LIVE ADMIN'}<br />{identity}</div></aside><main className="content"><header className="topbar"><div><h1>{section}</h1><p>Keep the shop network healthy and useful.</p></div><div className="actions"><button aria-label="Refresh data" disabled={busy || mode === 'demo'} onClick={() => void refresh()}><RefreshCw size={16} /></button><button onClick={() => void signOut()}><LogOut size={16} /> Sign out</button></div></header>
    {mode === 'demo' && <p className="banner">Local demo · Sample data · No messages or payments are sent. Edits stay in this browser.</p>}
    {error && <p role="alert" className="error">{error}</p>}{notice && <p role="status" className="success">{notice}</p>}{busy && <p role="status" className="muted">Working…</p>}
    {!snapshot ? <section className="panel"><p>{busy ? 'Loading shops…' : 'No data loaded.'}</p><button onClick={() => void refresh()} disabled={busy}>Retry</button></section> : <>
      {snapshot.notices?.filter((text) => !text.startsWith('Local demo')).map((text) => <p className="banner" key={text}>{text}</p>)}
      <div className="shop-selector"><label>Selected shop <select value={tenantId} onChange={(event) => setTenantId(event.target.value)}><option value="">Select a shop</option>{snapshot.tenants.map((tenant) => <option value={tenant.id} key={tenant.id}>{tenant.name}</option>)}</select></label>{apps[0] && <span className="muted">Schema v{apps[0].schema_version ?? 1} · Published {date(apps[0].published_at)}</span>}</div>
      {section === 'Overview' && <><div className="metrics"><Metric label="Shops loaded" value={String(snapshot.tenants.length)} /><Metric label="Active subscriptions" value={String(activeSubscriptions.length)} /><Metric label="Estimated monthly revenue" value={money(mrr)} /><Metric label="Paid invoices loaded" value={money(snapshot.invoices.filter((invoice) => invoice.status === 'paid').reduce((sum, invoice) => sum + invoice.amount_paise / 100, 0))} /></div><p className="muted">Metrics cover the loaded records. Revenue estimate uses published monthly plan prices; it excludes tax, discounts, and refunds. Payment history is the source of actual receipts.</p><section className="panel"><h2>Recent administration activity</h2><AuditTable items={snapshot.audit} /></section></>}
      {section === 'Tenants' && <div className="stack"><section className="panel"><div className="filter-row"><input aria-label="Search shops" placeholder="Search shop or phone" value={query} onChange={(event) => setQuery(event.target.value)} /><select aria-label="Plan filter" value={plan} onChange={(event) => setPlan(event.target.value)}><option value="">All plans</option>{Object.keys(planPrices).map((value) => <option key={value}>{value}</option>)}</select><select aria-label="Status filter" value={status} onChange={(event) => setStatus(event.target.value)}><option value="">All statuses</option><option value="active">Active</option><option value="inactive">Inactive</option></select><select aria-label="Shop type filter" value={type} onChange={(event) => setType(event.target.value)}><option value="">All shop types</option>{Array.from(new Set(snapshot.tenants.map((tenant) => tenant.shop_type))).map((value) => <option key={value}>{value}</option>)}</select></div><div className="table-wrap"><table className="table"><thead><tr><th>Shop</th><th>Type</th><th>Plan</th><th>Status</th><th>Details</th></tr></thead><tbody>{filtered.map((tenant) => <tr key={tenant.id}><td>{tenant.name}</td><td>{tenant.shop_type}</td><td>{tenant.plan}</td><td>{tenant.is_active ? 'Active' : 'Inactive'}</td><td><button onClick={() => setTenantId(tenant.id)}>Open</button></td></tr>)}</tbody></table>{!filtered.length && <p>No matching shops.</p>}</div></section>{selectedTenant && <section className="panel"><div className="panel-heading"><h2>{selectedTenant.name}</h2><button disabled={busy} onClick={() => { void command({ action: 'readonly_view' }).then(() => setReadonly(true)).catch(() => {}); }}>Open read-only shop view</button></div><p>Created {date(selectedTenant.created_at)} · Trial ends {date(selectedTenant.trial_ends_at)} · {detail?.usage.records ?? '…'} records</p>{readonly && <p className="banner">Read-only support view. Opening this view was recorded in the audit log. No shop session or write access is granted.</p>}<h3>Team</h3>{detail?.members.map((member) => <p key={member.id}>{member.profiles?.name || member.profiles?.phone || member.id} · {member.role} · {member.is_active ? 'active' : 'inactive'}</p>)}{detail && !detail.members.length && <p>No memberships found.</p>}{readonly && <><h3>Recent shop records (up to 100)</h3>{!detail?.records.length ? <p>No records found.</p> : <pre>{JSON.stringify(detail.records, null, 2)}</pre>}</>}<h3>Audit trail</h3><AuditTable items={detail?.audit ?? []} /></section>}</div>}
      {section === 'Low-code builder' && (apps.length ? <Builder key={tenantId} entities={snapshot.entities.filter((entity) => apps.some((app) => app.id === entity.app_id))} apps={apps} command={command} busy={busy} storageScope={`${mode}:${tenantId}`} /> : <EmptyShop />)}
      {section === 'Workflows' && (apps.length ? <WorkflowEditor key={tenantId} workflows={snapshot.workflows.filter((workflow) => apps.some((app) => app.id === workflow.app_id))} apps={apps} entities={snapshot.entities.filter((entity) => apps.some((app) => app.id === entity.app_id))} command={command} busy={busy} /> : <EmptyShop />)}
      {section === 'Templates' && <div className="template-grid">{snapshot.templates.map((template) => <section className="panel" key={template.key}><h2>{template.name}</h2><p>{template.entities.map((entity) => entity.label || entity.name).join(', ')}</p><p className="muted">{template.workflows?.length ?? 0} workflows. Adds missing entities; existing records are preserved.</p><details><summary>Preview template</summary><pre>{JSON.stringify(template, null, 2)}</pre></details><button className="primary" disabled={!tenantId || busy} onClick={() => { if (window.confirm(`Add missing ${template.name} entities to ${selectedTenant?.name}?`)) void command({ action: 'templates', template_key: template.key }).catch(() => {}); }}>Apply to selected shop</button></section>)}</div>}
      {section === 'Subscriptions' && (selectedTenant ? <Subscriptions snapshot={snapshot} tenantId={tenantId} command={command} busy={busy} /> : <EmptyShop />)}
      {section === 'WhatsApp logs' && <section className="panel"><h2>Message delivery</h2><p className="muted">Select a shop above. Delivery status is supplied by the provider webhook.</p><div className="table-wrap"><table className="table"><thead><tr><th>Time</th><th>Recipient</th><th>Template</th><th>Status</th><th>Error</th></tr></thead><tbody>{snapshot.whatsapp.filter((log) => !tenantId || log.tenant_id === tenantId).map((log) => <tr key={log.id}><td>{date(log.created_at)}</td><td>{log.recipient}</td><td>{log.template}</td><td>{log.status}</td><td>{log.error || '—'}</td></tr>)}</tbody></table>{!snapshot.whatsapp.some((log) => !tenantId || log.tenant_id === tenantId) && <p>No message logs found.</p>}</div></section>}
      {section === 'Feature flags' && <section className="panel"><h2>Platform feature flags</h2><p className="muted">Updates affect the configured percentage of eligible shops after their next configuration refresh.</p>{snapshot.flags.map((flag) => <form className="flag-row" key={`${flag.key}:${flag.updated_at ?? flag.enabled}:${flag.rollout_percent}`} onSubmit={(event) => { event.preventDefault(); const form = new FormData(event.currentTarget); void command({ action: 'update_flag', flag: { ...flag, enabled: form.get('enabled') === 'on', rollout_percent: Number(form.get('rollout')) } }).catch(() => {}); }}><div><strong>{flag.key}</strong><p className="muted">{flag.description}</p></div><label className="check"><input type="checkbox" name="enabled" defaultChecked={flag.enabled} />Enabled</label><label>Rollout %<input type="number" name="rollout" min="0" max="100" step="1" required defaultValue={flag.rollout_percent} /></label><button disabled={busy}>Save</button></form>)}</section>}
      {section === 'Settings' && <section className="panel"><h2>Connection and access</h2><p>Mode: {mode === 'live' ? 'Connected to Supabase' : 'Local demo'}</p><p>Signed in as {identity}</p><p>Admin access is granted through trusted authentication metadata. Access tokens and refresh tokens are stored in HTTP-only cookies.</p><p>Manage provider credentials and admin account provisioning on the server. See <code>packages/docs/web.md</code> for setup and operations.</p><h3>Error monitoring</h3><p>Request errors appear above and Edge Function failures are recorded in Supabase function logs. Configure your deployment’s monitoring integration before launch.</p>{mode === 'demo' && <button onClick={() => { if (window.confirm('Reset all local demo edits?')) { localStorage.removeItem(demoStorageKey); const data = demoSnapshot(); setSnapshot(data); setTenantId(data.tenants[0].id); setNotice('Local demo reset.'); } }}>Reset local demo</button>}</section>}
    </>}
  </main></div>;
}
function Metric({ label, value }: { label: string; value: string }) { return <div className="metric"><div className="metric-label">{label}</div><div className="metric-value">{value}</div></div>; }
function EmptyShop() { return <section className="panel"><p>Select a shop with an app to continue. New shops are created through mobile onboarding.</p></section>; }
function AuditTable({ items }: { items: Snapshot['audit'] }) { return !items.length ? <p className="muted">No audit events found.</p> : <div className="table-wrap"><table className="table"><thead><tr><th>Time</th><th>Action</th><th>Entity</th></tr></thead><tbody>{items.slice(0, 100).map((item) => <tr key={item.id}><td>{date(item.created_at)}</td><td>{item.action}</td><td>{item.entity || '—'}<details><summary>Details</summary><pre>{JSON.stringify(item.diff || item.metadata || {}, null, 2)}</pre></details></td></tr>)}</tbody></table></div>; }
function Subscriptions({ snapshot, tenantId, command, busy }: { snapshot: Snapshot; tenantId: string; command: Command; busy: boolean }) {
  const tenant = snapshot.tenants.find((item) => item.id === tenantId)!;
  const subscriptions = snapshot.subscriptions.filter((item) => item.tenant_id === tenantId);
  const invoices = snapshot.invoices.filter((item) => item.tenant_id === tenantId);
  const [nextPlan, setNextPlan] = useState<Plan>('basic');
  return <div className="stack"><section className="panel"><h2>{tenant.name} · {tenant.plan}</h2><p>Trial ends: {date(tenant.trial_ends_at)}</p>{subscriptions.map((subscription) => <p key={subscription.id}>{subscription.plan} · {subscription.status} · Period ends {date(subscription.current_period_end)}</p>)}{!subscriptions.length && <p>No subscription exists yet.</p>}<form className="actions" onSubmit={(event) => { event.preventDefault(); const form = new FormData(event.currentTarget); void command({ action: 'extend_trial', days: Number(form.get('days')) }).catch(() => {}); }}><label>Extend trial (days)<input type="number" name="days" min="1" max="90" step="1" defaultValue="7" required /></label><button disabled={busy}>Extend trial</button></form><hr /><p className="muted">Paid plan changes and cancellations are sent to Razorpay. Entitlements follow confirmed provider events.</p><div className="actions"><select aria-label="New plan" value={nextPlan} onChange={(event) => setNextPlan(event.target.value as Plan)}>{(['basic', 'standard', 'pro'] as Plan[]).map((plan) => <option key={plan} value={plan}>{plan} · {money(planPrices[plan])}/month</option>)}</select><button disabled={busy || !subscriptions.some((item) => item.razorpay_sub_id)} onClick={() => { if (window.confirm(`Request a plan change to ${nextPlan} for ${tenant.name}?`)) void command({ action: 'subscription_action', subscription_action: 'change_plan', plan: nextPlan }).catch(() => {}); }}>Change paid plan</button><button disabled={busy || !subscriptions.length || subscriptions.every((item) => item.status === 'cancelled')} onClick={() => { if (window.confirm(`Cancel the subscription for ${tenant.name}?`)) void command({ action: 'subscription_action', subscription_action: 'cancel' }).catch(() => {}); }}>Cancel subscription</button></div></section><section className="panel"><h2>Payment history</h2>{!invoices.length ? <p>No SaaS invoices found.</p> : <div className="table-wrap"><table className="table"><thead><tr><th>Date</th><th>Amount</th><th>Status</th><th>Action</th></tr></thead><tbody>{invoices.map((invoice) => <tr key={invoice.id}><td>{date(invoice.created_at)}</td><td>{money(invoice.amount_paise / 100)}</td><td>{invoice.status}</td><td><button disabled={busy || invoice.status !== 'paid'} onClick={() => { if (window.confirm(`Refund ${money(invoice.amount_paise / 100)}? This requests a real provider refund.`)) void command({ action: 'subscription_action', subscription_action: 'refund', invoice_id: invoice.id }).catch(() => {}); }}>Refund</button></td></tr>)}</tbody></table></div>}</section></div>;
}
