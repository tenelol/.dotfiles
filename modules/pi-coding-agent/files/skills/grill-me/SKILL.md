---
name: grill-me
description: A relentless interview to sharpen a plan or design.
disable-model-invocation: true
compatibility: Pi with the native subagent extension for independent fact finding.
metadata:
  adapted-from: mattpocock/skills/grilling
---

Interview the user relentlessly until you reach a shared understanding. Map this as a **design tree**: every decision branches into the decisions that hang off it.

Work the tree in **rounds**. The **frontier** is every decision whose prerequisites are already settled: the questions you can ask now without guessing at answers you haven't heard yet. Ask the whole frontier in one round: number each question and give your recommended answer. Then wait for the user's answers before the next round.

Format a round like so:

```
❓ **Q1** - **<question title>**: <question body, including choices when useful>

➡️ <your recommended answer>

---

❓ **Q2** - **<question title>**: <question body>

➡️ <your recommended answer>
```

Each round the user answers reshapes the tree: settled decisions push the frontier outward and unblock questions that depended on them. Recompute the frontier and ask the next round. A question whose answer depends on another question still open in this round belongs to a later round.

Before sending a round, check each question against the other unresolved decisions. If an answer could make another question unnecessary or change its options, defer the dependent question. For example, decide whether multiple devices are needed before asking about synchronization.

Finding facts is your job, never the user's. Inspect available evidence or use Pi's `subagent` tool for independent fact finding. A running investigation is an unsettled prerequisite: ask the other independent questions while it runs. Decisions are the user's; recommend an answer and wait for their choice.

The interview is complete when the frontier is empty and the user confirms the shared understanding. Until then, continue fact finding and the interview; do not implement decisions or fill in the user's answers yourself.
