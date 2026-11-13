import assert from 'node:assert/strict';
const base=process.env.RELAY_URL || 'ws://127.0.0.1:8787';
const room=`test-${crypto.randomUUID().slice(0,8)}`;
function open(path) {
 return new Promise((resolve,reject)=>{
  const ws=new WebSocket(base+path); const queue=[]; const waiters=[];
  ws.binaryType='arraybuffer';
  ws.addEventListener('message',e=>{ const value=typeof e.data==='string'?JSON.parse(e.data):e.data; if(waiters.length)waiters.shift()(value); else queue.push(value); });
  ws.next=()=>new Promise((r,j)=>{if(queue.length)return r(queue.shift());const timer=setTimeout(()=>j(Error('Message timeout')),5000);waiters.push(v=>{clearTimeout(timer);r(v)});});
  ws.addEventListener('open',()=>resolve(ws),{once:true});
  ws.addEventListener('error',()=>reject(Error('WebSocket refused')),{once:true});
 });
}
const clients=[];
const deadline=setTimeout(()=>{console.error('FAIL timeout');process.exit(1)},15000);
try {
 await assert.rejects(open(`/room/${room}`));
 const host=await open(`/room/${room}?host=1`);clients.push(host);
 assert.equal((await host.next()).id,1);
 await assert.rejects(open(`/room/${room}?host=1`));
 const guest=await open(`/room/${room}`);clients.push(guest);
 const welcome=await guest.next();assert.deepEqual(welcome.peers,[1]);
 assert.equal((await host.next()).id,welcome.id);
 const frame=new ArrayBuffer(15);const view=new DataView(frame);view.setInt32(0,1,true);view.setUint32(8,2,true);new Uint8Array(frame).set([12,34,56],12);
 guest.send(frame);
 const received=await host.next();assert.equal(new DataView(received).getInt32(0,true),welcome.id);assert.deepEqual([...new Uint8Array(received).slice(12)],[12,34,56]);
 const isolated=await open(`/room/${room}-other?host=1`);clients.push(isolated);assert.equal((await isolated.next()).id,1);
 host.send(JSON.stringify({type:'kick',id:welcome.id}));
 await new Promise(r=>guest.addEventListener('close',r,{once:true}));
 assert.equal((await host.next()).type,'left');
 const again=await open(`/room/${room}`);clients.push(again);await again.next();await host.next();
 const closed=new Promise(r=>again.addEventListener('close',r,{once:true}));host.close();await closed;
 console.log('PASS room creation, duplicate host rejection, absent room, membership, binary routing, sender identity, isolated rooms, kick, host disconnect');
} finally {clearTimeout(deadline);for(const ws of clients)ws.close();}
