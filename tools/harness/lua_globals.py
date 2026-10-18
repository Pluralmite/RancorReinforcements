"""Static check for a REFramework Lua script: finds global reads/writes that aren't known globals.

A read of an unknown global is almost always a typo or a local used before it is declared
(the classic "attempt to call a nil value" crash). Global writes are listed so new ones are deliberate.
"""
import sys, json, collections
from luaparser import ast, astnodes as N

LUA_STD = set("""_G _VERSION assert collectgarbage coroutine debug dofile error getmetatable io ipairs load loadfile
math next os package pairs pcall print rawequal rawget rawlen rawset require select setmetatable string table
tonumber tostring type utf8 xpcall warn""".split())
# globals that exist in REFramework's Lua state for DD2 (read from the live game through the bridge)
REF = set("""BehaviorTree BehaviorTreeCoreHandle BehaviorTreeNode BehaviorTreeNodeData BehaviorTreeObject
BehaviorTreeObjectData Delegate DynamicArrayManagedObject Matrix4x4f MemoryView ObjectExplorer Quaternion REComponent
REFGraphics REField REFramework REManagedObject REMethodDefinition REResource RETransform RETypeDefinition SystemArray
VR ValueType Vector2f Vector3f Vector4f base draw fs imgui imguizmo imnodes json log object_explorer re reframework
sdk thread vrmod""".split())


def line_of(node):
    t = getattr(node, '_first_token', None)
    return getattr(t, 'line', None) if t is not None else None


class Checker:
    def __init__(self, known):
        self.known = known
        self.scopes = [set()]
        self.reads = collections.defaultdict(list)
        self.writes = collections.defaultdict(list)

    def declared(self, name):
        return any(name in s for s in reversed(self.scopes))

    def declare(self, name):
        self.scopes[-1].add(name)

    def use(self, node):
        if not self.declared(node.id):
            self.reads[node.id].append(line_of(node))

    def write(self, node):
        if not self.declared(node.id):
            self.writes[node.id].append(line_of(node))

    def func(self, args, body, is_method=False):
        self.scopes.append(set())
        if is_method:
            self.declare('self')
        for a in args or []:
            if isinstance(a, N.Name):
                self.declare(a.id)
        self.visit(body)
        self.scopes.pop()

    def assign_target(self, tgt):
        if isinstance(tgt, N.Name):
            self.write(tgt)
        else:
            self.visit(tgt)

    def visit(self, node):
        if node is None:
            return
        if isinstance(node, list):
            for n in node:
                self.visit(n)
            return
        if not isinstance(node, N.Node):
            return
        t = type(node)
        if t is N.Chunk:
            self.visit(node.body)
        elif t is N.Block:
            self.scopes.append(set())
            for s in node.body:
                self.visit(s)
            self.scopes.pop()
        elif t is N.LocalAssign:
            self.visit(node.values)
            for tg in node.targets:
                self.declare(getattr(tg, "id", None) or getattr(getattr(tg, "name", None), "id", None))
        elif t is N.LocalFunction:
            self.declare(node.name.id)
            self.func(node.args, node.body)
        elif t is N.Function:
            self.assign_target(node.name)
            self.func(node.args, node.body)
        elif t is N.Method:
            self.visit(node.source)
            self.func(node.args, node.body, is_method=True)
        elif t is N.AnonymousFunction:
            self.func(node.args, node.body)
        elif t is N.Fornum:
            self.visit(node.start); self.visit(node.stop); self.visit(node.step)
            self.scopes.append({node.target.id})
            self.visit(node.body)
            self.scopes.pop()
        elif t is N.Forin:
            self.visit(node.iter)
            self.scopes.append({x.id for x in node.targets})
            self.visit(node.body)
            self.scopes.pop()
        elif t is N.Repeat:
            # the until-condition sees the body's locals
            self.scopes.append(set())
            body = node.body.body if isinstance(node.body, N.Block) else node.body
            for s in body:
                self.visit(s)
            self.visit(node.test)
            self.scopes.pop()
        elif t is N.Name:
            self.use(node)
        elif t is N.Index:
            self.visit(node.value)
            if node.notation == N.IndexNotation.SQUARE:
                self.visit(node.idx)
        elif t is N.Invoke:
            self.visit(node.source)
            self.visit(node.args)
        elif t is N.Field:
            if node.between_brackets:
                self.visit(node.key)
            self.visit(node.value)
        elif t is N.Assign:
            self.visit(node.values)
            for tg in node.targets:
                self.assign_target(tg)
        elif t in (N.Goto, N.Label):
            return
        else:
            for k, v in vars(node).items():
                if k.startswith('_') or k in ('comments',):
                    continue
                if isinstance(v, (N.Node, list)):
                    self.visit(v)


def check(path, extra_known=()):
    src = open(path, encoding='utf-8').read()
    tree = ast.parse(src)
    known = LUA_STD | REF | set(extra_known)
    c = Checker(known)
    c.visit(tree)
    written = set(c.writes)
    unknown_reads = {k: v for k, v in c.reads.items() if k not in known and k not in written}
    reads_of_own_globals = {k: v for k, v in c.reads.items() if k in written and k not in known}
    return {
        'unknown_reads': unknown_reads,              # likely bugs
        'global_writes': dict(c.writes),             # globals the script creates
        'reads_of_own_globals': reads_of_own_globals,
    }


if __name__ == '__main__':
    r = check(sys.argv[1])
    print(json.dumps({k: {n: sorted(set(x for x in ls if x))[:8] for n, ls in v.items()} for k, v in r.items()}, indent=1))
