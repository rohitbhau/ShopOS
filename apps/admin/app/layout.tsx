import type { Metadata } from 'next';
import './globals.css';
import './shop.css';

export const metadata: Metadata = { title: 'ShopOS — Your everyday business', description: 'A thoughtful workspace for billing, inventory, customers, and your everyday shop.' };

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="en"><body>{children}</body></html>;
}
