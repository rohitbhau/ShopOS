import Console from '../components/Console';
import { configuration } from '../src/server';

export const dynamic = 'force-dynamic';
export default function AdminPage() {
  return <Console mode={configuration().mode} />;
}
