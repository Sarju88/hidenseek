import { DurableObject } from 'cloudflare:workers';

// One isolated room per URL. Godot's host (peer 1) owns gameplay authority.
export class GameRoom extends DurableObject {
  async fetch(request) {
    const url = new URL(request.url);
    const hosting = url.searchParams.get('host') === '1';
    const sockets = this.ctx.getWebSockets().filter(s => !s.deserializeAttachment().closed);
    const host = sockets.find(s => s.deserializeAttachment().id === 1);
    if (hosting && sockets.length) return new Response('Room already exists. Join instead.', {status:409});
    if (!hosting && !host) return new Response('Room not found. Ask a player to Host first.', {status:404});
    if (sockets.length >= 10) return new Response('Room is full.', {status:403});
    if (host?.deserializeAttachment().refuse) return new Response('Room is not accepting players.', {status:403});
    let id = 1;
    if (!hosting) {
      do { id = 2 + (crypto.getRandomValues(new Uint32Array(1))[0] % 2147483645); }
      while (sockets.some(s => s.deserializeAttachment().id === id));
    }
    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);
    server.serializeAttachment({id, closed:false});
    this.ctx.acceptWebSocket(server);
    server.send(JSON.stringify({type:'welcome', id, peers:sockets.map(s => s.deserializeAttachment().id)}));
    for (const socket of sockets) this.send(socket, JSON.stringify({type:'joined', id}));
    return new Response(null, {status:101, webSocket:client});
  }
  send(socket, message) {
    try { socket.send(message); } catch { this.remove(socket); }
  }
  webSocketMessage(socket, message) {
    const state = socket.deserializeAttachment();
    if (state.closed) return;
    // Bound traffic per connection; attachment survives hibernation.
    const second = Math.floor(Date.now()/1000);
    if (state.second !== second) { state.second=second; state.count=0; state.bytes=0; }
    state.count++; state.bytes += typeof message === 'string' ? message.length : message.byteLength;
    socket.serializeAttachment(state);
    if (state.count > 600 || state.bytes > 2*1024*1024) { socket.close(1008,'Traffic limit'); this.remove(socket); return; }
    if (typeof message === 'string') {
      let control;
      try { control=JSON.parse(message); } catch { socket.close(1008,'Invalid control'); this.remove(socket); return; }
      if (state.id !== 1) return;
      if (control.type === 'refuse') { state.refuse=!!control.value; socket.serializeAttachment(state); }
      if (control.type === 'kick' && control.id !== 1) {
        const target=this.ctx.getWebSockets().find(s=>s.deserializeAttachment().id===control.id);
        if(target) { target.close(1008,'Disconnected by host'); this.remove(target); }
      }
      return;
    }
    if (message.byteLength < 12 || message.byteLength > 65536) { socket.close(1009,'Invalid packet size'); this.remove(socket); return; }
    const header = new DataView(message);
    const target = header.getInt32(0,true);
    if (header.getUint32(8,true)>2 || header.getUint32(4,true)>255) { socket.close(1008,'Invalid packet header'); this.remove(socket); return; }
    // Never trust a sender ID supplied by the client.
    header.setInt32(0,state.id,true);
    for(const other of this.ctx.getWebSockets()) {
      const info=other.deserializeAttachment();
      if(info.closed || info.id===state.id) continue;
      if(target===0 || target===info.id || (target<0 && info.id!==-target)) this.send(other,message);
    }
  }
  remove(socket) {
    const info=socket.deserializeAttachment();
    if(!info || info.closed) return;
    info.closed=true; socket.serializeAttachment(info);
    for(const other of this.ctx.getWebSockets()) {
      if(other===socket || other.deserializeAttachment().closed) continue;
      if(info.id===1) {
        const state=other.deserializeAttachment(); state.closed=true; other.serializeAttachment(state);
        other.close(1001,'Host left the room');
      } else this.send(other,JSON.stringify({type:'left',id:info.id}));
    }
  }
  webSocketClose(socket, code) { socket.close(code === 1005 ? 1000 : code); this.remove(socket); }
  webSocketError(socket) { this.remove(socket); }
}
export default {
  async fetch(request, env) {
    const url=new URL(request.url);
    if(url.pathname==='/health') return Response.json({ok:true,protocol:'hidenseek-relay-v1'});
    const match=url.pathname.match(/^\/room\/([A-Za-z0-9_-]{1,32})$/);
    if(!match) return new Response('Hide & Seek relay. Connect from the game.',{status:404});
    if(request.headers.get('Upgrade')?.toLowerCase()!=='websocket') return new Response('WebSocket required',{status:426});
    const origin=request.headers.get('Origin');
    if(origin && !['https://hidenseek.arjunrao.dev','https://sarju88.github.io'].includes(origin) && !/^http:\/\/(localhost|127\.0\.0\.1):\d+$/.test(origin)) return new Response('Origin not allowed',{status:403});
    return env.ROOMS.getByName(match[1].toLowerCase()).fetch(request);
  }
};
