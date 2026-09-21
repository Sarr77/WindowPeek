const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const root = path.join(__dirname, '..');
function load(file, globals = {}) {
    const context = vm.createContext(globals);
    vm.runInContext(fs.readFileSync(path.join(root, file), 'utf8').replace(/^\.import .*\n/gm, ''), context, { filename: file });
    return context;
}
const model = load('WindowModel.js');
const commands = load('WindowCommands.js', { Model: model });
const compositor = load('Compositor.js');
const settings = load('Settings.js');
const i18n = load('I18n.js');
const appearance = load('Appearance.js');
const preview = load('WindowPreview.js');
const labels = load('Labels.js');
const placement = load('PopupPlacement.js');

test('background choices reject invalid saved values and preserve transparency endpoints', () => {
    for (const value of [undefined, null, '', '0', false, {}, NaN, Infinity]) {
        assert.equal(settings.backgroundTransparency(value, 8), 8);
        assert.equal(settings.backgroundTransparency(value, 70), 70);
        assert.equal(settings.panelStyle(value), 'solid');
    }
    assert.equal(settings.backgroundTransparency(-1, 8), 0);
    assert.equal(settings.backgroundTransparency(0, 8), 0);
    assert.equal(settings.backgroundTransparency(62.8, 8), 63);
    assert.equal(settings.backgroundTransparency(100, 8), 100);
    assert.equal(settings.backgroundTransparency(150, 8), 100);
    assert.equal(settings.panelStyle('wallpaper'), 'wallpaper');
    assert.equal(settings.panelStyle('glass'), 'glass');
    assert.equal(settings.panelStyle('unknown'), 'solid');
});

test('Wallpaper transparency and its first-use reset belong to each theme', () => {
    let prefs = {wallpaperTransparency:70,glassTransparency:8};
    assert.equal(settings.wallpaperRule(prefs,'kanagawa').initialized,false);
    prefs = {...prefs, ...settings.setWallpaperTransparency(prefs,'kanagawa',45,45)};
    prefs = {...prefs, ...settings.setWallpaperTransparency(prefs,'hackerman',70,70)};
    prefs = {...prefs, ...settings.setWallpaperTransparency(prefs,'kanagawa',82)};
    assert.equal(settings.wallpaperRule(prefs,'kanagawa').value,82);
    assert.equal(settings.wallpaperRule(prefs,'kanagawa').defaultValue,45);
    assert.equal(settings.wallpaperRule(prefs,'hackerman').value,70);
    prefs = {...prefs, ...settings.setWallpaperTransparency(prefs,'kanagawa',45)};
    assert.equal(settings.wallpaperRule(prefs,'kanagawa').value,45);
    assert.equal(settings.wallpaperRule(prefs,'new-theme').value,70);
    assert.equal(prefs.glassTransparency,8);
    assert.equal(settings.wallpaperRule(JSON.parse(JSON.stringify(prefs)),'kanagawa').defaultValue,45);
    assert.equal(settings.wallpaperRule({wallpaperTransparency:44},'legacy-theme').value,44);
    for (const theme of ['', '__proto__','constructor','../other'])
        assert.equal(JSON.stringify(settings.setWallpaperTransparency(prefs,theme,30)),'{}');
    assert.equal(settings.wallpaperRule({wallpaperThemeTransparencies:{test:{value:'0',defaultValue:20}}},'test').initialized,false);
});

test('instant previews align to either panel edge on scaled and offset monitors', () => {
    for (const scale of [1, 2]) {
        const screen = {x:1920, y:-100, width:1920, height:1080};
        const bounds = {x:screen.x + 30, y:screen.y + 40, width:420*scale};
        const width = 336*scale, height = 240*scale;
        let point = placement.beside(bounds, 30*scale, 50*scale, width, height, screen);
        assert.equal(point.x, bounds.x - screen.x + bounds.width);
        assert.equal(point.y, 40, 'first preview never rises above the panel');
        point = placement.beside(bounds, 800, 50*scale, width, height, screen);
        assert.ok(point.y >= 40 && point.y + height <= screen.height);
        bounds.x = screen.x + screen.width - bounds.width - 20;
        point = placement.beside(bounds, 30*scale, 50*scale, width, height, screen);
        assert.equal(point.x + width, bounds.x - screen.x, 'right-edge panel flips the preview to its left');
    }
});

test('hover delays preserve zero, bound durations and reject malformed preferences', () => {
    for (const value of [undefined, null, '', '0', false, {}, NaN, Infinity])
        assert.equal(settings.hoverDelay(value), 400);
    assert.equal(settings.hoverDelay(0), 0);
    assert.equal(settings.hoverDelay(-100), 0);
    assert.equal(settings.hoverDelay(320.6), 321);
    assert.equal(settings.hoverDelay(5000), 2000);
    const manifest = JSON.parse(fs.readFileSync(path.join(root, 'manifest.json')));
    assert.equal(manifest.barWidget.defaults.panelHoverDelay, 400);
    assert.equal(manifest.barWidget.defaults.previewHoverDelay, 400);
    assert.equal(manifest.barWidget.defaults.popupAnimations, true);
});

test('preview keeps every window and workspace, with the active window first', () => {
    const window = (address, workspace, active = false) => ({ address, app: 'Editor', title: 'Same title', active,
        workspace: { id: workspace, name: String(workspace) } });
    const inventory = { status: 'ready', windows: [window('0x1', 1), window('0x2', 1), window('0x3', 1),
        window('0x4', 2), window('0x5', 4), window('0x6', 4, true), window('0x7', 5)] };
    const view = model.search(inventory, '', { includeSpecial: false });
    const original = JSON.stringify(view);
    const result = preview.arrange(view);
    assert.equal(result.count, 7);
    assert.equal(result.sections.reduce((count, section) => count + section.windows.length, 0), 7);
    assert.equal(result.sections[0].windows[0].address, '0x6');
    assert.equal(result.sections.length, 4);
    assert.ok(result.sections.every(section => section.windows.length > 0));
    assert.equal(JSON.stringify(view), original, 'preview never reorders the main search list');
});

test('preview shares special filtering and distinguishes an empty desktop from missing data', () => {
    const inventory = model.normalize({ clients: [
        { address: '0x1', workspace: { id: 1, name: '1' } },
        { address: '0x2', workspace: { id: -99, name: 'special:scratchpad' } }
    ] });
    assert.equal(preview.arrange(model.search(inventory, '', { includeSpecial: false })).count, 1);
    assert.equal(preview.arrange(model.search(inventory, '', { includeSpecial: true })).count, 2);
    assert.equal(preview.arrange(model.search(model.normalize(null), '')).status, 'unavailable');
    assert.equal(preview.arrange(model.search(model.normalize({clients: []}), '')).status, 'ready');
});

test('batch replies must contain a complete, valid snapshot', () => {
    const reply = [[], [], [], {}].map(value => JSON.stringify(value, null, 2)).join('\n\n\n');
    assert.equal(model.normalize(compositor.snapshot(reply)).status, 'ready');
    for (const invalid of ['', '{}', reply.slice(0, -1), '[]\n\n\n[]', 'null\n\n\n[]\n\n\n[]\n\n\n{}'])
        assert.equal(compositor.snapshot(invalid), null);
});

test('move plans accept only an explicit current destination and safely quote workspace names', () => {
    const snapshot = { clients: [{ address: '0x1', workspace: { id: 2, name: '2' } }],
        workspaces: [{ id: -1337, name: 'Projekt "Łódź" \\ notes' }, { id: -99, name: 'special:notes' }] };
    const target = 'name:Projekt "Łódź" \\ notes';
    const plan = commands.move(snapshot, '0x1', target);
    assert.equal(plan.target, 'Projekt "Łódź" \\ notes');
    assert.ok(plan.command.includes(JSON.stringify(target)));
    assert.ok(plan.command.indexOf('group.locked') < plan.command.indexOf('group:remove'));
    assert.equal(commands.move(snapshot, '0x1;bad', target), null);
    assert.equal(commands.move(snapshot, '0x1', 'name:Absent'), null);
    assert.equal(commands.move(snapshot, '0x1', '2'), null);
    assert.equal(commands.selector({ name: 'line\nbreak' }), '');
    assert.ok(commands.destinations(snapshot, '0x1', false).every(item => !item.value.startsWith('special:')));
});

test('new durable settings win over stale inline values without dropping unrelated choices', () => {
    const saved = { _windowpeekRevision: 20, language: 'pl', hintsUsed: 80 };
    const inline = { _windowpeekRevision: 10, language: 'en', barLabel: 'name' };
    const restored = settings.restore(saved, inline, 'sarr.windowpeek');
    assert.equal(restored.language, 'pl');
    assert.equal(restored.barLabel, 'name');
    assert.equal(restored.hintsUsed, 80);
    assert.ok(settings.stamp(restored, saved)._windowpeekRevision > 20);
    assert.equal(settings.hints({}).remaining, 200);
    assert.equal(settings.hints({}).enabled, true);
    assert.equal(settings.hints({ hintsUsed: 100, hintsMode: 'auto' }).enabled, true);
    assert.equal(settings.hints({ hintsUsed: 199, hintsMode: 'auto' }).remaining, 1);
    assert.equal(settings.hints({ hintsUsed: 200, hintsMode: 'auto' }).enabled, false);
    assert.equal(settings.hints({ hintsUsed: 200, hintsMode: 'on' }).enabled, true);
});

test('scratchpad moves also work before the workspace exists, without accepting arbitrary special destinations', () => {
    const snapshot = {clients: [{address: '0x1', workspace: {id: 1, name: '1'}}], workspaces: []};
    const plan = commands.move(snapshot, '0x1', 'special:scratchpad');
    assert.equal(plan.target, 'special:scratchpad');
    assert.equal(plan.source, '1');
    assert.ok(plan.command.includes('follow = false'));
    assert.ok(plan.command.indexOf('group.locked') < plan.command.indexOf('group:remove'));
    assert.equal(commands.move(snapshot, '0x1', 'special:absent'), null);
    snapshot.workspaces.push({id: -99, name: 'special:scratchpad', monitor: 'TEST-A'});
    const choices = commands.destinations(snapshot, '0x1', true).filter(item => item.value === 'special:scratchpad');
    assert.equal(choices.length, 1);
    assert.equal(choices[0].id, -99);
    assert.equal(choices[0].monitor, 'TEST-A');
    snapshot.clients[0].workspace = snapshot.workspaces[0];
    assert.equal(commands.move(snapshot, '0x1', 'special:scratchpad'), null);
});

test('bring targets the invoking monitor’s ordinary workspace, including named destinations', () => {
    const snapshot = {
        clients: [{ address: '0x1', workspace: { id: -99, name: 'special:notes' } }],
        monitors: [
            { id: 7, name: 'TEST-A', activeWorkspace: { id: 1 }, focused: true },
            { id: 8, name: 'TEST-B', activeWorkspace: { id: -1337 }, specialWorkspace: { id: -99 } }
        ],
        workspaces: [{ id: 1, name: '1' }, { id: -1337, name: 'Studio "one"' }, { id: -99, name: 'special:notes' }]
    };
    const plan = commands.bring(snapshot, '0x1', 'TEST-B');
    assert.equal(plan.target, 'Studio "one"');
    assert.equal(plan.source, 'special:notes');
    assert.equal(plan.monitor, 8);
    assert.ok(plan.command.includes(JSON.stringify('name:Studio "one"')));
    assert.equal(commands.bring(snapshot, '0x1', 'unplugged'), null);
    assert.equal(commands.bring(snapshot, '0xff', 'TEST-B'), null);
    snapshot.monitors[1].activeWorkspace = { id: -99 };
    assert.equal(commands.bring(snapshot, '0x1', 'TEST-B'), null, 'a special workspace is never a bring destination');
    snapshot.monitors[1].activeWorkspace = { id: -1337 };
    snapshot.clients[0].workspace = snapshot.workspaces[1];
    const same = commands.bring(snapshot, '0x1', 'TEST-B');
    assert.equal(same.target, 'Studio "one"');
    assert.ok(!same.command.includes('group:remove'), 'already here only focuses; grouped tabs stay together');
});

test('all 30 catalogs cover every UI key and preserve placeholders', () => {
    assert.equal(i18n.languages.length, 30);
    const keys = Object.keys(i18n.catalogs.en).sort();
    const tokens = text => (text.match(/\{[a-zA-Z]+\}/g) || []).sort();
    for (const { code } of i18n.languages) {
        assert.deepEqual(Object.keys(i18n.catalogs[code]).sort(), keys, code);
        for (const key of keys) {
            const value = i18n.catalogs[code][key];
            assert.ok(typeof value === 'string' && value.length > 0, code + ':' + key);
            assert.deepEqual(tokens(value), tokens(i18n.catalogs.en[key]), code + ':' + key);
        }
    }
    for (const file of fs.readdirSync(root).filter(file => file.endsWith('.qml')))
        for (const match of fs.readFileSync(path.join(root, file), 'utf8').matchAll(/words\.([a-zA-Z]+)/g))
            assert.ok(keys.includes(match[1]), file + ':' + match[1]);
    assert.equal(i18n.language('auto', ['pl-PL'], 'en_US'), 'pl');
    assert.equal(i18n.language('auto', ['zh-Hant-HK'], 'en_US'), 'zh-TW');
    assert.equal(i18n.isRtl('ar'), true);
});

test('adapted Tokyo Night color does not change theme mode or saved custom colors', () => {
    assert.equal(appearance.resolve({}, 'tokyo-night', '#7AA2F7'), '#D898F5');
    assert.equal(appearance.resolve({}, 'nord', '#88C0D0'), '#88C0D0');
    assert.equal(appearance.resolve({}, '', '#82FB9C'), '#82FB9C');
    const exactTheme = appearance.setRule({}, 'tokyo-night', 'theme', 'theme', '');
    assert.equal(appearance.resolve(exactTheme, 'tokyo-night', '#7AA2F7'), '#7AA2F7');
    const custom = appearance.setRule({}, 'tokyo-night', 'theme', 'custom', '#EF98F5');
    assert.equal(appearance.resolve(custom, 'tokyo-night', '#7AA2F7'), '#EF98F5');
});

test('appearance preserves saved presets while restoring the last applied color', () => {
    const saved = appearance.setRule({}, 'tokyo-night', 'theme', 'custom', '#123456');
    let draft = appearance.setRule(saved, 'tokyo-night', 'theme', 'custom', '#FF8800');
    draft = appearance.upsertPreset(draft, '', 'Amber', '#FF8800');
    const restored = appearance.restoreColor(draft, saved, 'tokyo-night');
    assert.equal(appearance.resolve(restored, 'tokyo-night', '#FFFFFF'), '#123456');
    assert.equal(restored.colorPresets.length, 1);
    assert.equal(appearance.normalize({ uiScale: 7 }).uiScale, 2);
});

test('custom labels stay literal, validate variables and fall back to the current language', () => {
    const settings = {labelStyle:'custom', customLabels:{barText:'Okna {count} · {monitor}',
        move:'  <b>Wybierz</b>\nteraz  ', scratchpad:'', ignored:'discard'}};
    const cleaned = labels.normalize(settings);
    assert.equal(cleaned.customLabels.move, '<b>Wybierz</b> teraz');
    assert.equal(cleaned.customLabels.ignored, undefined);
    assert.equal(labels.normalize({customLabels:{move:42}}).customLabels.move, undefined);
    assert.equal(labels.normalize({customLabels:{move:'x'.repeat(200)}}).customLabels.move.length, labels.maximumLength);
    const en = i18n.words('en'), pl = i18n.words('pl');
    assert.equal(labels.apply(en, settings).move, '<b>Wybierz</b> teraz');
    assert.equal(labels.apply(pl, settings).move, '<b>Wybierz</b> teraz');
    assert.equal(labels.apply(en, settings).hiddenWorkspace, 'Hidden');
    assert.equal(labels.apply(pl, settings).hiddenWorkspace, 'Ukryty');
    assert.equal(labels.apply(en, {labelStyle:'default', customLabels:settings.customLabels}).move, en.move);
    const text = labels.templates(en, settings, 'full', false).barText;
    assert.equal(labels.render(text, {count:6, monitor:'{count}'}), 'Okna 6 · {count}', 'substitution is not recursive');
    assert.equal(labels.valid(settings), true);
    const invalid = {labelStyle:'custom', customLabels:{barText:'{cout}'}};
    assert.equal(labels.valid(invalid), false);
    assert.equal(labels.templates(en, invalid, 'full', false).barText, 'WindowPeek · {count}');
    assert.equal(labels.valid({labelStyle:'custom', customLabels:{move:'Move {count}'}}), false);
    assert.equal(labels.templates(en, {}, 'compact', false).barText, '▣ {count}');
    assert.equal(labels.templates(en, {}, 'full', true).barText, 'WindowPeek\n{count}');
    for (const {code} of i18n.languages) {
        const words = i18n.words(code), defaults = labels.defaults(words, 'full', false);
        for (const field of labels.fields) {
            assert.ok(defaults[field.key], code + ':' + field.key);
            assert.equal(labels.invalidVariables(field.key, defaults[field.key]).length, 0, code + ':' + field.key);
        }
    }
});


test('surface settings retain independent theme scopes and sanitize malformed values', () => {
    let prefs = appearance.setSurfaceRule({}, 'windows', 'tokyo-night', 'theme', {color:'#246',brightness:12,opacity:42.2});
    prefs = appearance.setSurfaceRule(prefs, 'panel', 'nord', 'all', {color:'#000',brightness:-20,opacity:null});
    assert.equal(appearance.surfaceRuleFor(prefs,'windows','tokyo-night').color, '#224466');
    assert.equal(appearance.surfaceRuleFor(prefs,'windows','nord').color, '');
    assert.equal(appearance.surfaceRuleFor(prefs,'windows','tokyo-night').opacity, 42);
    assert.equal(appearance.surfaceRuleFor(prefs,'panel','tokyo-night').brightness, -20);
    assert.equal(appearance.surfaceRule({color:'bad color', brightness:Infinity, opacity:'55'}).opacity, null);
    assert.equal(appearance.surfaceRule({brightness:300,opacity:-9}).brightness, 100);
    assert.equal(appearance.brighten('#224466',-100), '#000000');
    assert.equal(appearance.brighten('#224466',100), '#FFFFFF');
    assert.equal(appearance.surfaceColor(prefs,'windows','nord','#ABCDEF'), '#ABCDEF');
    assert.equal(Object.hasOwn(appearance.normalize({surfaceColors:{bad:{},panel:{themes:{constructor:{color:'#fff'}}}}}).surfaceColors.panel.themes,'constructor'), false);
});

test('complete color presets round trip, preserve legacy presets and reset only the selected scope', () => {
    let prefs = appearance.setRule({},'nord','theme','custom','#123456');
    prefs = appearance.setSurfaceRule(prefs,'windows','nord','theme',{color:'#345678',brightness:9,opacity:30});
    prefs = appearance.setSurfaceRule(prefs,'wallpaper','nord','theme',{brightness:15});
    const style = appearance.captureStyle(prefs,'nord');
    prefs = appearance.upsertPreset(prefs,'','Full style','#123456',style);
    prefs = appearance.upsertPreset(prefs,'','Legacy','#ABCDEF');
    prefs = appearance.normalize(JSON.parse(JSON.stringify(prefs)));
    assert.equal(prefs.colorPresets[1].style, undefined);
    prefs = appearance.applyStyle(prefs,'tokyo-night','theme',prefs.colorPresets[0].style);
    assert.equal(appearance.surfaceRuleFor(prefs,'windows','tokyo-night').opacity, 30);
    assert.equal(appearance.surfaceRuleFor(prefs,'wallpaper','tokyo-night').brightness, 15);
    prefs = appearance.applyStyle(prefs,'tokyo-night','theme',{});
    assert.equal(appearance.surfaceRuleFor(prefs,'windows','tokyo-night').color, '');
    assert.equal(appearance.surfaceRuleFor(prefs,'windows','nord').color, '#345678');
    assert.equal(appearance.resolve(prefs,'nord','#fff'), '#123456');
    assert.equal(prefs.colorPresets.length, 2);
    prefs = appearance.applyStyle(prefs,'nord','all',style);
    assert.equal(appearance.surfaceRuleFor(prefs,'windows','another').opacity, 30);
    assert.equal(appearance.resolve(prefs,'another','#fff'), '#123456');
});

test('displayed runtime version matches the manifest', () => {
    const manifest = JSON.parse(fs.readFileSync(path.join(root,'manifest.json'),'utf8'));
    assert.ok(fs.readFileSync(path.join(root,'Runtime.qml'),'utf8').includes('readonly property string version: "' + manifest.version + '"'));
});


test('preview dimensions follow portrait, landscape and changing source sizes within monitor bounds', () => {
    const geometry = load('PreviewGeometry.js');
    for (const [w,h] of [[320,640],[1920,1080],[100,2000],[2000,100]]) {
        const fitted = geometry.fit(w,h,290,300,164,true);
        assert.ok(fitted.width <= 290 && fitted.height <= 300);
        assert.ok(Math.abs(fitted.width/fitted.height - w/h) < .0001);
    }
    assert.equal(geometry.fit(320,640,290,300,164,true).height, 300);
    assert.equal(geometry.fit(320,640,290,300,164,false).height, 164);
    assert.equal(geometry.fit(0,0,290,300,164,true).width, 290);
    assert.equal(geometry.fit(Infinity,20,290,100,164,true).height, 100);
});
