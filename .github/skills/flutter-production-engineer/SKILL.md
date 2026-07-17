---
name: flutter-production-engineer
description: 'Use for Flutter app performance profiling, startup optimization, app size reduction, jank and smoothness fixes, production readiness reviews, clean code improvements, and security hardening.'
argument-hint: 'Flutter app review, performance optimization, or production hardening'
user-invocable: true
disable-model-invocation: false
---

# Flutter Production Engineer

Use this skill when the task is to improve a Flutter app with a strong bias toward performance, efficiency, reliability, clean architecture, and security.

## What This Skill Produces

A production-focused Flutter review or implementation plan that:
- Identifies the highest-impact performance bottlenecks first
- Reduces app startup time, frame drops, rebuilds, memory pressure, and bundle size
- Improves code clarity and maintainability without unnecessary abstraction
- Hardens security-sensitive flows and data handling
- Ends with concrete, testable follow-up actions

## When to Use

Use this skill for tasks involving:
- Slow startup, janky scrolling, dropped frames, or UI lag
- Excessive rebuilds, expensive widget trees, or inefficient state handling
- Large app size, asset bloat, or dependency cleanup
- Memory leaks, battery drain, or background work inefficiency
- Production readiness reviews and release risk checks
- Security concerns such as secrets handling, auth flow safety, input validation, storage, and network hygiene
- Refactoring toward cleaner, more maintainable Flutter code

## Operating Principles

1. Optimize the user-visible bottleneck first.
2. Prefer measurement over guesswork.
3. Change the smallest surface that solves the issue.
4. Preserve behavior unless the task explicitly asks for product changes.
5. Treat security as a first-class requirement, not a final pass.
6. Favor Flutter-native solutions before adding dependencies.
7. Avoid overengineering; every abstraction must justify itself.

## Workflow

1. Define the target outcome.
   - Clarify whether the goal is performance, size, smoothness, maintainability, security, or a combination.
   - Identify the user flow, screen, or release slice in scope.

2. Find the controlling path.
   - Trace the widget tree, state source, network path, persistence layer, or build pipeline that directly controls the issue.
   - Prefer the nearest code that actually computes, renders, stores, or mutates the behavior.

3. Measure or infer the bottleneck.
   - Look for expensive rebuilds, synchronous work on the UI thread, repeated allocations, heavy images, large lists, unbounded listeners, or unnecessary package weight.
   - For security, inspect trust boundaries, secret handling, storage, transport, and data validation.

4. Choose the smallest effective fix.
   - Reduce rebuild scope, split widgets, move work off the frame path, cache carefully, lazy-load where safe, or simplify state flow.
   - For app size, remove dead code, defer heavy packages, shrink assets, and prefer tree-shakeable usage.
   - For security, remove insecure defaults, tighten validation, and minimize sensitive exposure.

5. Validate the change.
   - Re-run the narrowest relevant check available.
   - Confirm behavior, performance impact, or security posture improved without introducing regressions.

6. Summarize with evidence.
   - State what changed, why it was the right bottleneck, and what remains risky or worth measuring next.

## Quality Checklist

A good result should satisfy most of these:
- The bottleneck is identified, not guessed
- The fix is localized and easy to reason about
- Frame-time, rebuild, memory, or startup impact is meaningfully improved
- App size impact is considered when dependencies or assets change
- Security-sensitive code has explicit validation and safe defaults
- Code remains readable, testable, and maintainable
- Validation was run or clearly explained if unavailable

## Preferred Output Format

When asked to review or improve code, produce:
- The likely root cause
- The exact code path involved
- The change made or recommended
- The validation performed
- Any residual risks or next measurements

## Guardrails

- Do not trade correctness or security for raw speed.
- Do not add packages unless they materially improve the outcome.
- Do not optimize broadly without a clear bottleneck.
- Do not introduce complex architectures unless the problem demands them.
- Do not weaken auth, input validation, or storage safety for convenience.
