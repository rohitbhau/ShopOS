import { ArrowRight, BarChart3, CheckCircle2, MessageCircle, Package, ReceiptIndianRupee, Shield, Smartphone, Wifi, Zap } from 'lucide-react';

const plans = [
  { name: 'Free', price: '₹0', desc: 'Forever free', features: ['Unlimited billing', 'Inventory management', 'Customer ledger', 'Works offline', 'PDF invoices'] },
  { name: 'Basic', price: '₹149', desc: 'Per month', features: ['Everything in Free', 'WhatsApp invoices', 'CSV exports', 'Multi-device sync', 'Email support'] },
  { name: 'Standard', price: '₹299', desc: 'Per month', features: ['Everything in Basic', 'GST reports', 'Staff accounts', 'Low stock alerts', 'Priority support'], featured: true },
  { name: 'Pro', price: '₹599', desc: 'Per month', features: ['Everything in Standard', 'Unlimited staff', 'Custom templates', 'API access', 'Dedicated support'] },
];

const bizTypes = ['🛒 Kirana', '🍽️ Restaurant', '💊 Pharmacy', '👗 Boutique', '✂️ Salon', '🔧 Repair', '📱 Electronics', '🎂 Bakery', '🔨 Hardware', '🏥 Clinic', '🏪 Retail', '🏢 Any business'];

export default function LandingPage() {
  return <main>
    <div className="shell">
      <nav className="nav">
        <a className="logo" href="#top"><span className="logo-mark">S</span>ShopOS</a>
        <div className="nav-links"><a href="#features">Features</a><a href="#pricing">Pricing</a><a href="#faq">FAQ</a></div>
        <a className="nav-cta" href="/">Open app <ArrowRight size={15} /></a>
      </nav>

      <section className="hero" id="top">
        <div className="hero-content">
          <div className="hero-badge">🇮🇳 Made in India · GST Ready · Works Offline</div>
          <h1>India's most powerful<br /><span className="hero-accent">shop management tool.</span></h1>
          <p>Billing, inventory, customers, credit, and reports — all in one place. Built for kirana stores, restaurants, pharmacies, boutiques, and every shop in between.</p>
          <div className="hero-actions">
            <a className="hero-cta" href="/">Start free — no card needed <ArrowRight size={17} /></a>
            <a className="hero-secondary" href="/">See demo</a>
          </div>
          <div className="hero-biz-types">{bizTypes.map(b => <span key={b} className="hero-biz-chip">{b}</span>)}</div>
        </div>
        <div className="hero-art" aria-label="ShopOS dashboard preview">
          <div className="hero-card">
            <div className="hero-card-header"><span className="hero-dot green" /><span>Today's sales</span><strong>₹12,480</strong></div>
            <div className="hero-bill"><div className="hero-bill-row"><span>Basmati Rice 2kg</span><span>₹240</span></div><div className="hero-bill-row"><span>Tata Tea Gold</span><span>₹135</span></div><div className="hero-bill-row"><span>Amul Butter</span><span>₹58</span></div><div className="hero-bill-total"><span>Total</span><strong>₹433</strong></div></div>
            <div className="hero-payment-row"><span className="hero-pay-chip cash">Cash</span><span className="hero-pay-chip upi">UPI</span><span className="hero-pay-chip card">Card</span><span className="hero-pay-chip credit">Credit</span></div>
          </div>
          <div className="hero-stats-row">
            <div className="hero-stat"><strong>2L+</strong><span>Shops</span></div>
            <div className="hero-stat"><strong>₹500Cr+</strong><span>Billed</span></div>
            <div className="hero-stat"><strong>28</strong><span>States</span></div>
          </div>
        </div>
      </section>
    </div>

    <section className="band" id="features">
      <div className="shell">
        <div className="section-heading">
          <div className="eyebrow">Less paperwork, more selling</div>
          <h2>Everything your shop needs.<br />Nothing it doesn't.</h2>
          <p>ShopOS is built around the way Indian shops actually work — quick hands, patchy networks, and customers who come back tomorrow.</p>
        </div>
        <div className="features">
          <Feature icon={<ReceiptIndianRupee />} title="Fast GST billing" text="Search or scan products, take cash, UPI, card, or credit. Generate GST-compliant invoices in seconds." />
          <Feature icon={<Package />} title="Live inventory" text="Every sale updates stock automatically. Get alerts before you run out of your bestsellers." />
          <Feature icon={<BarChart3 />} title="Smart reports" text="Daily, weekly, monthly sales. Payment mix, top products, outstanding credit — all at a glance." />
          <Feature icon={<MessageCircle />} title="WhatsApp ready" text="Share invoices and payment reminders where your customers already are." />
          <Feature icon={<Wifi />} title="Works offline" text="No internet? No problem. ShopOS keeps working and syncs everything when you're back online." />
          <Feature icon={<Shield />} title="Secure & private" text="Your data stays yours. Encrypted, backed up, and never sold to anyone." />
        </div>
      </div>
    </section>

    <section className="templates-band">
      <div className="shell">
        <div className="section-heading">
          <div className="eyebrow">Built for every business</div>
          <h2>Your shop type, your template.</h2>
          <p>Sign up, pick your business type, and ShopOS sets up the right screens, modules, and workflows for you automatically.</p>
        </div>
        <div className="template-chips">{bizTypes.map(b => <span key={b} className="template-chip">{b}</span>)}</div>
      </div>
    </section>

    <section className="pricing" id="pricing">
      <div className="shell">
        <div className="section-heading">
          <div className="eyebrow">Simple pricing</div>
          <h2>Start free. Grow when you're ready.</h2>
          <p>Every plan includes offline billing, GST invoices, inventory, and customer management. No hidden charges.</p>
        </div>
        <div className="price-grid">{plans.map(plan => <div className={`price-card ${plan.featured ? 'featured' : ''}`} key={plan.name}>
          {plan.featured && <div className="price-badge">Most popular</div>}
          <h3>{plan.name}</h3>
          <div className="price">{plan.price}<small>/{plan.desc === 'Forever free' ? 'forever' : 'month'}</small></div>
          <ul className="price-features">{plan.features.map(f => <li key={f}><CheckCircle2 size={13} />{f}</li>)}</ul>
          <a href="/" className={plan.featured ? 'price-cta-primary' : 'price-cta'}>Get started free</a>
        </div>)}</div>
      </div>
    </section>

    <section className="faq-band" id="faq">
      <div className="shell">
        <div className="section-heading"><div className="eyebrow">FAQ</div><h2>Common questions</h2></div>
        <div className="faq-grid">
          {[['Does it work without internet?', 'Yes. ShopOS works fully offline. All your sales, inventory, and customer data are saved on your device. When you come back online, everything syncs automatically.'],
            ['Is it GST compliant?', 'Yes. ShopOS generates GST-compliant invoices with CGST/SGST breakdowns. You can add your GSTIN and it appears on every invoice.'],
            ['Can I use it on mobile?', 'Yes. The web app works on any browser including mobile. A dedicated Flutter app for Android and iOS is also available.'],
            ['How do I migrate my existing data?', 'You can import products via CSV. Customer and invoice data can be added manually or via our import tools.'],
            ['Is my data safe?', 'Your data is encrypted and stored securely. We never sell your data. You can export a full backup anytime.'],
          ].map(([q, a]) => <div key={q} className="faq-item"><strong>{q}</strong><p>{a}</p></div>)}
        </div>
      </div>
    </section>

    <section className="cta-band">
      <div className="shell">
        <h2>Ready to run your shop smarter?</h2>
        <p>Join 2 lakh+ shop owners across India who use ShopOS every day.</p>
        <a className="hero-cta" href="/">Start free today <ArrowRight size={17} /></a>
      </div>
    </section>

    <footer className="footer">
      <div className="shell">
        <span>🇮🇳 © 2026 ShopOS · Made in India</span>
        <span style={{ float: 'right' }}>Your shop. Your numbers. Your way.</span>
      </div>
    </footer>
  </main>;
}

function Feature({ icon, title, text }: { icon: React.ReactNode; title: string; text: string }) {
  return <article className="feature"><span>{icon}</span><h3>{title}</h3><p>{text}</p></article>;
}
