#!/usr/bin/env python3
"""Offline check of the build logic in Core.lua against a class guide JSON.

Mocks just enough of the WoW API (C_Traits, C_Spell, events) to load Locales.lua,
Core.lua and Data/<CLASS>.lua, fakes a talent tree from the JSON, spends the first
N points of each build and prints what the addon would recommend next.

Usage: tools/simulate.py research/WARRIOR.json [points_spent]
Requires: pip install lupa
"""
import json
import os
import sys

from lupa import LuaRuntime

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")

MOCK = r"""
local ns = {}
_G.__ns = ns
TalentCompassDB = { lang = "en", highlight = true, chatHints = true }
TalentCompassCharDB = {}
function GetLocale() return "enUS" end
function UnitClass() return "X", __class end
function UnitLevel() return 20 end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) print(m) end }
C_Timer = { After = function(_, f) end }
function geterrorhandler() return error end
function CreateFrame()
  return { RegisterEvent = function() end, SetScript = function() end }
end
SlashCmdList = {}
C_ClassTalents = { GetActiveConfigID = function() return 1 end }
C_Spell = {
  GetSpellName = function(id) return __spellNames[id] end,
  GetSpellTexture = function(id) return 1000 + id end,
}
C_Traits = {
  GetConfigInfo = function() return { treeIDs = { 1 } } end,
  GetGroupDisplayInfoByTreeID = function() return __groups end,
  GetTreeNodes = function() return __nodeIDs end,
  GetNodeInfo = function(_, nodeID) return __nodes[nodeID] end,
  GetEntryInfo = function(_, entryID) return { definitionID = entryID, maxRanks = __nodes[entryID].maxRanks } end,
  GetDefinitionInfo = function(defID) return { spellID = defID } end,
  GetTreeCurrencyInfo = function() return { { quantity = __unspent } } end,
}
return ns
"""


def load_file(lua, ns, path):
    with open(path, encoding="utf-8") as f:
        src = f.read()
    chunk = lua.execute("return function(src, name) return assert(load(src, name)) end")(src, path)
    chunk("TalentCompass", ns)


def main():
    path = sys.argv[1]
    spent = int(sys.argv[2]) if len(sys.argv) > 2 else 12
    data = json.load(open(path, encoding="utf-8"))
    cls = data["class"].upper()

    lua = LuaRuntime(unpack_returned_tuples=True)
    g = lua.globals()
    g.__class = cls
    ns = lua.execute(MOCK)
    for name in ("Locales.lua", "Core.lua", f"Data/{cls}.lua"):
        load_file(lua, ns, os.path.join(ROOT, name))
    g.TalentCompassDB = lua.table_from({"lang": "en", "highlight": True, "chatHints": True})

    for build_index, build in enumerate(data["builds"], 1):
        # Fake tree: one node per talent; node/entry/spell id are the same number.
        names, nodes, node_ids, groups = {}, {}, [], []
        ranks = {}
        remaining = spent
        for name, n in build["order"]:
            take = min(n, remaining)
            ranks[name] = ranks.get(name, 0) + take
            remaining -= take
        next_id = 100
        for tree_index, tree in enumerate(data["trees"], 1):
            groups.append(lua.table_from({"groupID": tree_index, "displayName": tree["name"]}))
            for t in tree["talents"]:
                next_id += 1
                names[next_id] = t["name"]
                nodes[next_id] = lua.table_from({
                    "ID": next_id, "posX": t.get("col", 1), "posY": t.get("tier", 1),
                    "entryIDs": lua.table_from([next_id]),
                    "groupIDs": lua.table_from([tree_index]),
                    "ranksPurchased": ranks.get(t["name"], 0),
                    "maxRanks": t.get("maxRank", 1),
                })
                node_ids.append(next_id)
        g.__spellNames = lua.table_from(names)
        g.__nodes = lua.table_from(nodes)
        g.__nodeIDs = lua.table_from(node_ids)
        g.__groups = lua.table_from(groups)
        g.__unspent = 1

        g.TalentCompassCharDB = lua.table_from({"build": build["id"]})
        active = ns.GetActiveBuild()
        scan = ns.ScanTree()
        plan = ns.ComputePlan(active, scan)
        step = plan.steps[plan.nextIndex] if plan.nextIndex else None
        missing = list(plan.missing.values())
        print(f"{cls} / {build['id']}: talents in tree={len(node_ids)} spent={spent} done={plan.doneCount}/{plan.total} "
              f"next={step.key + ' ' + str(step.rankAfter) + '/' + str(step.maxRanks) if step else '-'} "
              f"offBuild={len(plan.offBuild)} missing={missing}")
        g.TalentCompassCharDB = lua.table_from({})
        best = ns.BestBuild(scan)
        matches = {b["id"]: ns.MatchBuild(ns.classes[cls].builds[i + 1], scan).percent for i, b in enumerate(data["builds"])}
        print(f"   points of this build -> best match: {best.id}, match %: {matches}")
        assert best.id == build["id"] or matches[best.id] == matches[build["id"]], "best build should be the one the points came from"
        assert plan.doneCount == spent, "done count mismatch"
        assert plan.total == 51
        assert not missing


if __name__ == "__main__":
    main()
