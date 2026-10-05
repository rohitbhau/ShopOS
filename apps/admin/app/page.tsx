import ShopWorkspace from '../components/shop/ShopWorkspace';
import { configuration } from '../src/server';

export const dynamic = 'force-dynamic';
export default function AdminPage() {
  return <ShopWorkspace mode={configuration().mode} />;
}
