/* The shop shell and hashed assets can be reopened offline. Auth/API responses
   are deliberately fetched from the network and never cached here. */
const CACHE = 'shopos-shell-v1';
self.addEventListener('install', event => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE), response = await fetch('/');
    if (!response.ok) throw new Error('Shop shell unavailable');
    const html = await response.clone().text(); await cache.put('/', response);
    const assets = Array.from(html.matchAll(/(?:src|href)=["'](\/_next\/static\/[^"']+)["']/g), match => match[1]);
    await cache.addAll(Array.from(new Set(assets))); await self.skipWaiting();
  })());
});
self.addEventListener('activate', event => {
  event.waitUntil((async () => { for (const key of await caches.keys()) if (key.startsWith('shopos-shell-') && key !== CACHE) await caches.delete(key); await self.clients.claim(); })());
});
self.addEventListener('fetch', event => {
  const url = new URL(event.request.url);
  if (event.request.method !== 'GET' || url.origin !== self.location.origin || url.pathname.startsWith('/api/')) return;
  if (event.request.mode === 'navigate' && url.pathname === '/') {
    event.respondWith((async () => {
      const cache = await caches.open(CACHE);
      try { const response = await fetch(event.request, { signal: AbortSignal.timeout(4000) }); if (response.ok) { await cache.put('/', response.clone()); return response; } throw new Error('Offline'); }
      catch { return (await cache.match('/')) || Response.error(); }
    })());
  } else if (url.pathname.startsWith('/_next/static/')) {
    event.respondWith((async () => { const cache = await caches.open(CACHE), saved = await cache.match(event.request); if (saved) return saved; const response = await fetch(event.request); if (response.ok) await cache.put(event.request, response.clone()); return response; })());
  }
});
