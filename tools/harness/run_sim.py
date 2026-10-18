#!/usr/bin/env python3
"""Simulated Rancor fights against the real script (offline). Prints what every big-enemy slot became.

  python3 run_sim.py <script.lua> [--fights N] [--config cfg.json]
"""
import sys, os, json, argparse, collections, re
from lupa import lua54

HERE = os.path.dirname(os.path.abspath(__file__))
REGULAR = [
    ["ch261000_00", "ch231000_00", "ch231000_00", "ch231000_00"],
    ["ch254001_60", "ch226003_60", "ch231000_00", "ch231000_00"],
    ["ch227002_00", "ch261000_00"],
    ["ch226003_60", "ch227003_00"],
    ["ch257003_10"],
]
DEVOUR = [["ch261000_00", "ch254001_60", "ch226003_60"], ["ch231000_00", "ch231000_00"],
          ["ch227002_00", "ch261000_00", "ch226003_60"], ["ch226002_60", "ch226002_60"],
          ["ch254001_60", "ch227003_00", "ch261000_00"]]
DEVOUR_SATANICA = [["ch261000_00", "ch254001_60", "ch226003_60"], ["ch231000_00", "ch231000_00"],
          ["ch227002_00", "ch261000_00", "ch226003_60"], ["ch261001_00", "ch261000_00", "ch261000_00", "ch261000_00"]]


def to_lua(L, v):
    if isinstance(v, dict):
        t = L.table()
        for k, x in v.items():
            t[k] = to_lua(L, x)
        return t
    if isinstance(v, list):
        t = L.table()
        for i, x in enumerate(v, 1):
            t[i] = to_lua(L, x)
        return t
    return v


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('script')
    ap.add_argument('--fights', type=int, default=300)
    ap.add_argument('--config')
    ap.add_argument('--json')
    ap.add_argument('--slots', help='override K.SLOTS_EXPECTED: regular,virulent,devour')
    ap.add_argument('--layouts', help='realistic sampled Rancor layouts (layouts.json): per-Rancor reinforcement counts')
    a = ap.parse_args()
    L = lua54.LuaRuntime(unpack_returned_tuples=True)
    L.execute(open(os.path.join(HERE, 'mock_reframework.lua')).read())
    L.execute(open(os.path.join(HERE, 'runner.lua')).read())
    lay = json.load(open(a.layouts)) if a.layouts else None
    if lay:
        ids = sorted({e for k in lay.values() for f in k for w in f['waves'] for e in w})
        L.globals().SIM_EXTRA_IDS = to_lua(L, ids)
    L.execute(open(os.path.join(HERE, 'sim_rancor.lua')).read())
    H, M, SIM = L.globals().HARNESS, L.globals().MOCK, L.globals().SIM_
    if a.config:
        M.json_files["RancorReinforcements.json"] = to_lua(L, json.load(open(a.config)))
    H.load_script(open(a.script, encoding='utf-8').read(), os.path.basename(a.script))
    H.frames(3)
    if a.slots:
        r_, v_, d_ = [float(x) for x in a.slots.split(',')]
        L.execute(f'RR_DEV.K.SLOTS_EXPECTED = {{ regular = {r_}, virulent = {v_}, devour = {d_} }}')
    if lay:
        return layouts_report(L, H, M, SIM, lay, a)
    lua_reg, lua_dev, lua_sat = to_lua(L, REGULAR), to_lua(L, DEVOUR), to_lua(L, DEVOUR_SATANICA)
    for i in range(a.fights):
        SIM.fight(lua_reg, False)
    final_seen = collections.Counter()
    for layout, lt in (('3 large waves', lua_dev), ('2 large + Satanica', lua_sat)):
        for i in range(a.fights):
            f = SIM.fight(lt, True)
            sw = list(dict(f.swaps.items()).values()) if f.swaps else []
            final_seen[(layout, 'ch255010_00' in sw)] += 1
            if layout == '2 large + Satanica':
                SIM.advance(700)   # Satanica's 10-minute hands-off window ends
    touched = SIM.satanica_check()
    dev = None
    if L.eval('RR_DEV ~= nil'):
        dev = L.execute('''
            local r = {}
            SIM_.pos = { x = 100, y = 10, z = 100 }; SIM_.void_id = 3202; SIM_.vortex = true; SIM_.advance(70)
            r.arm_ok = RR_DEV.arm("golem")
            r.armed = SIM_.request("ch261000_00")
            SIM_.advance(20)
            RR_DEV.force_eye_final()
            r.final = SIM_.request("ch257003_10")
            r.status_wave = RR_DEV.status().wave
            SIM_.vortex = false; SIM_.advance(40)
            return r''')
        dev = dict(dev.items())

    res = collections.defaultdict(collections.Counter)
    for k, n in dict(SIM.results.items()).items():
        kind_slot, got = k.split(' -> ')
        res[kind_slot][got] += n
    out = {'fights_each': a.fights, 'slots': {}, 'unrestored': SIM.unrestored or 0, 'satanica_touched': touched,
           'max_per_fight': dict(SIM.max_per_fight.items()) if SIM.max_per_fight else {}, 'errors': []}
    print(f"Simulated {a.fights} regular + {a.fights} Devouring Rancor fights")
    for ks in sorted(res):
        tot = sum(res[ks].values())
        parts = ', '.join(f"{g} {100 * n / tot:.1f}%" for g, n in res[ks].most_common())
        out['slots'][ks] = {g: n / tot for g, n in res[ks].items()}
        print(f"  {ks} (n={tot}): {parts}")
    for layout in ('3 large waves', '2 large + Satanica'):
        yes, no = final_seen[(layout, True)], final_seen[(layout, False)]
        print(f"  Devouring ({layout}): Purgener appeared in {100 * yes / max(1, yes + no):.1f}% of fights")
        out['purgener_rate_' + layout] = yes / max(1, yes + no)
    print(f"  spawn records not restored after their wave: {out['unrestored']}")
    print(f"  Satanica wave entries changed: {touched}")
    if dev is not None:
        print(f"  RR_DEV.arm('golem') -> next big enemy became {dev['armed']}; force_eye_final -> final became {dev['final']}")
    print(f"  most of one reinforcement in a single fight: {out['max_per_fight']}")
    errs = [dict(e.items()) for e in H.errors.values()] if H.errors else []
    log = M.files["RancorReinforcements_log.txt"] or ''
    bad = [l for l in str(log).split('\n') if re.search(r'error|Error|ERROR', l)]
    out['errors'] = [e['phase'] + ': ' + e['msg'].split('\n')[0] for e in errs] + bad[:20]
    print(f"  uncaught errors: {len(errs)}; error lines in the mod's log: {len(bad)}")
    for e in out['errors'][:15]:
        print('    ' + e)
    if a.json:
        json.dump(out, open(a.json, 'w'), indent=1)


def layouts_report(L, H, M, SIM, lay, a):
    out = {'kinds': {}}
    for kind in ('regular', 'virulent', 'devour'):
        fights = lay[kind][:a.fights]
        per, what, finals, death_touched, death_check = [], collections.Counter(), collections.Counter(), 0, collections.Counter()
        slots = []
        for f in fights:
            r = SIM.fight_layout(to_lua(L, f['waves']), f['void_id'], kind == 'devour')
            if any(e.startswith('ch261001') for w in f['waves'] for e in w):
                SIM.advance(700)   # Satanica's 10-minute hands-off window ends before the next Rancor
            sw = list(dict(r.swaps.items()).values()) if r.swaps else []
            per.append(int(r.n))
            for x in sw:
                orig, got = x.split('>')
                what[got] += 1
                if orig.startswith('ch227003') and kind != 'devour':
                    death_touched += 1
            big = [e for w in f['waves'] for e in w if e.startswith(('ch261000_', 'ch254001_6', 'ch226003_6', 'ch227002_', 'ch250002_', 'ch229000_', 'ch222006_'))]
            slots.append(len(big))
            if kind == 'devour':
                fin = [e for w in f['waves'] for e in w if e.startswith(('ch258002_', 'ch227003_', 'ch261001_'))]
                fin = fin[-1] if fin else 'none'
                took = [x.split('>')[1] for x in sw if x.split('>')[0] == fin]
                finals[fin + (' -> ' + took[0] if took else ' (game)')] += 1
                if fin.startswith('ch227003'):
                    death_check[('Purgener' if took else 'Death') + ': check says ' + str(bool(r.death_after))] += 1
        n = len(per)
        hist = collections.Counter(per)
        mean = sum(per) / max(1, n)
        sd = (sum((x - mean) ** 2 for x in per) / max(1, n)) ** 0.5
        out['kinds'][kind] = {'fights': n, 'mean': mean, 'sd': sd, 'hist': dict(hist), 'what': dict(what),
                              'finals': dict(finals), 'death_touched_outside_devour': death_touched, 'death_check': dict(death_check),
                              'slots_mean': sum(slots) / max(1, n)}
        print(f"{kind}: {n} fights, big-enemy slots {sum(slots) / max(1, n):.2f}/fight; reinforcements per Rancor {mean:.2f} (sd {sd:.2f}); "
              f"histogram {dict(sorted(hist.items()))}")
        print(f"   placed: {dict(what.most_common())}")
        if finals:
            print(f"   finale: " + ', '.join(f"{k} {100 * v / n:.1f}%" for k, v in finals.most_common()))
        if death_check:
            print(f"   Death-defeated check after the fight: {dict(death_check)}")
        if death_touched:
            print(f"   !! Death replaced outside the Devouring finale {death_touched} time(s)")
    errs = [dict(e.items()) for e in H.errors.values()] if H.errors else []
    log = M.files["RancorReinforcements_log.txt"] or ''
    bad = [l for l in str(log).split('\n') if re.search(r'error|Error|ERROR', l)]
    out['unrestored'] = SIM.unrestored or 0
    out['errors'] = [e['phase'] + ': ' + e['msg'].split('\n')[0] for e in errs] + bad[:20]
    print(f"spawn records not restored: {out['unrestored']}; uncaught errors: {len(errs)}; error lines in the mod's log: {len(bad)}")
    for e in out['errors'][:15]:
        print('    ' + e)
    if a.json:
        json.dump(out, open(a.json, 'w'), indent=1)


if __name__ == '__main__':
    main()
