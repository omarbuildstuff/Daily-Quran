import { createHash } from 'node:crypto';
import { getStore } from '@netlify/blobs';

const keyFor = (endpoint) => createHash('sha256').update(endpoint).digest('hex');

// Mark that this subscriber listened today — suppresses today's reminder.
// Body: { endpoint, localDate: 'YYYY-MM-DD' (in the user's timezone) }
export async function POST(request) {
	let body;
	try {
		body = await request.json();
	} catch {
		return Response.json({ error: 'Invalid JSON body' }, { status: 400 });
	}
	if (!body?.endpoint || !body?.localDate) {
		return Response.json({ error: 'Missing endpoint or localDate' }, { status: 400 });
	}
	try {
		const store = getStore('push-subs');
		const key = keyFor(body.endpoint);
		const record = await store.get(key, { type: 'json' }).catch(() => null);
		if (!record) return Response.json({ ok: true, unknown: true });
		record.lastListenedDate = body.localDate;
		await store.setJSON(key, record);
		return Response.json({ ok: true });
	} catch (err) {
		console.error('push/listened error:', err);
		return Response.json(
			{ error: 'Subscription storage unavailable' },
			{ status: 503 },
		);
	}
}
