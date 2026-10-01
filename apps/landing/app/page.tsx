import { ArrowRight, BarChart3, MessageCircle, Package, ReceiptIndianRupee, Smartphone } from 'lucide-react';

const plans = [
  ['Free', '₹0', 'For getting started'],
  ['Basic', '₹149', 'Simple daily billing'],
  ['Standard', '₹299', 'WhatsApp and reports'],
  ['Pro', '₹599', 'For growing teams'],
];

export default function LandingPage() {
  return <main>
    <div className="shell">
      <nav className="nav"><a className="logo" href="#top"><span className="logo-mark">S</span>ShopOS</a><div className="nav-links"><a href="#features">What you get</a><a href="#pricing">Pricing</a><a href="#faq">FAQ</a></div><a className="nav-cta" href="https://wa.me/919999999999">Talk to us <ArrowRight size={16} /></a></nav>
      <section className="hero" id="top"><div><div className="eyebrow">Made for India&apos;s everyday shops</div><h1>Run your shop from your phone.</h1><p>Billing, stock, customer accounts, and reports in one calm little app. It keeps working when the internet doesn&apos;t.</p><div className="hero-actions"><a className="hero-cta" href="#pricing">Start your 14-day trial <ArrowRight size={17} /></a><span className="hero-note">No card required</span></div></div><div className="hero-art" aria-label="Shop counter with inventory and billing"><div className="receipt"><strong>Today&apos;s bill</strong><div className="receipt-row"><span>Rice 1 kg</span><span>₹72</span></div><div className="receipt-row"><span>Soap × 2</span><span>₹70</span></div><div className="receipt-row"><span>Total</span><b>₹142</b></div></div></div></section>
    </div>
    <section className="band" id="features"><div className="shell"><div className="section-heading"><div className="eyebrow">Less paperwork, more selling</div><h2>The useful bits, without the fuss.</h2><p>ShopOS is built around the way small shops actually work: quick hands, patchy networks, and customers who come back tomorrow.</p></div><div className="features"><Feature icon={<ReceiptIndianRupee />} title="Fast billing" text="Search or scan products, take cash or UPI, and save a clean invoice in seconds." /><Feature icon={<Package />} title="Stock that stays current" text="Every sale updates inventory and flags the items that need attention." /><Feature icon={<BarChart3 />} title="Reports you can read" text="See sales, payment mix, top items, and outstanding credit at a glance." /><Feature icon={<MessageCircle />} title="WhatsApp ready" text="Share invoices and payment reminders where your customers already are." /></div></div></section>
    <section className="pricing" id="pricing"><div className="shell"><div className="section-heading"><div className="eyebrow">Simple pricing</div><h2>Start small. Grow when you&apos;re ready.</h2><p>Every plan includes offline billing, secure backups, and a shop owner&apos;s peace of mind.</p></div><div className="price-grid">{plans.map(([name, price, description], index) => <div className={`price-card ${index === 2 ? 'featured' : ''}`} key={name}><h3>{name}</h3><div className="price">{price}<small>/month</small></div><p>{description}. Built for a busy counter, not a complicated office.</p><a href="https://wa.me/919999999999">Get started</a></div>)}</div></div></section>
    <footer className="footer"><div className="shell"><span>© 2026 ShopOS</span><span style={{ float: 'right' }}>Your shop. Your numbers. Your way.</span></div></footer>
  </main>;
}

function Feature({ icon, title, text }: { icon: React.ReactNode; title: string; text: string }) { return <article className="feature"><span>{icon}</span><h3>{title}</h3><p>{text}</p></article>; }
