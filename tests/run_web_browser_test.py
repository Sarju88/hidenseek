"""Run the browser fixture through two Paradev browser panes; codes stay local."""
import argparse, subprocess, json, time
parser = argparse.ArgumentParser()
parser.add_argument("--workspace", required=True)
parser.add_argument("--host-pane", required=True)
parser.add_argument("--guest-pane", required=True)
parser.add_argument("--url", default="http://localhost:8765/")
args = parser.parse_args()
W, HOST, GUEST = args.workspace, args.host_pane, args.guest_pane
def cli(*args):
 r=subprocess.run(['superset','browser',*args,'--json'],capture_output=True,text=True,timeout=25)
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
for p in [HOST,GUEST]:cli('navigate','--workspace',W,'--pane',p,'--url',args.url)
for p in [HOST,GUEST]:until(p,lambda s:not s.get('loading'),'browser load')
initial=command(HOST)
check(not initial['quit_visible'] and not initial['main_quit_visible'],'Quit absent from both web menus')
command(HOST,'host')
host=until(HOST,lambda s:bool(s.get('code')),'host invite')
check(host['code'].startswith('HNS1.'),'Host produces a complete invite')
command(GUEST,'join',host['code'])
guest=until(GUEST,lambda s:bool(s.get('code')),'guest reply')
check(guest['code'].startswith('HNS1.'),'Join produces a reply')
command(HOST,'accept',guest['code'])
for _ in range(45):
 h=command(HOST);g=command(GUEST)
 if len(h['players'])==2 and len(g['players'])==2:break
 time.sleep(.4)
else:raise RuntimeError('Peers failed to connect: '+json.dumps([{k:v for k,v in s.items() if k!='code'} for s in [h,g]]))
check(h['peer']==1 and g['peer']>1,'Actual browser-to-browser WebRTC connection')
check(not h['lobby_open'] and not g['lobby_open'],'Pairing panels close after connection')
command(GUEST,'approach')
for _ in range(30):
 h=command(HOST);g=command(GUEST)
 pos=h['positions'].get(str(g['peer']),[0,0,0])
 if abs(pos[0]+5)<.3 and abs(pos[2]-17)<.3:break
 time.sleep(.2)
else:raise RuntimeError('Remote movement not synchronized: '+json.dumps(h['positions']))
check(True,'Remote movement synchronizes before interaction')
command(GUEST,'hide')
for _ in range(25):
 h=command(HOST);g=command(GUEST)
 if g['hidden'].get(str(g['peer'])) and h['hidden'].get(str(g['peer'])):break
 time.sleep(.2)
else:raise RuntimeError('Remote hiding failed')
check(not h['bodies'][str(g['peer'])],'Host sees remote hider concealed')
command(HOST,'approach')
command(HOST,'check')
for _ in range(35):
 h=command(HOST);g=command(GUEST)
 if h['found'].get('1')==1 and not g['hidden'].get(str(g['peer'])):break
 time.sleep(.2)
else:raise RuntimeError('Remote discovery failed')
check(True,'Seeker checks and reveals remote hider')
command(HOST,'pause')
check(command(HOST)['paused'],'Pause menu opens')
command(HOST,'resume')
check(not command(HOST)['paused'],'Resume returns to the game')
command(GUEST,'menu')
check(command(GUEST)['main_menu'],'Main Menu leaves the browser session')
for _ in range(15):
 h=command(HOST)
 if len(h['players'])==1:break
 time.sleep(.3)
check(len(h['players'])==1,'Host cleans up disconnected player')
command(HOST,'quit_guard')
check(command(HOST)['main_menu'],'Web quit handler returns to menu without stopping engine')
print('ALL BROWSER MULTIPLAYER TESTS PASSED',flush=True)
