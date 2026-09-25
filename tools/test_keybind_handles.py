#!/usr/bin/env python3
"""Run generated bindings against real Hyprland handles, without starting a desktop.

Bubblewrap hides the host home, runtime sockets, devices and network. Config
verification initializes Hyprland's real keybind API; only timer scheduling is
replaced because verification does not run an event loop.
"""
from pathlib import Path
import os
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
JS = r'''
const fs=require('node:fs'),vm=require('node:vm');
function load(file,globals={}) {const c=vm.createContext(globals);vm.runInContext(fs.readFileSync(file,'utf8').replace(/^\.import.*\n/gm,''),c);return c;}
const keys=load('Shortcuts.js');
const families=[['ShortcutBindings.js','_windowpeek_shortcuts_v1',[]],['HoverBindings.js','_windowpeek_hover_keys_v1',[keys.hoverBindings({},false)]],['OpenShortcut.js','_windowpeek_open_v1',[]],['OutsideClicks.js','_windowpeek_outside_clicks_v1',[]],['NativeProtection.js','_windowpeek_native_focus_v2',[123,'WPTEST',10,36,500,600,true]]];
let out=`local timers={}\nfunction hl.timer(callback,options)
 local t={callback=callback};function t:set_enabled(value) end;function t:set_timeout(value) end
 table.insert(timers,t);return t
end
local function handles(s) return s.bind and {s.bind} or s.binds end
local function expire(s,partial)
 for i,b in ipairs(handles(s)) do if not partial or i==1 then if tostring(b)~='HL.Keybind(expired)' then b:remove() end;assert(tostring(b)=='HL.Keybind(expired)') end end
end
local function enabled(s,value)
 for _,b in ipairs(handles(s)) do assert(tostring(b)~='HL.Keybind(expired)');assert(b:is_enabled()==value) end
end\n`;
for (const [file,state,args] of families) {
 const api=load(file,{Keys:keys});
 out+=api.install('first:1',...args)+`\nlocal s=${state}; enabled(s,true);local live=handles(s)[2];expire(s,true)\n`;
 out+=api.renew('first:1')+api.release('first:1')+'\nfor _,t in ipairs(timers) do t.callback() end\n';
 out+=api.install('second:2',...(file==='NativeProtection.js'?args.concat(false):args))+`\nenabled(s,true);${file==='NativeProtection.js'?"assert(s.enabled==false,'initial hold must match the current view')":""};if live then assert(handles(s)[2]==live,'live handles must be reused') end;expire(s,false)\n`;
 out+=api.renew('second:2')+api.release('second:2')+'\nfor _,t in ipairs(timers) do t.callback() end\n';
 out+=api.install('third:3',...args)+api.release('third:3')+`\nenabled(s,false);print('PASS real expired handles: ${file}')\n`;
}
out+="print('WINDOWPEEK_REAL_HANDLES_PASS')\n";process.stdout.write(out);
'''

def main():
    script = subprocess.check_output(['node','-e',JS],cwd=ROOT,text=True)
    with tempfile.TemporaryDirectory(prefix='windowpeek-handles-') as directory:
        base=Path(directory)
        (base/'home').mkdir(); (base/'runtime').mkdir(mode=0o700)
        (base/'test.lua').write_text(script)
        env={'PATH':'/usr/bin','HOME':str(Path.home()),'XDG_RUNTIME_DIR':str(base/'runtime'),
             'HYPRLAND_NO_RT':'1','HYPRLAND_NO_CRASHREPORTER':'1'}
        command=['bwrap','--ro-bind','/','/','--bind',str(base/'home'),str(Path.home()),
                 '--tmpfs','/run','--tmpfs','/tmp','--bind',str(base),str(base),
                 '--dev','/dev','--proc','/proc','--unshare-all','--die-with-parent','--new-session',
                 '--chdir',str(base),'Hyprland','--verify-config','-c',str(base/'test.lua')]
        result=subprocess.run(command,env=env,text=True,capture_output=True,timeout=20)
        output=result.stdout+result.stderr
        if result.returncode or 'WINDOWPEEK_REAL_HANDLES_PASS' not in output:
            raise AssertionError(str(result.returncode)+'\n'+output)
        print('PASS real Hyprland handles: partial/full expiry, renewal, release, timer and reinstall (5 families)')

if __name__=='__main__': main()
