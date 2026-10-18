#!/usr/bin/env python3
"""Offline test harness for Rancor Reinforcements (and other REFramework scripts).

  python3 run_harness.py <script.lua> [--release] [--configs DIR] [--no-static] [--json out.json]

Runs, per config scenario, in a fresh mock REFramework:
  load script -> 5 frames -> draw UI -> call every hook with empty args -> 2 frames -> UI with every button pressed
and reports every uncaught Lua error with its traceback. Also runs the static global-name check and, for a
release build, checks that no log/research files are written and no dev tools are drawn.
"""
import sys, os, json, glob, argparse, hashlib, pickle
from lupa import lua54

HERE = os.path.dirname(os.path.abspath(__file__))
CONFIG_NAME = "RancorReinforcements.json"
DEV_ONLY_LABELS = ("Item giver", "Test spawn", "Gimmick finder", "Research", "research")


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


def from_lua(v):
    if hasattr(v, 'items') and not isinstance(v, (str, bytes)):
        d = dict(v.items())
        if d and all(isinstance(k, int) for k in d):
            return [from_lua(d[k]) for k in sorted(d)]
        return {k: from_lua(x) for k, x in d.items()}
    return v


def run_scenario(src, name, config, extra_steps=None):
    L = lua54.LuaRuntime(unpack_returned_tuples=True)
    L.execute(open(os.path.join(HERE, 'mock_reframework.lua')).read())
    L.execute(open(os.path.join(HERE, 'runner.lua')).read())
    H = L.globals().HARNESS
    M = L.globals().MOCK
    if config is not None:
        M.json_files[CONFIG_NAME] = to_lua(L, config)
    H.load_script(src, os.path.basename(SCRIPT))
    H.frames(5)
    H.ui(False)
    H.hooks()
    H.frames(2)
    if extra_steps:
        extra_steps(L)
    H.ui(True)
    H.frames(1)
    H.reset()
    s = from_lua(H.summary())
    for k in ('errors', 'labels', 'files', 'json_files'):
        if not isinstance(s.get(k), list):
            s[k] = list((s.get(k) or {}).values())
    s['scenario'] = name
    s['rr_dev'] = L.eval('RR_DEV ~= nil')
    cfg = M.json_files[CONFIG_NAME]
    s['config_after'] = from_lua(cfg) if cfg is not None else None
    if s['rr_dev']:
        r = L.execute('''
            local errs = {}
            local function t(name, f, ...) local ok, e = pcall(f, ...); if not ok then errs[#errs + 1] = name .. ": " .. tostring(e) end; return e end
            t("status", RR_DEV.status); t("tracked", RR_DEV.tracked); t("regions", RR_DEV.regions)
            local ok_arm = t("arm golem", RR_DEV.arm, "golem"); t("disarm", RR_DEV.disarm)
            t("force_eye_final", RR_DEV.force_eye_final); t("force_devour_final", RR_DEV.force_devour_final, "purgener")
            t("sample_pick", RR_DEV.sample_pick, 200, false); t("log_tail", RR_DEV.log_tail, 5); t("log", RR_DEV.log, "x")
            return errs''')
        s['errors'] += [{'phase': 'RR_DEV', 'msg': e} for e in (from_lua(r) or [])] if isinstance(from_lua(r), list) else []
    s['_L'] = L
    return s


def static_check(path):
    sys.path.insert(0, HERE)
    import lua_globals
    key = hashlib.md5(open(path, 'rb').read()).hexdigest()
    cache = os.path.join(HERE, '.static_cache_' + key)
    if os.path.exists(cache):
        return pickle.load(open(cache, 'rb'))
    r = lua_globals.check(path)
    r = {k: {n: sorted({x for x in ls if x}) for n, ls in v.items()} for k, v in r.items()}
    pickle.dump(r, open(cache, 'wb'))
    return r


def main():
    global SCRIPT
    ap = argparse.ArgumentParser()
    ap.add_argument('script')
    ap.add_argument('--release', action='store_true', help='also check release-build rules')
    ap.add_argument('--configs', default=os.path.join(HERE, 'configs'))
    ap.add_argument('--no-static', action='store_true')
    ap.add_argument('--json')
    a = ap.parse_args()
    SCRIPT = a.script
    src = open(a.script, encoding='utf-8').read()
    problems = []
    report = {'script': a.script}

    if not a.no_static:
        st = static_check(a.script)
        report['static'] = st
        for n, lines in st['unknown_reads'].items():
            problems.append(f"STATIC  unknown global read '{n}' at lines {lines[:6]} (typo, or a local used before it is declared)")
        allowed_writes = set(json.load(open(os.path.join(HERE, 'allowed_globals.json')))) if os.path.exists(os.path.join(HERE, 'allowed_globals.json')) else set()
        for n, lines in st['global_writes'].items():
            if n not in allowed_writes:
                problems.append(f"STATIC  new global written '{n}' (missing 'local'?)")

    scenarios = [('fresh install (no config)', None)]
    for p in sorted(glob.glob(os.path.join(a.configs, '*.json'))):
        scenarios.append((os.path.basename(p), json.load(open(p))))
    results = []
    for name, cfg in scenarios:
        s = run_scenario(src, name, cfg)
        s.pop('_L')
        results.append(s)
        seen = set()
        for e in s['errors']:
            first = e['msg'].split('\n')[0]
            key = (e['phase'].split(' ')[0], first)
            if key in seen:
                continue
            seen.add(key)
            problems.append(f"RUNTIME [{name}] {e['phase']}: {first}")
        if a.release:
            if s['files']:
                problems.append(f"RELEASE [{name}] files written: {s['files']}")
            bad = [l for l in s['labels'] if any(w in l for w in DEV_ONLY_LABELS)]
            if bad:
                problems.append(f"RELEASE [{name}] dev UI drawn: {bad[:6]}")
            if s['rr_dev']:
                problems.append(f"RELEASE [{name}] RR_DEV test API is present")
    report['scenarios'] = results

    print(f"Harness: {os.path.basename(a.script)}  ({'release' if a.release else 'dev'} checks)")
    for s in results:
        print(f"  {s['scenario']}: {len(s['errors'])} errors, {s['hooks']} hooks, {s['entry_cbs']} entry + {s['frame_cbs']} frame callbacks, "
              f"{len(s['labels'])} UI labels, files written: {len(s['files'])}, RR_DEV: {s['rr_dev']}")
    if problems:
        print(f"\n{len(problems)} problem(s):")
        for p in problems:
            print('  - ' + p)
    else:
        print('\nNo problems found.')
    if a.json:
        json.dump(report, open(a.json, 'w'), indent=1, default=str)
    sys.exit(1 if problems else 0)


if __name__ == '__main__':
    main()
