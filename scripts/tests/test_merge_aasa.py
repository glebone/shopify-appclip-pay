import json, os, sys, unittest
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import merge_aasa  # noqa: E402

FOREIGN = {"applinks": {"details": [
    {"appIDs": ["YA2642A35F.com.masterofcode.linkdemo"],
     "components": [{"/": "/UniversalLinkTest/amb/*", "comment": "keep me"}]}]}}
OURS = {"appclips": {"apps": ["T1.com.x.pay.Clip"]},
        "applinks": {"details": [{"appIDs": ["T1.com.x.pay"], "components": [{"/": "/pay/*"}]}]}}

class MergeAASATests(unittest.TestCase):
    def test_adds_our_entries_to_foreign_file(self):
        out = merge_aasa.merge(FOREIGN, OURS)
        self.assertEqual(out["appclips"]["apps"], ["T1.com.x.pay.Clip"])
        self.assertEqual(len(out["applinks"]["details"]), 2)

    def test_preserves_foreign_detail_verbatim(self):
        out = merge_aasa.merge(FOREIGN, OURS)
        self.assertEqual(out["applinks"]["details"][0], FOREIGN["applinks"]["details"][0])

    def test_replaces_previous_pay_entry_instead_of_appending(self):
        existing = json.loads(json.dumps(FOREIGN))
        existing["applinks"]["details"].append(
            {"appIDs": ["OLDTEAM.com.example.payclipdemo"], "components": [{"/": "/pay/*"}]})
        out = merge_aasa.merge(existing, OURS)
        pay = [d for d in out["applinks"]["details"] if d["components"] == [{"/": "/pay/*"}]]
        self.assertEqual(pay, OURS["applinks"]["details"])

    def test_drops_clip_of_the_parent_it_replaced(self):
        existing = {"appclips": {"apps": ["OLDTEAM.com.example.payclipdemo.Clip", "T9.com.other.Clip"]},
                    "applinks": {"details": [
                        {"appIDs": ["OLDTEAM.com.example.payclipdemo"], "components": [{"/": "/pay/*"}]}]}}
        out = merge_aasa.merge(existing, OURS)
        self.assertEqual(out["appclips"]["apps"], ["T9.com.other.Clip", "T1.com.x.pay.Clip"])

    def test_keeps_other_appclips_apps(self):
        existing = {"appclips": {"apps": ["T9.com.other.Clip"]}}
        out = merge_aasa.merge(existing, OURS)
        self.assertEqual(out["appclips"]["apps"], ["T9.com.other.Clip", "T1.com.x.pay.Clip"])

    def test_empty_existing(self):
        self.assertEqual(merge_aasa.merge({}, OURS), OURS)

    def test_does_not_mutate_inputs(self):
        before = json.dumps(FOREIGN)
        merge_aasa.merge(FOREIGN, OURS)
        self.assertEqual(json.dumps(FOREIGN), before)

if __name__ == "__main__":
    unittest.main()
