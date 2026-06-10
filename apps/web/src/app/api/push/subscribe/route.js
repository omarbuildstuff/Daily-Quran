import { createHash } from 'node:crypto';
import { getStore } from '@netlify/blobs';

const keyFor = (endpoint) => createHash('sha256').update(endpoint).digest('hex');

const openStore = () => getStore('push-subs');

export async function action({ request }) {
	if (request.method === 'POST') {
		let body;
		try {
			body = await request.json();
		} catch {
			return Response.json({ error: 'Invalid JSON body' }, { status: 400 });
		}
		const sub = body?.subscription;
		if (!sub?.endpoint) {
			return Response.json({ error: 'Missing subscription' }, { status: 400 });
		}
		try {
			const store = openStore();
			const key = keyFor(sub.endpoint);
			const existing = await store.get(key, { type: 'json' }).catch(() => null);
			await store.setJSON(key, {
				subscription: sub,
				anchor: body.anchor || 'fajr',
				offsetMin: Number.isFinite(Number(body.offsetMin)) ? Number(body.offsetMin) : 15,
				clockTime: body.clockTime || '07:00',
				lat: typeof body.lat === 'number' ? body.lat : null,
				lng: typeof body.lng === 'number' ? body.lng : null,
				tz: body.tz || 'UTC',
				lastSentDate: existing?.lastSentDate || null,
				lastListenedDate: existing?.lastListenedDate || null,
				updatedAt: Date.now(),
			});
			return Response.json({ ok: true });
		} catch (err) {
			console.error('push/subscribe error:', err);
			return Response.json(
				{ error: 'Subscription storage unavailable' },
				{ status: 503 },
			);
		}
	}

	if (request.method === 'DELETE') {
		let body;
		try {
			body = await request.json();
		} catch {
			return Response.json({ error: 'Invalid JSON body' }, { status: 400 });
		}
		if (!body?.endpoint) {
			return Response.json({ error: 'Missing endpoint' }, { status: 400 });
		}
		try {
			await openStore().delete(keyFor(body.endpoint));
			return Response.json({ ok: true });
		} catch (err) {
			console.error('push/unsubscribe error:', err);
			return Response.json(
				{ error: 'Subscription storage unavailable' },
				{ status: 503 },
			);
		}
	}

	return Response.json({ error: 'Method not allowed' }, { status: 405 });
}
