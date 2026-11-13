"""Run the browser fixture through two Paradev browser panes; server address networking."""
import argparse, subprocess, json, time
parser = argparse.ArgumentParser()
parser.add_argument("--workspace", required=True)
parser.add_argument("--host-pane", required=True)
parser.add_argument("--guest-pane", required=True)
parser.add_argument("--url", default="http://localhost:8765/")
parser.add_argument("--server", default="127.0.0.1:18580")
parser.add_argument("--reuse", action="store_true", help="Use already-loaded fixture panes")
args = parser.parse_args()
W, HOST, GUEST = args.workspace, args.host_pane, args.guest_pane
def cli(*args):
 r=subprocess.run(['superset','browser',*args,'--json'],capture_output=True,text=True,timeout=45)
 if r.returncode:raise RuntimeError(r.stderr[:500])
 return json.loads(r.stdout)
def command(pane,cmd='state',value=''):
 expr='(()=>{if(typeof window.hnsCommand!=="function")return {loading:true};engine.rtenv.resumeMainLoop();window.hnsCommand('+json.dumps(cmd)+','+json.dumps(value)+');return JSON.parse(window.hnsState)})()'
 return cli('eval','--workspace',W,'--pane',pane,'--code',expr).get('result')
def until(pane,predicate,label,timeout=30):
 end=time.monotonic()+timeout
 state={}
 while time.monotonic()<end:
  state=command(pane)
  if predicate(state):return state
  time.sleep(.5)
 raise RuntimeError(label+' timed out: '+json.dumps({k:v for k,v in state.items() if k!='code'}))
def check(ok,msg):
 if not ok:raise RuntimeError(msg)
 print('PASS',msg,flush=True)
if not args.reuse:
 for p in [HOST,GUEST]:cli('navigate','--workspace',W,'--pane',p,'--url',args.url)
for p in [HOST,GUEST]:until(p,lambda s:not s.get('loading'),'browser load',timeout=90)
initial=command(HOST)
check(not initial['quit_visible'] and not initial['main_quit_visible'],'Quit absent from both web menus')
command(HOST,'host',args.server)
until(HOST,lambda s:len(s.get('players',[]))==1 and not s.get('connecting'),'browser Host connects to server')
command(GUEST,'join',args.server)
for _ in range(45):
 h=command(HOST);g=command(GUEST)
 if len(h['players'])==2 and len(g['players'])==2:break
 time.sleep(.4)
else:raise RuntimeError('Peers failed to connect: '+json.dumps([{k:v for k,v in s.items() if k!='code'} for s in [h,g]]))
check(h['peer']>=1 and g['peer']>1 and h['peer']!=g['peer'],'Two browser players connect with distinct peer IDs')
check(h['session_host']==h['peer'],'Browser Host creates the server session')
check(not h['main_menu'] and not g['main_menu'],'Joining enters the game without code panels')
check(h['phase']=='lobby' and h['locked'] and g['locked'], 'All players frozen in lobby')
command(GUEST,'start')
time.sleep(.4)
check(command(GUEST)['phase']=='lobby','Guest cannot start round')
command(HOST,'start')
for _ in range(30):
 h=command(HOST);g=command(GUEST)
 if h['phase']=='hiding' and g['phase']=='hiding':break
 time.sleep(.2)
check(h['phase']=='hiding' and g['phase']=='hiding','Host starts hiding countdown')
check(55 <= h['remaining'] <= 60,'60-second hiding countdown')
seeker,hider=(HOST,GUEST) if h['blind'] else (GUEST,HOST)
s=command(seeker);r=command(hider)
check(s['locked'] and s['blind'] and not r['locked'],'Random seeker blind and frozen; hider released')
command(hider,'approach')
for _ in range(20):
 command(seeker);command(hider);time.sleep(.2)
command(hider,'hide')
for _ in range(30):
 s=command(seeker);r=command(hider)
 if r['hidden'].get(str(r['peer'])):break
 time.sleep(.2)
check(bool(r['hidden'].get(str(r['peer']))),'Hider hides during countdown')
check(not s['bodies'][str(r['peer'])],'Seeker sees concealed hider state')
end=time.monotonic()+65
while time.monotonic()<end:
 s=command(seeker);r=command(hider)
 if s['phase']=='seeking' and r['phase']=='seeking':break
 time.sleep(1)
check(s['phase']=='seeking' and not s['blind'] and not s['locked'],'Seeker released after full countdown')
command(seeker,'approach')
for _ in range(20):
 command(seeker);command(hider);time.sleep(.2)
command(seeker,'check')
for _ in range(35):
 s=command(seeker);r=command(hider)
 if s['phase']=='lobby' and r['phase']=='lobby':break
 time.sleep(.2)
check(s['found'].get(str(s['peer']))==1 and not r['hidden'].get(str(r['peer'])),'Seeker finds hider; round returns to lobby')
check(s['locked'] and r['locked'],'All players frozen between rounds')
command(HOST,'pause')
check(command(HOST)['paused'],'Pause menu opens')
command(HOST,'resume')
check(not command(HOST)['paused'],'Resume returns to game')
command(GUEST,'menu')
check(command(GUEST)['main_menu'],'Main Menu leaves browser session')
command(HOST,'quit_guard')
check(command(HOST)['main_menu'],'Web quit handler returns to menu')
print('ALL BROWSER ROUND TESTS PASSED',flush=True)
