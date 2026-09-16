#!/usr/bin/env node
// Local presenter-sync relay for an html-deck deck.
//
//   node sync-relay.mjs my-deck.html [--port 8080]
//
// Then open, in whichever two browsers you like:
//   stage  (projector, fullscreen)  http://localhost:8080/?sync=http://localhost:8080
//   notes  (laptop)                 http://localhost:8080/?sync=http://localhost:8080&role=notes
//
// It serves the deck AND relays state, so both windows are same-origin: no
// CORS, and no mixed-content problem (a deck loaded over https cannot open a
// ws:// or http:// localhost connection, which is what rules out running the
// relay against the published cf-now URL — see SKILL.md).
//
// Zero dependencies, and no network beyond the loopback interface: the deck
// already carries a recorded terminal demo so a dead venue wifi cannot break
// it, and slide navigation should not be the thing that reintroduces that
// dependency.
//
// Transport is SSE down / POST up rather than WebSocket. It needs no framing
// (so: no dependency), and EventSource reconnects on its own, so a laptop that
// sleeps mid-talk recovers with no reconnect logic on either end.

import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { basename, resolve } from 'node:path';

const argv = process.argv.slice(2);
const portFlag = argv.indexOf('--port');
const port = portFlag === -1 ? 8080 : Number(argv[portFlag + 1]);
const deckArg = argv.find((a, i) => !a.startsWith('--') && i !== portFlag + 1);

if (!deckArg) {
  console.error('usage: node sync-relay.mjs <deck.html> [--port 8080]');
  process.exit(1);
}
const deckPath = resolve(deckArg);

// room -> { clients: Set<ServerResponse>, last: state|null }
const rooms = new Map();
const roomFor = name => {
  if (!rooms.has(name)) rooms.set(name, { clients: new Set(), last: null });
  return rooms.get(name);
};

const send = (res, data) => res.write(`data: ${JSON.stringify(data)}\n\n`);

const server = createServer(async (req, res) => {
  const url = new URL(req.url, `http://localhost:${port}`);
  const room = roomFor(url.searchParams.get('room') || 'deck');

  // ── SSE stream ──
  if (url.pathname === '/events') {
    res.writeHead(200, {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache, no-transform',
      Connection: 'keep-alive',
    });
    res.write('retry: 1000\n\n');
    room.clients.add(res);
    // A window that joins late is brought straight to where the talk is,
    // rather than waiting for the next keypress to find out.
    if (room.last) send(res, room.last);
    const beat = setInterval(() => res.write(': ping\n\n'), 15000);
    req.on('close', () => { clearInterval(beat); room.clients.delete(res); });
    return;
  }

  // ── State publish, fanned out to everyone (the sender filters its own echo) ──
  if (url.pathname === '/state' && req.method === 'POST') {
    let body = '';
    req.on('data', c => {
      body += c;
      if (body.length > 4096) req.destroy();   // this payload is ~80 bytes
    });
    req.on('end', () => {
      try {
        const state = JSON.parse(body);
        room.last = state;
        for (const c of room.clients) send(c, state);
        res.writeHead(204).end();
      } catch {
        res.writeHead(400).end('bad json');
      }
    });
    return;
  }

  // ── The deck itself ──
  if (url.pathname === '/' || url.pathname === '/' + basename(deckPath)) {
    try {
      res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store' });
      res.end(await readFile(deckPath));
    } catch (e) {
      res.writeHead(500).end(String(e.message));
    }
    return;
  }

  // ── Anything else the deck references, relative to it (images, fonts) ──
  try {
    const asset = resolve(deckPath, '..', '.' + url.pathname);
    // Do not serve outside the deck's own directory.
    if (!asset.startsWith(resolve(deckPath, '..'))) { res.writeHead(403).end(); return; }
    res.writeHead(200).end(await readFile(asset));
  } catch {
    res.writeHead(404).end('not found');
  }
});

server.listen(port, '127.0.0.1', () => {
  const base = `http://localhost:${port}`;
  console.log(`html-deck sync relay — ${basename(deckPath)}\n`);
  console.log(`  stage  ${base}/?sync=${base}`);
  console.log(`  notes  ${base}/?sync=${base}&role=notes\n`);
  console.log('ctrl-c to stop');
});
