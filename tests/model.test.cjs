const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const model = vm.createContext({});
const filename = path.join(__dirname, '../WindowModel.js');
vm.runInContext(fs.readFileSync(filename, 'utf8'), model, { filename });
const plain = value => JSON.parse(JSON.stringify(value));
const normalize = snapshot => plain(model.normalize(snapshot));
const search = (inventory, query = '', options) => plain(model.search(inventory, query, options));
const addresses = view => view.sections.flatMap(section => section.windows.map(window => window.address));

const client = (address, extra = {}) => ({
    address, class: 'Editor', title: 'Example project', mapped: true,
    workspace: { id: 2, name: '2' }, grouped: [], ...extra
});
const snapshot = (clients, extra = {}) => ({
    clients,
    workspaces: [{ id: 2, name: '2', monitorID: 7, monitor: 'TEST-A' }],
    monitors: [{ id: 7, name: 'TEST-A' }],
    activeAddress: '',
    ...extra
});

test('unavailable data, an empty desktop and no search matches remain distinguishable', () => {
    for (const input of [undefined, null, {}, { clients: null }, { clients: {} }]) {
        assert.deepEqual(normalize(input), { status: 'unavailable', windows: [] });
        assert.deepEqual(search(normalize(input)), { status: 'unavailable', sections: [] });
    }
    const empty = normalize(snapshot([]));
    assert.deepEqual(empty, { status: 'ready', windows: [] });
    assert.deepEqual(search(empty), { status: 'ready', sections: [] });
    const inventory = normalize(snapshot([client('0x1')]));
    assert.deepEqual(search(inventory, 'absent'), { status: 'ready', sections: [] });
    assert.equal(inventory.windows.length, 1);
});

test('equal titles are separate windows; duplicate addresses keep the first mapped record', () => {
    const inventory = normalize(snapshot([
        client('0xA', { mapped: false }), client('0x000A'),
        client('0xb'), client('0Xa', { title: 'Duplicate record' })
    ], { activeAddress: '0X000A' }));
    assert.deepEqual(inventory.windows.map(window => window.address), ['0xa', '0xb']);
    assert.deepEqual(inventory.windows.map(window => window.title), ['Example project', 'Example project']);
    assert.deepEqual(inventory.windows.map(window => window.active), [true, false]);
});

test('invalid addresses and unmapped clients cannot become search results', () => {
    const invalid = [
        '', 'abc', '0x0', '0X0000', '0x1; command', '0x123456789abcdef01',
        '0x1\n', '0x1\r', '0x1\u2028', '0x1\u2029', 12, null
    ];
    const inventory = normalize(snapshot([
        null, {}, ...invalid.map(value => client(value)),
        client('0x1', { mapped: false }), client('0x2')
    ]));
    assert.deepEqual(addresses(search(inventory)), ['0x2']);
});

test('hidden group tabs remain searchable as individual windows', () => {
    const group = ['0x3', '0x1', '0x2'];
    const inventory = normalize(snapshot([
        client('0x1', { grouped: group }),
        client('0x2', { grouped: ['0X02', '0x3', '0x1'], hidden: true, title: 'Hidden notes' }),
        client('0x3', { grouped: group, hidden: true })
    ], { activeAddress: '0x1' }));
    assert.equal(inventory.windows.length, 3);
    assert.ok(inventory.windows.every(window => window.group.join(',') === '0x1,0x2,0x3'));
    const view = search(inventory, 'hidden notes');
    assert.deepEqual(addresses(view), ['0x2']);
    assert.equal(view.sections[0].windows[0].hidden, true);
    assert.equal(view.sections[0].windows[0].active, false);
});

test('group membership ignores invalid and repeated pointers without inventing clients', () => {
    const inventory = normalize(snapshot([
        client('0x1', { grouped: ['0x1', '0X01', null, 'bad', '0x0', '0x9'] }),
        client('0x2', { grouped: ['0x1', '0x9'] }),
        client('0x3', { grouped: ['0x3', '0X03'] })
    ]));
    assert.deepEqual(inventory.windows.map(window => window.group), [['0x1', '0x9'], [], []]);
    assert.deepEqual(addresses(search(inventory)), ['0x1', '0x2', '0x3']);
});

test('search matches literal fragments of the app or title, ignoring case and outer whitespace', () => {
    const inventory = normalize(snapshot([
        client('0x1', { class: 'ExampleBrowser', title: 'Release notes' }),
        client('0x2', { title: 'Release .* checklist' }),
        client('0x3', { class: '', initialClass: 'Terminal', title: '' })
    ]));
    assert.deepEqual(addresses(search(inventory, ' BROWSER ')), ['0x1']);
    assert.deepEqual(addresses(search(inventory, 'RELEASE')), ['0x1', '0x2']);
    assert.deepEqual(addresses(search(inventory, '.*')), ['0x2']);
    assert.deepEqual(addresses(search(inventory, 'term')), ['0x3']);
    assert.deepEqual(addresses(search(inventory, 'browser release')), []);
    assert.deepEqual(addresses(search(inventory, '  ')), ['0x1', '0x2', '0x3']);
});

test('Unicode search handles canonical equivalents without removing accents', () => {
    const title = 'Zażółć — Cafe\u0301 — 東京';
    const inventory = normalize(snapshot([client('0x1', { title })]));
    for (const query of ['ZAŻÓŁĆ', 'CAFÉ', 'cafe\u0301', '東京'])
        assert.deepEqual(addresses(search(inventory, query)), ['0x1']);
    assert.deepEqual(addresses(search(inventory, 'cafe')), []);
    assert.equal(inventory.windows[0].title, title);
});

test('display strings remain literal and malformed fields do not become object strings', () => {
    const title = '<b>Notes</b> $(example) "quoted"\nsecond line';
    const inventory = normalize(snapshot([
        client('0x1', { title }),
        client('0x2', { title: {}, class: null, initialClass: 'Fallback' })
    ]));
    assert.equal(inventory.windows[0].title, title);
    assert.equal(inventory.windows[1].title, '');
    assert.equal(inventory.windows[1].app, 'Fallback');
});

test('sections order numbered, named, special and unknown workspaces', () => {
    const inventory = normalize(snapshot([
        client('0x1', { workspace: { id: 10, name: '10' } }),
        client('0x2', { workspace: { id: -1337, name: 'Projekt Łódź' } }),
        client('0x3', { workspace: { id: -99, name: 'special:scratchpad' } }),
        client('0x4', { workspace: null }), client('0x5'),
        client('0x6', { workspace: { id: -1338, name: 'Badania' } })
    ]));
    const sections = search(inventory).sections;
    assert.deepEqual(sections.map(section => section.key),
        ['id:2', 'id:10', 'id:-1338', 'id:-1337', 'id:-99', 'unknown']);
    assert.equal(sections[3].workspace.name, 'Projekt Łódź');
    assert.equal(sections[4].workspace.special, true);
    assert.equal(sections[5].workspace, null);
});

test('special-workspace filtering leaves the source inventory intact', () => {
    const inventory = normalize(snapshot([
        client('0x1'),
        client('0x2', { workspace: { id: -99, name: 'special:scratchpad' } }),
        client('0x3', { workspace: { id: -98, name: 'special:notes' } })
    ]));
    assert.deepEqual(addresses(search(inventory, '', { includeSpecial: false })), ['0x1']);
    assert.equal(inventory.windows.length, 3);
    assert.deepEqual(addresses(search(inventory)).sort(), ['0x1', '0x2', '0x3']);
});

test('workspace identity survives a rename and does not depend on its label', () => {
    const inventory = normalize(snapshot([
        client('0x1', { workspace: { id: 2, name: 'Old label' } }),
        client('0x2', { workspace: { id: 3, name: 'Shared label' } })
    ], { workspaces: [{ id: 2, name: 'Shared label' }] }));
    const sections = search(inventory).sections;
    assert.deepEqual(sections.map(section => section.key), ['id:2', 'id:3']);
    assert.deepEqual(sections.map(section => section.workspace.name), ['Shared label', 'Shared label']);
});

test('partial workspace records preserve names and can resolve metadata by name', () => {
    const inventory = normalize(snapshot([
        client('0x1', { workspace: { name: '2' } }),
        client('0x2', { workspace: { name: 'Projekt 東京' } }),
        client('0x3', { workspace: {} })
    ]));
    const sections = search(inventory).sections;
    assert.deepEqual(sections.map(section => section.key), ['id:2', 'name:Projekt 東京', 'unknown']);
    assert.deepEqual(sections[0].workspace.monitor, { id: 7, name: 'TEST-A' });
    assert.equal(sections[1].workspace.monitor, null);
});

test('monitor assignment comes from workspace metadata, not a stale client monitor', () => {
    const inventory = normalize(snapshot([client('0x1', { monitor: 99 })]));
    assert.deepEqual(inventory.windows[0].workspace.monitor, { id: 7, name: 'TEST-A' });
    const moved = normalize(snapshot([client('0x1', { monitor: 7 })], {
        workspaces: [{ id: 2, name: '2', monitor: 'TEST-B' }],
        monitors: [{ id: 8, name: 'TEST-B' }]
    }));
    assert.deepEqual(moved.windows[0].workspace.monitor, { id: 8, name: 'TEST-B' });
});

test('missing, disabled or conflicting monitor metadata leaves placement unknown', () => {
    for (const extra of [
        { monitors: null }, { monitors: [] }, { workspaces: null },
        { monitors: [{ id: 7, name: 'TEST-A', disabled: true }] },
        { monitors: [{ id: 7, name: 'TEST-B' }] },
        { monitors: [{ id: 8, name: 'TEST-A' }] }
    ]) {
        const inventory = normalize(snapshot([client('0x1')], extra));
        assert.equal(inventory.status, 'ready');
        assert.equal(inventory.windows.length, 1);
        assert.equal(inventory.windows[0].workspace.monitor, null);
    }
});

test('title, focus and source order changes do not reorder rows or change their identity', () => {
    const clients = [client('0x20000000000001'), client('0x2'), client('0x20000000000000')];
    const before = normalize(snapshot(clients, { activeAddress: '0x2' }));
    const after = normalize(snapshot(clients.slice().reverse().map((window, i) => ({
        ...window, title: 'Changed ' + i, class: 'Renamed ' + i
    })), { activeAddress: '0x20000000000001' }));
    const expected = ['0x2', '0x20000000000000', '0x20000000000001'];
    assert.deepEqual(addresses(search(before)), expected);
    assert.deepEqual(addresses(search(after)), expected);
    assert.equal(after.windows.find(window => window.active).address, '0x20000000000001');
});

test('normalization and search do not mutate their inputs or keep state between calls', () => {
    function freeze(value) {
        if (value && typeof value === 'object') {
            Object.values(value).forEach(freeze);
            Object.freeze(value);
        }
        return value;
    }
    const input = freeze(snapshot([
        client('0x2', { grouped: ['0x2', '0x1'] }),
        client('0x1', { grouped: ['0x2', '0x1'] })
    ]));
    const original = JSON.stringify(input);
    const inventory = freeze(normalize(input));
    const view = search(inventory);
    assert.deepEqual(addresses(view), ['0x1', '0x2']);
    assert.equal(JSON.stringify(input), original);
    normalize(snapshot([client('0x3')]));
    assert.deepEqual(normalize(input), inventory);
    assert.deepEqual(search(inventory), view);
});

const preview = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../WindowPreview.js'), 'utf8'), preview);
test('session ordering survives focus changes without dropping or mutating windows', () => {
    const initial = search(normalize(snapshot([
        client('0x1', { workspace: { id: 1, name: '1' } }),
        client('0x2'), client('0x3')
    ], { activeAddress: '0x3' })));
    const before = JSON.stringify(initial);
    assert.deepEqual(addresses(plain(preview.arrange(initial, '0x3'))), ['0x3', '0x2', '0x1']);
    assert.equal(JSON.stringify(initial), before);
    const changed = structuredClone(initial);
    for (const section of changed.sections) for (const window of section.windows)
        window.active = window.address === '0x1';
    assert.deepEqual(addresses(plain(preview.arrange(changed, '0x3'))), ['0x3', '0x2', '0x1']);
    assert.deepEqual(addresses(plain(preview.arrange(changed))), ['0x1', '0x2', '0x3']);
    assert.deepEqual(addresses(plain(preview.arrange(changed, ''))), ['0x1', '0x2', '0x3']);
    changed.sections[1].windows = changed.sections[1].windows.filter(w => w.address !== '0x3');
    assert.deepEqual(addresses(plain(preview.arrange(changed, '0x3'))), ['0x1', '0x2']);
});
