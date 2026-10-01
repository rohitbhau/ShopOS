import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'ShopOS | Your shop, finally in one place',
  description: 'Offline-first billing, inventory, and customer accounts for small shops.',
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="en"><body>{children}</body></html>;
}
