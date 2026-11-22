extends RefCounted

enum Upgrade { UNDECIDED, STUDY, BODY }

enum ExamPlan { UNDECIDED, SAME_SCHOOL, ORIGINAL_PATH, HELP_XIAOHUI }

static var upgrade := Upgrade.UNDECIDED
static var exam_plan := ExamPlan.UNDECIDED
