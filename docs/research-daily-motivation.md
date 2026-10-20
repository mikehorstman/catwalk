# Research: what keeps people walking — a step goal or daily challenges?

**The question.** Should Catwalk keep a daily step goal, or move to time-based challenges ("walk 20 minutes"), or something else? What do other walking apps do, and what does the evidence say about which keeps people coming back?

**Short answer.** Keep **steps** as the spine and add **variety** on top of it. Steps are the only measure the phone gives passively and honestly, they are the one thing every walking app can compare, and the evidence for step goals is the strongest of the options. Time-based challenges work better as a *translation* ("≈ 40 min of walking") and as *side quests*, not as a second scoreboard. The bigger lever than either metric is **how the goal is set**: research shows a higher goal does make people walk more, but also makes them fail more often, and failing is what kills retention in an app like this one.

---

## 1. What the evidence says

1. **Step goals work, and pedometers add about 2,000 steps a day.** Bravata et al. (JAMA 2007), 26 studies / 2,767 people: pedometer users walked ~27 % more, about +2,000 steps/day, with small improvements in weight and blood pressure. Step goals are the best-evidenced simple intervention in this space. <https://doi.org/10.1001/jama.298.19.2296>

2. **7,000 is the useful number, not 10,000.** Ding et al. (Lancet Public Health 2025), a dose-response meta-analysis of device-measured daily steps: all-cause mortality risk is about half the reference at ~7,000 steps, and gains flatten after ~8,000–10,000 (HR ~0.53 at 7,000 vs ~0.52 at 10,000). 10,000 is commonly traced to a 1960s Japanese pedometer campaign, not to physiology. <https://www.thelancet.com/journals/lanpub/article/PIIS2468-2667(25)00164-1/fulltext>

3. **A higher goal gets more walking but fewer wins — a direct trade-off.** Chevance et al. (2020), an N-of-1 study with daily step goals set at 1–2.6× each person's baseline: "setting a higher physical activity goal leads to engaging in higher physical activity levels, but concurrently lower goal achievement." Both effects were roughly linear. This is the single most important finding for Catwalk, because here a missed goal costs the cat's mood and a streak. <https://pmc.ncbi.nlm.nih.gov/articles/PMC7928044>

4. **Time and intensity have the health-guideline backing.** Google Fit replaced its step goal with **Move Minutes + Heart Points**, built with the American Heart Association and WHO, because "many users were not meeting the recommended levels of physical activity, even among those that were consistently active every day". The AHA guideline is 150 min/week of moderate activity. Note what they did *not* do: they did not keep steps and add minutes as two targets — they made intensity the target. <https://heart.org/en/news/2018/08/21/google-just-launched-heart-points-here-are-5-things-you-need-to-know>

5. **Step and minute goals are both used, and neither clearly wins on adherence.** In a 6-month behavioural programme (PMC8838543), adherence to step-based and minute-based goals followed similar patterns; the **first two months** were the formative window, and adherence tracked *self-monitoring and goal attainment together* — not the metric. <https://pmc.ncbi.nlm.nih.gov/articles/PMC8838543/>

6. **Gamification works, but modestly and unevenly.** A 2022 meta-analysis of RCTs found gamified interventions do increase physical activity, with large heterogeneity and weak long-term evidence — the "novelty effect" problem. <https://pmc.ncbi.nlm.nih.gov/articles/PMC8767479/> Practical reading: do not build a feature and assume it keeps working in month three.

7. **Streaks are powerful, and forgiveness makes them *more* effective, not less.** Duolingo's own write-up: a better streak animation raised 7-day retention by **+1.7 %**, and allowing **two** streak freezes instead of one raised daily active learners by **+0.38 %** — freezes did not encourage skipping, they reduced quitting. <https://blog.duolingo.com/how-duolingo-streak-builds-habit/>

8. **Step counts are imperfect measurements.** Phone and wrist step counters are sensitive to gait, device placement and non-walking movement (drumming, shaking). This is an argument for using the phone's own health store rather than a home-made counter — which Catwalk already does — and for treating the number as a nudge, not a medical measurement.

## 2. What other apps do

| App | What you are asked to hit | Failure state | Notable mechanic |
|---|---|---|---|
| **Apple Fitness** | 3 rings: Move (kcal), Exercise (minutes), Stand (hours) | Rings stay open | Minutes + intensity; rings are the metaphor |
| **Google Fit** | Move Minutes + Heart Points | Goal unclosed | Guideline-based (150 min/week), intensity weighted |
| **Fitbit** | 10,000 steps default, Active Zone Minutes | Nothing breaks | Step goals plus "zone minutes" for intensity |
| **Pokémon GO** | Distance (eggs, buddy, Adventure Sync) | Nothing breaks | No daily target: distance is a resource, not a score |
| **Pikmin Bloom** | Steps → seedlings → flowers | Nothing breaks | **No failure state at all**; steps are currency |
| **Walkr** | Steps → energy for a spaceship | Nothing breaks | Tiny early goals, fast unlocks |
| **Sweatcoin** | Steps → currency | Nothing breaks | Steps as money (marketplace) |
| **Zombies, Run!** | 20–30 min episodes | Nothing breaks | **Time** and story, not steps; you finish an episode |
| **StepBet / Stridekick** | Weekly step challenges | Money at risk | Stakes; strong but a different tone |
| **Finch** | Self-care actions | Pet gets sad | **Attachment** to a pet is the retention engine |

Two patterns stand out. The games that retain casual users (**Pikmin Bloom**, **Walkr**) have **no failure state** and turn steps into a currency for unlocking things. The apps with a real daily target (**Apple**, **Google**, **Fitbit**) keep the target but make it *modest and forgiving*. The apps that use a hard target plus a penalty (**StepBet**) work, but through money and competition, which is not Catwalk's tone.

Catwalk currently sits in the harshest corner: a daily target, a pet that visibly suffers, a streak that breaks, and a cat that can run away. That is why the goal-setting findings matter more here than in any of the apps above.

## 3. So: steps or minutes?

**Steps, as the spine.** Reasons:
- It is the measure the phone gives passively and honestly, which is already a Catwalk rule ("the phone's own record is the source of truth").
- The evidence for step goals is the strongest, and 7,000 is a defensible, reachable number.
- Minutes require trusting intensity estimates that the health store does not always provide; on the step-sensor fallback there are no minutes at all.
- Every competitor can be compared on steps, which makes the number feel meaningful.

**Minutes, as a translation and as flavour.** "6,000 steps ≈ 40 minutes of walking" gives people a second way to picture the goal without a second counter — useful for anyone who thinks in time, and it matches the AHA/Google framing. At a normal pace, roughly 100 steps a minute.

**One extra daily challenge, as variety.** Not a second goal — a *side quest*, one per day, always optional, always step-derived so there is only ever one number that matters. This is where the "walk 20 minutes" idea belongs: it is a way to vary *how* you walk, not another thing to fail at.

## 4. What this means for Catwalk, concretely

**a. Set the goal from the person, not from marketing.** Onboarding should suggest a goal from the phone's last 7 days (median daily steps × 1.1), clamped to 3,000–12,000; 6,000 only when there is no history. This directly answers Chevance: pick the goal that gets walked *and* hit. Show 7,000 in the copy as the number most of the benefit sits at.

**b. Show the goal in two languages.** Steps as the number, "≈ 40 min of walking" underneath. One target, two readings.

**c. One rotating side quest per day**, chosen from step data and difficulty-ramped over the first two weeks (the formative window from finding 5):
- "Two walks of 10 minutes" — split walking is easier to fit into a day
- "20 minutes before noon"
- "Beat yesterday"
- "Walk after dinner"
- "A street you have not walked" (needs the map; later)
Each pays a small bonus and never costs the cat anything if missed. It exists to add novelty, which is the thing gamification research says fades.

**d. Keep the forgiveness layer, and let evidence guide it.** The freeze mechanic, the 50 % half day and the weekly walk home are all in line with Duolingo's finding that forgiveness raises activity rather than lowering it. Do not tighten them to "motivate".

**e. Frame the week, not only the day.** A daily streak plus a 7-day view (already built) gives people with irregular schedules a way to win the week. Consider a later "flexible week" mode: 5 of 7 days, or a weekly step total, for shift workers and parents.

**f. Do not add a second scoreboard.** No parallel "minutes goal". No leaderboard before slice 6, and then carefully — the gamification evidence is mixed, and social comparison demotivates the people who most need the app.

## 5. What to build, in order

1. **Goal suggestion from the first week** (biggest single lever, small change). Falls back to 6,000.
2. **The minutes translation** on Home and in onboarding copy: "≈ 40 min".
3. **Side quests**: one per day, step-derived, optional, small bonus. Needs hourly step buckets from the health store; degrade to step-only quests when only the sensor is available.
4. **Copy pass**: 7,000 as the reference number, "most of the benefit", not "you failed".

## 6. What to avoid

- **Raising the goal aggressively.** It raises steps and lowers wins; in this app a lost win is a sad cat.
- **Two targets** (steps *and* minutes). It splits progress and doubles the sense of failure.
- **Penalties and money stakes.** Effective elsewhere, wrong tone here, and a legal/compliance mess.
- **A leaderboard as the fix for retention.** Mixed evidence, and it punishes the least active players.
- **Assuming a feature keeps working.** Gamification effects fade; plan to add novelty on a schedule.

## Sources

- Bravata DM et al. *Using Pedometers to Increase Physical Activity and Improve Health: A Systematic Review.* JAMA 2007;298(19):2296–2304. <https://doi.org/10.1001/jama.298.19.2296>
- Ding D et al. *Daily steps and health outcomes in adults: a systematic review and dose-response meta-analysis.* Lancet Public Health 2025;10(8). <https://www.thelancet.com/journals/lanpub/article/PIIS2468-2667(25)00164-1/fulltext>
- Chevance G et al. *Goal Setting and Achievement for Walking: A Series of N-of-1 Digital Interventions.* Annals of Behavioral Medicine 2020. <https://pmc.ncbi.nlm.nih.gov/articles/PMC7928044>
- American Heart Association. *Google just launched Heart Points. Here are 5 things you need to know.* 2018. <https://heart.org/en/news/2018/08/21/google-just-launched-heart-points-here-are-5-things-you-need-to-know>
- *Describing Transitions in Adherence to Physical Activity Self-monitoring and Goal Attainment.* PMC8838543. <https://pmc.ncbi.nlm.nih.gov/articles/PMC8838543/>
- *Evaluating the Effectiveness of Gamification on Physical Activity: Systematic Review and Meta-analysis of RCTs.* PMC8767479. <https://pmc.ncbi.nlm.nih.gov/articles/PMC8767479/>
- Duolingo. *The habit-building research behind your Duolingo streak.* 2022. <https://blog.duolingo.com/how-duolingo-streak-builds-habit/>
- *Validation of an open-source smartphone step counting algorithm.* PMC10081434. <https://ncbi.nlm.nih.gov/pmc/articles/PMC10081434>
