# Tempo: Smart Day — Marketing Content

> Ready-to-post copy for every major launch channel. All content written to publish as-is.

**App Store:** https://apps.apple.com/us/app/tempo-smart-day/id6759478302
**GitHub:** https://github.com/ashishkattamuri/Tempo
**Developer:** Ashish Kattamuri

---

## 1. Product Hunt

### Tagline

```
Your day, rescheduled — automatically, based on what matters.
```

*(58 characters)*

---

### Description (250–300 words)

Every productivity app assumes you'll stick to your plan. Tempo assumes you won't — and handles the fallout for you.

When life drops a surprise meeting into your afternoon, Tempo doesn't just flag the conflict. It proposes a resolution: your Non-Negotiable meeting stays put, your Identity Habit (a 45-minute run) compresses to its 20-minute minimum to keep the streak alive, your Flexible Task slides to the next free slot within seven days, and your Optional Goal gracefully steps aside. You review the proposal and approve it in one tap. Done.

That's the core idea: four task categories that map to how things actually feel in your life, and a scheduling engine that respects those priorities every time something goes wrong.

**Version 2.0 ships three major additions:**

- **Focus Block** — Automatically blocks distracting apps during any scheduled task using Apple's DeviceActivity + ManagedSettings framework. No app needs to stay open, no manual toggling. A custom indigo shield screen ("You're in the zone 🎯") appears with your current task name whenever you try to open a blocked app.

- **Fix My Day with Apple Intelligence** — On iOS 26+ with Apple Intelligence, the rescheduling engine is replaced by an on-device model that reasons about each task individually — its context, your sleep window, your existing commitments — and proposes whether to move it, shorten it, or defer it. Fully private, fully on-device.

- **Weekly Review** — Completion rates by category, a day-by-day bar chart, identity habit streaks, and an AI-generated narrative: a compassionate summary of your week, one specific pattern it noticed, and one concrete suggestion for next week.

No cloud sync. No account. No ads. Your data stays on your device.

Free on the App Store. Open source on GitHub (GPL-3.0).

---

### First Comment — Maker Story (150–200 words)

Hey Product Hunt! Ashish here, maker of Tempo.

I built Tempo because I kept failing at the same thing: I'd spend Sunday night planning a perfect week, then Tuesday would happen — an unexpected call, a task that ran long, a kid who needed something — and the whole plan would collapse. I'd either manually reshuffle everything (exhausting) or give up and lose the habit momentum I'd been building.

The breakthrough insight was that not all tasks fail the same way. A workout shouldn't just disappear — it should compress. A flexible work task shouldn't be lost — it should find the next real opening. A non-negotiable shouldn't even be touched. Once I encoded those rules, the scheduling engine basically wrote itself.

v2.0 took that a step further. Focus Block came from realising I'd reschedule my deep work block and then immediately open Twitter anyway. The Apple Intelligence integration came from wanting the rescheduling suggestions to feel less algorithmic and more like a thoughtful advisor who knows me.

I hope it helps you too. Would love your honest feedback — I read every comment.

---

### Gallery Captions for 5 Screenshots

**Screenshot 1 — Timeline View**
Your day at a glance. An hourly timeline from 5 AM to midnight shows every task colour-coded by category, with live progress tracking as the day unfolds.

**Screenshot 2 — Fix My Day**
When your plan breaks, Tempo proposes a fix. See exactly what moves, what compresses, and what defers — then approve it in one tap.

**Screenshot 3 — Focus Block**
The custom shield screen that appears when you open a blocked app mid-task. Indigo background. Your task name. A gentle reminder of what you chose to focus on.

**Screenshot 4 — Task Categories**
Four categories that map to how tasks actually feel: Non-Negotiable, Identity Habit, Flexible Task, and Optional Goal. Each one handled differently when conflicts arise.

**Screenshot 5 — Weekly Review**
Your week in numbers — completion rates, habit streaks, time invested by category — plus an AI-generated narrative that tells you what it noticed and what to try differently next week.

---

## 2. Twitter/X Thread

**Tweet 1**
I spent a year failing at productivity apps. The problem wasn't discipline — it was that every app assumed my plan would survive contact with the day. So I built one that expects it won't. 🧵

**Tweet 2**
Tempo is a scheduling app with four task types: Non-Negotiable, Identity Habit, Flexible Task, and Optional Goal. When conflicts happen, each one is handled differently — based on what it actually is.

**Tweet 3**
Your workout isn't an appointment. It shouldn't get "declined" like one. Identity Habits compress to their minimum viable duration on hard days. The streak stays alive. You don't have to choose between your habit and your day.

**Tweet 4**
v2.0 ships Focus Block: block distracting apps automatically during any scheduled task, using Apple's native DeviceActivity + ManagedSettings. No app needs to stay open. No manual toggling. 🚫📱

**Tweet 5**
When you try to open a blocked app, you see a custom indigo screen: "You're in the zone 🎯" — with your current task name. Not a shame spiral, just a quiet reminder of what you chose.

**Tweet 6**
On iOS 26+, Fix My Day uses Apple Intelligence on-device to reason about your schedule per task — not just a summary, but actual decisions: move it, compress it, or defer it. Fully private. No cloud.

**Tweet 7**
Falls back to a solid rule-based engine on iOS < 26. No features gated behind hardware you don't have yet. The core scheduling still works beautifully.

**Tweet 8**
Weekly Review: completion rates by category, habit streaks, a day-by-day breakdown, and an AI-generated narrative of your week — one pattern it noticed, one thing to try next week. 📊

**Tweet 9**
No account. No cloud sync. No ads. 1.7 MB. Open source on GitHub (GPL-3.0). Free on the App Store.

If you've ever had a plan fall apart by 10 AM, this one's for you.

**Tweet 10**
App Store: https://apps.apple.com/us/app/tempo-smart-day/id6759478302
GitHub: https://github.com/ashishkattamuri/Tempo

Would love to hear what breaks for you. Every piece of feedback shapes the next version. 🙏

#productivity #iOS #SwiftUI #AppleIntelligence #indiedev #buildinpublic

---

## 3. Reddit — r/productivity

### Title

I built an iOS app that reschedules your day for you when things go sideways — now with app blocking and Apple Intelligence

---

### Post Body

Long-time lurker, first-time poster here with something I've been building for the past year.

**The problem I kept running into**

Every productivity method I've tried — time blocking, GTD, the perfect Notion setup — breaks on the same thing: real life. By Tuesday morning my beautifully planned week is already a mess of conflicts and good intentions. The calendar apps just show me the chaos. They don't help me get out of it.

What I actually needed wasn't a better planning interface. It was something that could help me *replan* without me having to think through every domino.

**What I built**

Tempo is a scheduling app built around one core idea: not all tasks fail the same way, so they shouldn't be handled the same way when conflicts arise.

You assign each task one of four categories:

- **Non-Negotiable** — meetings, appointments, real deadlines. These never move. Everything else works around them.
- **Identity Habit** — the things that make you you: your run, your reading, your meditation. When the day gets hard, these compress to a minimum duration rather than disappearing entirely. The streak survives.
- **Flexible Task** — work that matters but has scheduling room. Gets moved to the next genuinely free slot (the engine searches up to 7 days out).
- **Optional Goal** — side projects, learning, nice-to-haves. Steps aside gracefully when the day is full.

When something disrupts your plan, Tempo shows you a proposed resolution. You can see exactly what it wants to move, compress, or defer — and you approve it before anything changes. You're always in control.

**What's new in v2.0**

Two things that took the app from useful to genuinely different:

*Focus Block* — Picks which apps to block during any task, and blocks them automatically when the task starts. Uses Apple's native DeviceActivity framework so it works in the background. When you try to open a blocked app, you see a custom screen with your task name on it ("You're in the zone 🎯"). Not a punishment, just a gentle anchor back to what you're supposed to be doing.

*Fix My Day with Apple Intelligence* — On iOS 26+, when your day breaks, the rescheduling suggestions are generated by an on-device model that reasons about each task individually. It knows your sleep schedule, sees your existing commitments, and considers what each task actually is before suggesting whether to move, shorten, or defer it. Totally private — nothing leaves the device.

*Weekly Review* — Completion rates, habit streaks, time by category, and an AI narrative of your week. One pattern it noticed, one thing to try differently.

**The honest bit**

It's free, there's no account, no cloud sync, no ads. 1.7 MB. Everything lives on your device. It's also open source on GitHub if you want to see how the scheduling engine works — I'm happy to talk through the priority logic in the comments if anyone's curious.

If you've tried it or have questions, I'd genuinely love to hear what you think. What would make it click for you?

App Store: https://apps.apple.com/us/app/tempo-smart-day/id6759478302
GitHub: https://github.com/ashishkattamuri/Tempo

---

## 4. Reddit — r/iOSProgramming

### Title

I integrated FoundationModels @Generable, DeviceActivity extensions, and ManagedSettingsUI into a scheduling app — lessons from v2.0

---

### Post Body

Just submitted v2.0 of Tempo (open source scheduling app) and wanted to write up some of the more interesting technical bits, since I couldn't find much documentation or community discussion on a few of these when I was building them.

**1. FoundationModels with @Generable for structured rescheduling output**

The core AI feature — "Fix My Day" — needed the on-device model to return structured decisions per task, not a freeform string. The `@Generable` macro from the FoundationModels framework (iOS 26+) was the right tool here.

I defined a `RescheduleDecision` struct annotated with `@Generable`, with an enum field for the action (`move_today`, `compress_today`, `defer_tomorrow`) and optional fields for a suggested time and rationale string. The model receives a prompt describing the task — its category, name, duration, original time, and the full list of existing commitments for the day — and returns a populated `RescheduleDecision` instance directly.

What I found: the model is genuinely good at respecting the constraint hierarchy when the prompt is structured clearly. Specifying sleep window start/end as hard boundaries, and listing Non-Negotiable tasks explicitly as immovable, got reliable results. The `@Generable` conformance meant I didn't have to write any JSON parsing or response validation — the framework handles it.

Fallback to the rule-based `ReshuffleEngine` happens via a simple `if #available(iOS 26, *)` guard. Both paths produce the same output shape, so the UI doesn't need to know which engine ran.

**2. DeviceActivity extension point changes in iOS 26**

This one caused the most head-scratching. The `DeviceActivityMonitor` extension point changed meaningfully in the iOS 26 SDK — specifically around how the system calls `intervalDidStart` and `intervalDidEnd` and what you're allowed to do inside them.

For Focus Block, I needed to apply a `ManagedSettings.Shield` on app categories and specific token-identified apps when a task starts, and remove it when the task ends. The extension (`TempoFocusExtension`) conforms to `DeviceActivityMonitor`. The `FocusBlockManager` in the main app schedules a `DeviceActivitySchedule` with a one-minute-precision start and end time for each task that has a Focus Group assigned.

Key things I learned:
- The extension runs in a separate process. It cannot access the main app's SwiftData store directly. I pass the necessary configuration (which apps to block, which categories) via a shared `UserDefaults` suite using an App Group.
- `ManagedSettings.ManagedSettingsStore` must be written from the extension, not the main app, for shields to apply correctly.
- You cannot conditionally apply shields based on dynamic data fetched at runtime inside the extension — everything the extension needs must be pre-written to the shared container before the schedule fires.

**3. Custom ShieldConfiguration with ManagedSettingsUI**

`TempoShieldExtension` conforms to `ShieldConfigurationDataSource`. The custom shield shows the task name on an indigo background with "You're in the zone 🎯" as the title. The task name is also passed via the shared `UserDefaults` suite — the extension reads it at `configuration(shielding:context:)` call time.

One gotcha: `ShieldConfigurationDataSource` has strict limits on what UIKit/SwiftUI elements you can use. You return a `ShieldConfiguration` with a `label`, optional `subtitle`, and a background colour — you can't inject arbitrary views. The indigo background is set via `ShieldConfiguration(backgroundColor: .init(named: "TempoIndigo", in: .main, compatibleWith: nil))` with the colour defined in the extension's own asset catalogue.

**4. FamilyControls entitlement**

`DeviceActivity` and `ManagedSettings` require the `com.apple.developer.family-controls` entitlement, which requires approval from Apple. For development/TestFlight you can use the `.individual` usage description; for distribution you need to submit a request justifying the use. Worth noting this in your App Store review notes — reviewers need a physical device to test Focus Block anyway.

The project is open source at https://github.com/ashishkattamuri/Tempo — the extension targets are `TempoFocusExtension/` and `TempoShieldExtension/` in the repo root. Happy to answer questions about any of this.

---

## 5. Hacker News — Show HN

### Title

```
Show HN: Tempo – iOS scheduler that uses Apple Intelligence to replan your day
```

*(79 characters)*

---

### First Comment Body

Hi HN. I built Tempo, a scheduling app for iOS that automatically proposes a resolution when your plan falls apart. The core idea: tasks have four categories (Non-Negotiable, Identity Habit, Flexible Task, Optional Goal), each handled differently when conflicts arise. A workout compresses instead of being dropped. A flexible task finds the next free slot. A non-negotiable is never touched. You see the proposed changes and approve them before anything moves.

Version 2.0 adds three things I'm particularly interested in technically:

**Focus Block** uses `DeviceActivity` + `ManagedSettings` + `FamilyControls` to block distracting apps automatically during scheduled tasks — no foreground process required. The blocking logic lives in a separate `DeviceActivityMonitor` extension. A custom `ShieldConfigurationDataSource` extension renders the blocked-app screen with the current task name. App-to-extension communication happens through a shared `UserDefaults` group since the extension is a separate process with no SwiftData access.

**Fix My Day with Apple Intelligence** uses FoundationModels with a `@Generable`-annotated struct to get structured per-task rescheduling decisions from the on-device model — `move_today`, `compress_today`, or `defer_tomorrow` — rather than a freeform summary. The model sees task context, sleep window, and existing commitments. Falls back to the rule-based engine on iOS < 26.

**Weekly Review** generates a narrative summary using the same FoundationModels path, with completion stats computed from SwiftData as context.

The app is free, stores everything on-device (SwiftData, no cloud), and is fully open source under GPL-3.0: https://github.com/ashishkattamuri/Tempo

I'd be particularly interested in feedback on the priority model itself — is four categories the right abstraction? Does anything feel like it belongs in a different bucket? And on the AI integration: is "propose then confirm" the right pattern for this, or would people trust it to act autonomously?

App Store: https://apps.apple.com/us/app/tempo-smart-day/id6759478302

---

## 6. IndieHackers Post

### Title

I shipped a scheduling app that reschedules itself — 1.5 years, one developer, zero revenue, a lot learned

---

### Post Body

I want to write this while the launch is still fresh and I haven't sanitised the memory of it yet.

**Where it started**

I've been obsessed with productivity systems for years — not in a content-creator way, but in a genuine "I want to ship more and feel less scattered" way. I tried everything. The problem I kept running into was that every tool optimised for planning and completely abandoned me when reality interrupted the plan.

The moment that broke me was a Tuesday morning when I had a perfect 8-hour work block laid out and by 10 AM it was already rubble. Three calendar conflicts, an urgent Slack message, and the whole Jenga tower fell. I spent 45 minutes manually reshuffling tasks I should've just been doing.

I thought: what if the reshuffling was automatic?

**Version 1.0: The engine**

The core scheduling engine — `ReshuffleEngine` — took about three months to get right. The insight that unlocked it was that tasks fail in categorically different ways. A habit that disappears is worse than a task that moves. A non-negotiable that gets bumped is worse than a flexible task that slips. So I built category-specific processors: one for each of the four task types, each with its own conflict resolution logic.

The rule-based engine searches up to 7 days forward for a free slot, respects sleep boundaries, compresses habits to a minimum viable duration before deferring them, and proposes everything — never applies changes without your explicit approval.

Shipping that to the App Store, getting Apple to approve the FamilyControls entitlement, learning that screenshots matter more than the app itself for conversion — all of that was its own education.

**Version 2.0: Where it got interesting**

Three features I'm most proud of, in order of how much they changed the product:

*Focus Block* — I'd rescheduled my deep work block dozens of times and then immediately opened social media anyway. The scheduling wasn't the problem. My own context-switching was. Focus Block uses Apple's `DeviceActivity` framework to block apps in the background during tasks, with a custom shield screen that shows your current task name. Getting the inter-process communication right between the main app and the two required extensions (`DeviceActivityMonitor` and `ShieldConfigurationDataSource`) took longer than I expected. The extensions can't access the main app's SwiftData store, so everything goes through a shared App Group.

*Apple Intelligence integration* — When iOS 26 and FoundationModels were announced, I rewrote the "Fix My Day" feature to use the on-device model with structured output via `@Generable`. It was surprisingly good at respecting the priority hierarchy when the prompt was well-structured. The whole "it reasons about your schedule and proposes decisions per task" thing went from a product fantasy to a real feature in about three weeks of integration work.

*Weekly Review* — Simpler to build, but it might be the feature users engage with most. People love a number that tells them how their week went.

**The honest numbers (as of launch week)**

Downloads: very early, watching carefully.
GitHub stars: growing slowly, a handful of contributors already.
Revenue: zero (it's free). I haven't decided whether to introduce a Pro tier for things like Apple Intelligence features or keep it entirely free.

**What I'd tell myself at the start**

The scheduling engine is not your moat. The moat is the specific sequence of decisions you make about what "smart" means — what compresses, what defers, what never moves. Get very opinionated about that and defend it. Vague "AI-powered scheduling" is table stakes now. Specific, named behaviours that users can predict and trust is the product.

Also: the FamilyControls entitlement review takes longer than you expect. Apply for it early.

And: write the App Store screenshots before you write the last feature. I did it backwards and spent a week on screenshots after the feature work was done when I should've been shipping.

**What's next**

Stage 3 of the roadmap is a conversational AI assistant — natural language task creation, proactive overload warnings, an evening planning brief. The scheduling logic Tempo has built becomes the reasoning layer the assistant operates on top of. I'm not rushing it. I want the v2.0 features to prove their value first.

If you're building something in the productivity space, I'd love to compare notes. And if you've used Tempo and have a take on what's missing, I'm all ears.

App Store: https://apps.apple.com/us/app/tempo-smart-day/id6759478302
GitHub: https://github.com/ashishkattamuri/Tempo

---

## 7. LinkedIn Post

**Introducing Tempo: Smart Day v2.0 — because most productivity apps optimise for planning, not for when plans break.**

I've spent the past year building a scheduling app for iOS that handles the part every calendar tool ignores: what happens when something disrupts your plan and you need to figure out what moves, what compresses, and what gets cut.

Tempo organises tasks into four priority categories — Non-Negotiable, Identity Habit, Flexible Task, and Optional Goal — and when conflicts arise, the scheduling engine handles each type differently. Your commitments stay fixed. Your daily habits compress to a minimum viable duration instead of disappearing. Your flexible work finds the next genuinely free slot. Your optional goals step aside gracefully.

Version 2.0 ships three meaningful additions:

**Focus Block** automatically blocks distracting apps during any scheduled task using Apple's native DeviceActivity framework. No manual toggling, no app to keep open. This was built because I realised I'd block time for deep work and then immediately undermine it with context-switching.

**Fix My Day with Apple Intelligence** uses FoundationModels on iOS 26+ to generate personalised rescheduling decisions per task — reasoning about task context, sleep schedule, and existing commitments entirely on-device. For users on older iOS versions, the rule-based engine runs unchanged.

**Weekly Review** provides completion analytics by category, habit streak tracking, and an AI-generated reflection on the week — one specific pattern identified, one actionable suggestion for next.

The app is free, stores all data on-device (no cloud, no account, no ads), and is open source on GitHub.

If you're building in the productivity space or thinking about Apple Intelligence integrations, I'd be glad to compare notes.

App Store: https://apps.apple.com/us/app/tempo-smart-day/id6759478302
GitHub: https://github.com/ashishkattamuri/Tempo

#productivity #iOS #mobileapp #AppleIntelligence #indiedevelopment #SwiftUI

---

## 8. Apple Editorial Submission

**Why Tempo: Smart Day deserves to be featured**

Most scheduling apps are built for an idealised version of the user — someone whose plan survives the day intact. Tempo is built for the version of the user who exists: someone whose plan will be disrupted, and who needs a tool that handles that disruption intelligently rather than just showing them the mess.

The app's four-category priority model — Non-Negotiable, Identity Habit, Flexible Task, Optional Goal — reflects a genuine insight about how people actually think about their commitments. The scheduling engine applies different logic to each category when conflicts arise: habits compress to minimum viable durations before they're deferred, flexible tasks find the next real free slot up to seven days forward, and non-negotiables are never touched. Users review every proposed change before it's applied. They're always in control.

Version 2.0 makes Tempo one of the first third-party apps to ship a meaningful Apple Intelligence integration using FoundationModels with structured `@Generable` output — generating per-task rescheduling decisions that reason about context, sleep windows, and existing commitments entirely on-device. It also uses DeviceActivity, ManagedSettings, and FamilyControls to automatically block distracting apps during focus sessions, with a custom shield screen that keeps users anchored to the task at hand.

The app collects zero data, requires no account, and weighs 1.7 MB. It is also fully open source.

Tempo is a focused, privacy-respecting, technically ambitious app that reflects exactly the kind of craftsmanship and Apple platform integration the App Store has always championed. We believe it would resonate strongly in a Productivity or Utilities editorial placement, particularly for an Apple Intelligence feature spotlight.

---

## 9. Press Pitch Email

**Subject:** Tempo: Smart Day — first iOS scheduler with per-task Apple Intelligence rescheduling + automatic app blocking (open source, free)

Hi [Editor name],

I'm Ashish Kattamuri, a solo iOS developer. I just shipped v2.0 of Tempo: Smart Day, a scheduling app I've been building for about a year, and I think it might be worth a look for [MacStories / 9to5Mac].

The app's core idea: tasks have four priority categories, each handled differently when your day breaks — habits compress instead of disappearing, flexible tasks find a new slot automatically, non-negotiables never move. You see the proposed changes and approve them in one tap.

v2.0 ships two things that feel technically noteworthy:

**Fix My Day with Apple Intelligence** uses FoundationModels with `@Generable`-annotated structured output on iOS 26+ to generate per-task rescheduling decisions — not a summary, but actual decisions (move, compress, or defer) reasoned against task context, sleep schedule, and existing commitments. Fully on-device.

**Focus Block** uses DeviceActivity + ManagedSettings + FamilyControls to automatically block distracting apps during scheduled tasks, with a custom shield screen that shows the current task name.

The app is free, stores everything on-device (no cloud, no account), and is open source on GitHub under GPL-3.0.

App Store: https://apps.apple.com/us/app/tempo-smart-day/id6759478302
GitHub: https://github.com/ashishkattamuri/Tempo

Happy to provide TestFlight access, a press kit, or answer any questions. Thanks for your time.

Ashish Kattamuri
ashishkattamuri.github.io/Tempo/
