# Micro Animations Research Report

A comprehensive guide to creating extremely delightful, immersive micro animations in SwiftUI. Compiled from Apple documentation, WWDC talks, community best practices, and analysis of the Motion codebase.

---

## Table of Contents

1. [The 12 Principles of Animation Applied to SwiftUI](#1-the-12-principles-of-animation-applied-to-swiftui)
2. [Spring Animation Mastery](#2-spring-animation-mastery)
3. [PhaseAnimator and KeyframeAnimator](#3-phaseanimator-and-keyframeanimator)
4. [Gesture + Animation Combos](#4-gesture--animation-combos)
5. [Haptic Integration](#5-haptic-integration)
6. [Micro Animation Catalog](#6-micro-animation-catalog)
7. [Performance Tips](#7-performance-tips)
8. [The "Feel" Spectrum](#8-the-feel-spectrum)
9. [Advanced Techniques](#9-advanced-techniques)
10. [Codebase Patterns Already in Use](#10-codebase-patterns-already-in-use)

---

## 1. The 12 Principles of Animation Applied to SwiftUI

Originally developed by Disney animators in the 1930s, these principles create motion that appears natural, fluid, and believable. Here is how each maps to SwiftUI APIs.

### 1.1 Squash and Stretch

The most important principle. Objects deform under force, conveying weight and flexibility.

```swift
// Button press: squash on contact, stretch on release
struct SquashStretchButton: View {
    @State private var isPressed = false

    var body: some View {
        Text("Press Me")
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(Capsule().fill(.blue))
            .foregroundStyle(.white)
            .scaleEffect(
                x: isPressed ? 1.1 : 1.0,
                y: isPressed ? 0.9 : 1.0
            )
            .animation(.spring(response: 0.25, dampingFraction: 0.5), value: isPressed)
            .onTapGesture {
                isPressed = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isPressed = false
                }
            }
    }
}
```

**SwiftUI APIs**: `.scaleEffect(x:y:)`, `.spring()` with low damping for overshoot, `GeometryEffect` for custom deformations.

### 1.2 Anticipation

A small preparatory motion before the main action. Signals to the user what is about to happen.

```swift
// Button presses down before launching a modal
withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) {
    buttonPressed = true  // scale to 0.95
}
DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
    buttonPressed = false
    present()  // main action
}
```

The Motion codebase uses this in `SharedElementTransition.swift` -- the Continue button scales to 0.95 with a fast spring before the modal appears.

**SwiftUI APIs**: Two-phase `withAnimation` calls, `DispatchQueue.main.asyncAfter` for sequencing, `.scaleEffect`.

### 1.3 Staging

Direct the user's eye to what matters. Animate the focal element while keeping everything else still.

```swift
// Staggered modal content appearance
withAnimation(.easeOut(duration: 0.25).delay(0.08)) { showIcon = true }
withAnimation(.easeOut(duration: 0.28).delay(0.12)) { showTitle = true }
withAnimation(.easeOut(duration: 0.30).delay(0.16)) { showDescription = true }
```

This pattern is already used in the codebase's `SharedElementTransition.swift` for the modal reveal.

**SwiftUI APIs**: `.delay()`, staggered `withAnimation` calls, `.opacity`, `.offset`.

### 1.4 Straight Ahead Action and Pose to Pose

- **Straight ahead**: Frame-by-frame animation using `TimelineView(.animation)` or `CADisplayLink`.
- **Pose to pose**: Define key states and let SwiftUI interpolate -- this is the default model.

```swift
// Pose to pose (most SwiftUI animations)
withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
    scale = isExpanded ? 1.2 : 1.0
}

// Straight ahead (frame-by-frame)
TimelineView(.animation) { timeline in
    let t = timeline.date.timeIntervalSinceReferenceDate
    let yOffset = sin(t * 3.0 + Double(index) * 0.8) * 20
    Text("K").offset(y: yOffset)
}
```

**SwiftUI APIs**: `TimelineView(.animation)`, `CADisplayLink`, `Timer.publish`, standard `withAnimation`.

### 1.5 Follow Through and Overlapping Action

Different parts of an object settle at different times. Hair keeps moving after the head stops.

```swift
// Card with content that overshoots differently
struct OverlappingCard: View {
    @State private var isShown = false

    var body: some View {
        VStack {
            Image(systemName: "star.fill")
                .scaleEffect(isShown ? 1.0 : 0.3)
                .animation(.spring(response: 0.35, dampingFraction: 0.5), value: isShown)

            Text("Title")
                .offset(y: isShown ? 0 : 20)
                .opacity(isShown ? 1 : 0)
                .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.05), value: isShown)

            Text("Description text here")
                .offset(y: isShown ? 0 : 15)
                .opacity(isShown ? 1 : 0)
                .animation(.spring(response: 0.45, dampingFraction: 0.75).delay(0.1), value: isShown)
        }
    }
}
```

**SwiftUI APIs**: Different `.animation()` modifiers on child views, varying `response` and `delay` values.

### 1.6 Slow In and Slow Out (Easing)

Objects accelerate and decelerate naturally rather than moving at constant speed.

```swift
// SwiftUI built-in easing curves
.animation(.easeInOut(duration: 0.3), value: state)  // symmetric
.animation(.easeOut(duration: 0.25), value: state)    // fast start, slow end (most common)
.animation(.easeIn(duration: 0.2), value: state)      // slow start, fast end (exits)

// Custom Bezier curves
.animation(.timingCurve(0.23, 1.0, 0.32, 1.0, duration: 0.4), value: state)
// ^ Telegram-style ease: fast start, smooth settle
```

**SwiftUI APIs**: `.easeIn`, `.easeOut`, `.easeInOut`, `.timingCurve()`, `.spring()` (inherently eased).

### 1.7 Arc

Natural motion follows curved paths, not straight lines.

```swift
// Combine offset X and Y with different timings for curved motion
struct ArcMotion: View {
    @State private var launched = false

    var body: some View {
        Circle()
            .frame(width: 20, height: 20)
            .offset(
                x: launched ? 200 : 0,
                y: launched ? -100 : 0
            )
            .animation(
                .spring(response: 0.6, dampingFraction: 0.8),
                value: launched
            )
    }
}
```

For true arc motion, use `KeyframeAnimator` with separate `KeyframeTrack` for X and Y with different timing curves.

### 1.8 Secondary Action

Supporting animations that reinforce the primary action without distracting.

```swift
// Primary: card scales up. Secondary: shadow expands, background dims
.scaleEffect(isExpanded ? 1.05 : 1.0)
.shadow(
    color: .black.opacity(isExpanded ? 0.2 : 0.08),
    radius: isExpanded ? 20 : 6,
    y: isExpanded ? 10 : 3
)
.background(Color.black.opacity(isExpanded ? 0.3 : 0))
```

### 1.9 Timing

The number of frames (duration) for a given action determines perceived weight and energy.

| Action | Duration | Reasoning |
|--------|----------|-----------|
| Button tap feedback | 0.12-0.18s | Instant, snappy |
| Toggle switch | 0.2-0.3s | Quick but visible |
| Card expansion | 0.3-0.4s | Smooth, noticeable |
| Page transition | 0.35-0.5s | Deliberate |
| Modal presentation | 0.3-0.45s | Clear staging |
| Loading pulse | 1.0-2.0s | Calm, continuous |
| Breathing animation | 2.0-3.0s | Ambient, subtle |

### 1.10 Exaggeration

Slightly amplify movements beyond realistic proportions for clarity.

```swift
// An error shake that exaggerates displacement
struct ShakeEffect: GeometryEffect {
    var progress: CGFloat
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let decay = exp(-2.5 * progress)
        let wave = sin(2 * .pi * 6 * progress) + sin(2 * .pi * 10 * progress) * 0.3
        let offset = 18 * decay * wave  // 18pt is exaggerated but clear
        return ProjectionTransform(
            CGAffineTransform(translationX: offset, y: 0)
        )
    }
}
```

This is already implemented in the Motion codebase's `HoldToFillButton.swift`.

### 1.11 Solid Drawing

In UI terms: maintain visual consistency during animations. Shadows, borders, and depth cues should animate coherently.

```swift
// Maintain 3D consistency during rotation
.rotation3DEffect(.degrees(tilt.x * 8), axis: (x: 0, y: 1, z: 0))
.rotation3DEffect(.degrees(-tilt.y * 8), axis: (x: 1, y: 0, z: 0))
.shadow(color: .black.opacity(0.1), radius: 20, y: 10)
```

### 1.12 Appeal

The overall charm of the animation. Comes from combining all other principles with appropriate personality.

```swift
// Breathing animation adds life to idle state
withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
    breathScale = 1.02
}
```

---

## 2. Spring Animation Mastery

Springs are the foundation of natural-feeling motion. SwiftUI offers several spring APIs.

### 2.1 The Three Spring APIs

```swift
// API 1: Response + Damping (most intuitive for designers)
.spring(response: 0.5, dampingFraction: 0.7)

// API 2: Named presets (iOS 17+)
.smooth          // response: 0.5, dampingFraction: 1.0
.smooth(duration: 0.3)
.snappy          // response: 0.3, dampingFraction: 0.85
.snappy(duration: 0.2)
.bouncy          // response: 0.5, dampingFraction: 0.7
.bouncy(extraBounce: 0.2)

// API 3: Interactive spring (for gesture tracking)
.interactiveSpring(response: 0.1)  // very fast, for finger tracking
```

### 2.2 Parameter Reference

**Response** controls speed: how quickly the value reaches its target.
- `0.1-0.2`: Very fast (finger tracking, micro feedback)
- `0.25-0.4`: Quick (button presses, toggles)
- `0.4-0.6`: Medium (card transitions, expansions)
- `0.6-0.9`: Slow (dramatic reveals, page transitions)

**Damping Fraction** controls bounce:
- `0.3-0.5`: Very bouncy (playful, elastic)
- `0.5-0.7`: Moderately bouncy (natural, lively)
- `0.7-0.85`: Slight bounce (polished, professional)
- `0.85-1.0`: No bounce (smooth, serious)
- `> 1.0`: Over-damped (sluggish, heavy)

### 2.3 Exact Parameter Recipes

#### Bouncy Button Press
```swift
// Press down
.animation(.spring(response: 0.15, dampingFraction: 0.5), value: isPressed)
// Scale: 0.92 -> 1.0

// Alternative with named preset
.animation(.snappy(duration: 0.18), value: isPressed)
```

#### Smooth Page Transition
```swift
.animation(.spring(response: 0.5, dampingFraction: 0.85), value: currentPage)
// Or
.animation(.smooth(duration: 0.45), value: currentPage)
```

#### Elastic Pull-to-Refresh
```swift
// During pull (rubber band feel)
let rubberBandOffset = pow(rawOffset, 0.72)  // diminishing returns formula

// On release (spring back)
.animation(.spring(response: 0.55, dampingFraction: 0.4), value: isRefreshing)
```

The `pow(rawOffset, 0.72)` rubber-banding formula is used in the codebase's `SharedElementTransition.swift` drag-to-dismiss.

#### Snappy Toggle
```swift
.animation(.spring(response: 0.25, dampingFraction: 0.65), value: isOn)
// Fast with a satisfying small overshoot
```

#### Heavy/Weighty Object
```swift
.animation(.spring(response: 0.7, dampingFraction: 0.6), value: position)
// Slow to start, visible overshoot -- feels massive
```

#### Light/Airy Float
```swift
.animation(.spring(response: 0.35, dampingFraction: 0.8), value: position)
// Quick response, minimal bounce -- feels weightless
```

#### Energetic Bounce (Celebration)
```swift
.animation(.spring(response: 0.3, dampingFraction: 0.35), value: trigger)
// Multiple oscillations, very playful
```

#### Snap to Position
```swift
.animation(.spring(response: 0.35, dampingFraction: 0.68), value: position)
// Quick with one clean overshoot -- used in the codebase for drag-to-dismiss snap-back
```

#### Modal Presentation
```swift
.animation(.spring(response: 0.32, dampingFraction: 0.75), value: showModal)
// Balanced: quick enough to not feel slow, damped enough to feel polished
```

### 2.4 The Apple Design Guidance on Springs

From WWDC 2018 "Designing Fluid Interfaces":

- **Start with 100% damping** (no overshoot) for smooth, graceful motion that does not distract.
- **Add bounce only when earned**: if a gesture has momentum (like a swipe), reward it with overshoot. If there is no momentum (like a tap), use 100% damping.
- **Think of response, not duration**: springs are behaviors, not prescriptions. They can be interrupted and retargeted.
- **Use bounciness as a teaching tool**: a small bounce can hint that something is interactive or exists behind a gesture.

---

## 3. PhaseAnimator and KeyframeAnimator

### 3.1 PhaseAnimator

Available iOS 17+. Cycles through discrete phases automatically or on trigger.

**When to use**: Multi-step animations where all properties change together at each step. Simpler than KeyframeAnimator. Good for loading indicators, attention animations, celebration effects.

#### Continuous Loop
```swift
PhaseAnimator([false, true]) { phase in
    Image(systemName: "heart.fill")
        .foregroundStyle(.red)
        .scaleEffect(phase ? 1.2 : 1.0)
        .opacity(phase ? 1.0 : 0.7)
}
// Cycles forever with default spring between phases
```

#### Triggered Animation with Custom Timing
```swift
enum SuccessPhase: CaseIterable {
    case initial, scaleUp, overshoot, settle

    var scale: CGFloat {
        switch self {
        case .initial: 0.0
        case .scaleUp: 1.15
        case .overshoot: 0.95
        case .settle: 1.0
        }
    }

    var opacity: CGFloat {
        switch self {
        case .initial: 0.0
        default: 1.0
        }
    }
}

Image(systemName: "checkmark.circle.fill")
    .font(.system(size: 60))
    .foregroundStyle(.green)
    .phaseAnimator(
        SuccessPhase.allCases,
        trigger: showSuccess
    ) { content, phase in
        content
            .scaleEffect(phase.scale)
            .opacity(phase.opacity)
    } animation: { phase in
        switch phase {
        case .initial: .spring(response: 0.01)
        case .scaleUp: .spring(response: 0.3, dampingFraction: 0.5)
        case .overshoot: .spring(response: 0.2, dampingFraction: 0.7)
        case .settle: .spring(response: 0.25, dampingFraction: 0.9)
        }
    }
```

#### Attention-Grabbing Notification Badge
```swift
enum PulsePhase: CaseIterable {
    case rest, bump, settle

    var scale: CGFloat {
        switch self {
        case .rest: 1.0
        case .bump: 1.3
        case .settle: 1.0
        }
    }

    var rotation: Angle {
        switch self {
        case .rest: .degrees(0)
        case .bump: .degrees(-15)
        case .settle: .degrees(0)
        }
    }
}

PhaseAnimator(PulsePhase.allCases) { phase in
    Text("3")
        .font(.caption.bold())
        .foregroundStyle(.white)
        .frame(width: 22, height: 22)
        .background(Circle().fill(.red))
        .scaleEffect(phase.scale)
        .rotationEffect(phase.rotation)
} animation: { phase in
    switch phase {
    case .rest: .easeInOut(duration: 2.0)  // long pause
    case .bump: .spring(response: 0.2, dampingFraction: 0.4)
    case .settle: .spring(response: 0.3, dampingFraction: 0.6)
    }
}
```

### 3.2 KeyframeAnimator

Available iOS 17+. Provides per-property timing control with multiple keyframe types.

**When to use**: Complex choreographed animations where different properties need independent timing. Bouncing objects, character animations, elaborate transitions.

#### The Pattern: Define AnimationValues Struct
```swift
struct BounceValues {
    var verticalOffset: CGFloat = 0
    var scale: CGFloat = 1.0
    var verticalStretch: CGFloat = 1.0
    var rotation: Angle = .zero
    var opacity: Double = 1.0
}
```

#### Bouncing Ball
```swift
Circle()
    .fill(.orange)
    .frame(width: 50, height: 50)
    .keyframeAnimator(initialValue: BounceValues()) { content, value in
        content
            .offset(y: value.verticalOffset)
            .scaleEffect(y: value.verticalStretch)
            .scaleEffect(value.scale)
            .rotationEffect(value.rotation)
    } keyframes: { _ in
        KeyframeTrack(\.verticalOffset) {
            SpringKeyframe(-100, duration: 0.3)   // launch up
            CubicKeyframe(0, duration: 0.3)       // fall down
            SpringKeyframe(-40, duration: 0.25)   // smaller bounce
            CubicKeyframe(0, duration: 0.25)      // settle
        }
        KeyframeTrack(\.verticalStretch) {
            CubicKeyframe(0.8, duration: 0.05)    // squash on ground
            SpringKeyframe(1.2, duration: 0.15)   // stretch going up
            CubicKeyframe(1.0, duration: 0.2)     // normalize mid-air
            CubicKeyframe(0.85, duration: 0.05)   // squash on landing
            SpringKeyframe(1.0, duration: 0.3)    // settle
        }
        KeyframeTrack(\.rotation) {
            LinearKeyframe(.degrees(0), duration: 0.1)
            SpringKeyframe(.degrees(360), duration: 0.8)
        }
    }
```

#### Four Keyframe Types
| Type | Behavior | Best For |
|------|----------|----------|
| `LinearKeyframe` | Constant-speed interpolation | Rotation, uniform motion |
| `SpringKeyframe` | Spring physics interpolation | Bounces, organic settling |
| `CubicKeyframe` | Bezier curve interpolation | Smooth arcs, easing |
| `MoveKeyframe` | Instant jump (no interpolation) | State resets, teleporting |

#### Celebration Checkmark
```swift
struct CheckmarkValues {
    var scale: CGFloat = 0.0
    var opacity: Double = 0.0
    var rotation: Angle = .degrees(-30)
    var yOffset: CGFloat = 20
}

Image(systemName: "checkmark.circle.fill")
    .font(.system(size: 80))
    .foregroundStyle(.green)
    .keyframeAnimator(
        initialValue: CheckmarkValues(),
        trigger: triggerCelebration
    ) { content, value in
        content
            .scaleEffect(value.scale)
            .opacity(value.opacity)
            .rotationEffect(value.rotation)
            .offset(y: value.yOffset)
    } keyframes: { _ in
        KeyframeTrack(\.scale) {
            SpringKeyframe(1.3, duration: 0.3, spring: .bouncy)
            SpringKeyframe(1.0, duration: 0.2)
        }
        KeyframeTrack(\.opacity) {
            LinearKeyframe(1.0, duration: 0.15)
        }
        KeyframeTrack(\.rotation) {
            SpringKeyframe(.degrees(0), duration: 0.4, spring: .bouncy(extraBounce: 0.1))
        }
        KeyframeTrack(\.yOffset) {
            SpringKeyframe(0, duration: 0.3, spring: .snappy)
        }
    }
```

### 3.3 PhaseAnimator vs KeyframeAnimator Decision Guide

| Criterion | PhaseAnimator | KeyframeAnimator |
|-----------|---------------|------------------|
| Complexity | Simple, discrete states | Complex, per-property timing |
| Control | All properties change per phase | Each property has its own timeline |
| Use case | Toggle states, pulse, attention | Choreographed motion, physics |
| Looping | Built-in continuous or triggered | Manual repeat setup |
| Learning curve | Low | Medium |

---

## 4. Gesture + Animation Combos

### 4.1 The Foundation: DragGesture with Animation

```swift
.gesture(
    DragGesture(minimumDistance: 0)
        .onChanged { value in
            // Interactive tracking -- use interactiveSpring for finger following
            withAnimation(.interactiveSpring(response: 0.1)) {
                currentTilt = CGPoint(
                    x: min(max(value.translation.width / 150, -1), 1),
                    y: min(max(value.translation.height / 150, -1), 1)
                )
            }
        }
        .onEnded { _ in
            // Release -- use a bouncier spring
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                currentTilt = .zero
            }
        }
)
```

This exact pattern is used in `ParallaxImageView.swift` in the codebase.

### 4.2 Rubber Banding

From Apple's "Designing Fluid Interfaces": gradually and softly indicate interface boundaries.

```swift
// Formula 1: Power function (used in codebase SharedElementTransition)
let rubberBanded = pow(rawOffset, 0.72)

// Formula 2: Asymptotic (used in codebase AudioWavePlayerView)
let rubberX = tx * 0.5 / (1 + abs(tx) / 200)

// Formula 3: Apple-style (from UIScrollView behavior)
let rubberBand = (1.0 - (1.0 / (offset * 0.55 / limit + 1.0))) * limit
```

### 4.3 Velocity-Aware Dismissal

```swift
.onEnded { value in
    // Use both distance AND predicted distance for intent
    if value.translation.height > 120 || value.predictedEndTranslation.height > 250 {
        dismiss()
    } else {
        // Snap back with bounce
        withAnimation(.spring(response: 0.35, dampingFraction: 0.68)) {
            dragOffset = 0
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
```

### 4.4 Momentum Projection

From WWDC 2018 -- calculate where gesture momentum will carry content:

```swift
func project(value: CGFloat, velocity: CGFloat, decelerationRate: CGFloat = 0.998) -> CGFloat {
    // UIScrollView-style projection
    return value + velocity * velocity / (2 * (1 - decelerationRate))
}

// Usage: find nearest snap point
let projected = project(value: currentPosition, velocity: gestureVelocity)
let nearestSnapPoint = snapPoints.min(by: { abs($0 - projected) < abs($1 - projected) })
withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
    position = nearestSnapPoint ?? currentPosition
}
```

### 4.5 Parallax Tilt with Drag + 3D Rotation

```swift
// From the codebase ParallaxImageView
Image("photo")
    .distortionEffect(
        ShaderLibrary.parallaxEffect(
            .float2(320, 400),
            .float2(currentTilt.x, currentTilt.y),
            .float(1.0)
        ),
        maxSampleOffset: CGSize(width: 30, height: 30)
    )
    .rotation3DEffect(.degrees(currentTilt.x * 8), axis: (x: 0, y: 1, z: 0))
    .rotation3DEffect(.degrees(-currentTilt.y * 8), axis: (x: 1, y: 0, z: 0))
```

### 4.6 Elastic Warp on Drag

The `AudioWavePlayerView.swift` in the codebase implements a perspective-warp `GeometryEffect` that deforms a chat bubble when dragged, using `CATransform3D` with perspective:

```swift
// Pseudo: pull creates 3D rotation + scale in drag direction
transform.m34 = -1.0 / 800  // perspective
let rotateY = tx * 0.003 * (px - 0.5).sign
transform = CATransform3DRotate(transform, rotateY, 0, 1, 0)
let scaleX = 1.0 + abs(tx) / w * 0.15
transform = CATransform3DScale(transform, scaleX, scaleY, 1)
```

### 4.7 Long Press + Fill + Release

From `HoldToFillButton.swift` in the codebase:

```swift
DragGesture(minimumDistance: 0)
    .onChanged { _ in
        guard !isPressed, !isLocked else { return }
        isPressed = true
        AudioServicesPlaySystemSound(1104)  // haptic on press start
        startFilling()                       // timer-based fill
    }
    .onEnded { _ in
        stopFilling()
        if fillProgress >= 1.0 {
            // Success sequence: hold -> shake -> reset
            isCompleted = true
            AudioServicesPlaySystemSound(1075)
            holdThenShake()
        } else {
            // Incomplete: spring back to empty
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                fillProgress = 0
            }
        }
    }
```

---

## 5. Haptic Integration

### 5.1 The Modern API: sensoryFeedback (iOS 17+)

```swift
// Declarative -- triggers when value changes
.sensoryFeedback(.impact(flexibility: .soft), trigger: isPressed)
.sensoryFeedback(.error, trigger: isShaking)
.sensoryFeedback(.success, trigger: isCompleted)
.sensoryFeedback(.selection, trigger: selectedIndex)

// Conditional trigger
.sensoryFeedback(.impact(weight: .medium), trigger: dragOffset) { old, new in
    abs(new) > 100 && abs(old) <= 100  // only at threshold
}
```

### 5.2 The UIKit API (for precise timing)

```swift
// Impact -- three intensities
UIImpactFeedbackGenerator(style: .light).impactOccurred()
UIImpactFeedbackGenerator(style: .medium).impactOccurred()
UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

// Selection -- for picker-like interactions
UISelectionFeedbackGenerator().selectionChanged()

// Notification -- semantic feedback
UINotificationFeedbackGenerator().notificationOccurred(.success)
UINotificationFeedbackGenerator().notificationOccurred(.warning)
UINotificationFeedbackGenerator().notificationOccurred(.error)

// System sounds (AudioToolbox) -- precise timing
AudioServicesPlaySystemSound(1104)  // tap
AudioServicesPlaySystemSound(1521)  // vibrate
AudioServicesPlaySystemSound(1075)  // complete
AudioServicesPlaySystemSound(1016)  // key press
```

### 5.3 Available sensoryFeedback Types

| Feedback | Description | Use Case |
|----------|-------------|----------|
| `.success` | Positive confirmation | Task completed, saved |
| `.warning` | Caution signal | Approaching limit |
| `.error` | Something went wrong | Validation failure, shake |
| `.selection` | Subtle selection tick | Picker scroll, tab change |
| `.increase` | Value going up | Volume, slider |
| `.decrease` | Value going down | Volume, slider |
| `.start` | Process beginning | Recording start |
| `.stop` | Process ending | Recording stop |
| `.alignment` | Snapping to guide | Grid snap, ruler |
| `.levelChange` | Discrete level change | Step progress |
| `.impact(flexibility:weight:)` | Physical impact | Button press, collision |

### 5.4 Haptic-Animation Pairing Rules

1. **Trigger haptic at the moment of visual change**, not before or after.
2. **Match intensity to visual scale**: light haptic for small motion, heavy for dramatic.
3. **Use semantic haptics**: `.success` for green checkmarks, `.error` for red shakes.
4. **Do not over-haptic**: reserve for meaningful moments. Frequent haptics become noise.
5. **Prepare generators ahead of time** for zero-latency response:
```swift
let generator = UIImpactFeedbackGenerator(style: .medium)
generator.prepare()  // call slightly before you need it
// ... later ...
generator.impactOccurred()
```

### 5.5 Pairing Examples from the Codebase

| Animation | Haptic | File |
|-----------|--------|------|
| Button press down | `AudioServicesPlaySystemSound(1104)` | HoldToFillButton.swift |
| Fill complete | `AudioServicesPlaySystemSound(1075)` | HoldToFillButton.swift |
| Shake error | `.sensoryFeedback(.error, trigger: isShaking)` | HoldToFillButton.swift |
| Modal present | `UIImpactFeedbackGenerator(style: .medium)` | SharedElementTransition.swift |
| Modal dismiss | `UIImpactFeedbackGenerator(style: .light)` | SharedElementTransition.swift |
| Drag snap back | `UIImpactFeedbackGenerator(style: .light)` | SharedElementTransition.swift |
| CTA press | `UIImpactFeedbackGenerator(style: .light)` | SharedElementTransition.swift |

---

## 6. Micro Animation Catalog

### 6.1 Button Feedback

#### Tap Pop (Most Common)
```swift
struct TapPopButton: View {
    @State private var pressed = false

    var body: some View {
        Text("Tap Me")
            .font(.headline)
            .padding(.horizontal, 26)
            .padding(.vertical, 14)
            .background(Capsule().fill(.blue))
            .foregroundStyle(.white)
            .scaleEffect(pressed ? 0.92 : 1.0)
            .animation(.snappy(duration: 0.18), value: pressed)
            .sensoryFeedback(.impact(flexibility: .soft), trigger: pressed)
            .onTapGesture {
                pressed = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    pressed = false
                }
            }
    }
}
```

#### Hold-to-Confirm
```swift
// Scale down while holding, fill progress bar, shake on complete
// See HoldToFillButton.swift in codebase for full implementation
.scaleEffect(isPressed ? 0.96 : breathScale)
.animation(.spring(response: 0.35, dampingFraction: 0.7), value: isPressed)
```

#### Jelly Button
```swift
struct JellyButton: View {
    @State private var animating = false

    var body: some View {
        Text("Jelly")
            .padding(.horizontal, 32).padding(.vertical, 16)
            .background(Capsule().fill(.purple))
            .foregroundStyle(.white)
            .scaleEffect(
                x: animating ? 1.08 : 1.0,
                y: animating ? 0.92 : 1.0
            )
            .animation(.spring(response: 0.2, dampingFraction: 0.35), value: animating)
            .onTapGesture {
                animating = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    animating = false
                }
            }
    }
}
```

### 6.2 Card Interactions

#### Lift on Hover/Press
```swift
RoundedRectangle(cornerRadius: 20)
    .fill(.ultraThinMaterial)
    .frame(height: 140)
    .scaleEffect(isHovered ? 1.03 : 1.0)
    .shadow(
        color: .black.opacity(0.25),
        radius: isHovered ? 30 : 10,
        y: isHovered ? 10 : 4
    )
    .animation(.smooth(duration: 0.22), value: isHovered)
```

#### Swipe to Dismiss
```swift
.offset(x: dragOffset)
.rotationEffect(.degrees(Double(dragOffset) / 20))
.opacity(1 - abs(dragOffset) / 500)
.gesture(
    DragGesture()
        .onChanged { value in
            dragOffset = value.translation.width
        }
        .onEnded { value in
            if abs(value.translation.width) > 150 {
                withAnimation(.spring(response: 0.3)) {
                    dragOffset = value.translation.width > 0 ? 500 : -500
                }
            } else {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    dragOffset = 0
                }
            }
        }
)
```

#### 3D Card Flip
```swift
.rotation3DEffect(
    .degrees(isFlipped ? 180 : 0),
    axis: (x: 0, y: 1, z: 0),
    perspective: 0.5
)
.animation(.spring(response: 0.6, dampingFraction: 0.8), value: isFlipped)
```

### 6.3 Loading States

#### Pulsing Dot
```swift
Circle()
    .fill(.blue)
    .frame(width: 12, height: 12)
    .scaleEffect(isPulsing ? 1.3 : 0.8)
    .opacity(isPulsing ? 1.0 : 0.4)
    .animation(
        .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
        value: isPulsing
    )
```

#### Three-Dot Wave
```swift
HStack(spacing: 8) {
    ForEach(0..<3) { i in
        Circle()
            .fill(.blue)
            .frame(width: 10, height: 10)
            .offset(y: isAnimating ? -8 : 0)
            .animation(
                .easeInOut(duration: 0.5)
                .repeatForever(autoreverses: true)
                .delay(Double(i) * 0.15),
                value: isAnimating
            )
    }
}
.onAppear { isAnimating = true }
```

#### Skeleton Shimmer
```swift
RoundedRectangle(cornerRadius: 8)
    .fill(.gray.opacity(0.15))
    .overlay(
        LinearGradient(
            colors: [.clear, .white.opacity(0.4), .clear],
            startPoint: .leading,
            endPoint: .trailing
        )
        .offset(x: shimmerOffset)
    )
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .onAppear {
        withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
            shimmerOffset = 300
        }
    }
```

### 6.4 Success/Error States

#### Success Checkmark
```swift
// Phase 1: Circle draws itself
// Phase 2: Checkmark strokes in
// Phase 3: Scale bump + haptic

Circle()
    .trim(from: 0, to: circleProgress)
    .stroke(.green, lineWidth: 3)
    .animation(.easeOut(duration: 0.4), value: circleProgress)

// After circle completes:
Image(systemName: "checkmark")
    .scaleEffect(checkScale)
    .animation(.spring(response: 0.25, dampingFraction: 0.4), value: checkScale)
    .sensoryFeedback(.success, trigger: showCheck)
```

#### Error Shake
```swift
// Use the ShakeEffect GeometryEffect from the codebase
.modifier(ShakeEffect(progress: shakeProgress))
.sensoryFeedback(.error, trigger: isShaking)

// Trigger:
withAnimation(.linear(duration: 0.6)) {
    shakeProgress = 1.0
}
```

#### Warning Jiggle
```swift
.rotationEffect(.degrees(isWarning ? 3 : 0))
.animation(
    .spring(response: 0.1, dampingFraction: 0.2)
    .repeatCount(5, autoreverses: true),
    value: isWarning
)
```

### 6.5 Pull-to-Refresh

```swift
struct PullToRefresh: View {
    @State private var pullOffset: CGFloat = 0
    @State private var isRefreshing = false

    var body: some View {
        VStack {
            // Indicator
            Image(systemName: "arrow.clockwise")
                .rotationEffect(.degrees(Double(pullOffset) * 2))
                .scaleEffect(min(pullOffset / 80, 1.0))
                .opacity(min(pullOffset / 60, 1.0))
                .offset(y: -40 + pullOffset * 0.5)

            // Content with rubber-band pull
            ScrollView { /* content */ }
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    let raw = max(0, value.translation.height)
                    pullOffset = pow(raw, 0.72)  // rubber band
                }
                .onEnded { _ in
                    if pullOffset > 60 {
                        isRefreshing = true
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            pullOffset = 50
                        }
                        // Simulate refresh
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                pullOffset = 0
                                isRefreshing = false
                            }
                        }
                    } else {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                            pullOffset = 0
                        }
                    }
                }
        )
    }
}
```

### 6.6 Tab Switching

```swift
// Capsule indicator slides between tabs
HStack(spacing: 0) {
    ForEach(tabs.indices, id: \.self) { index in
        Text(tabs[index])
            .frame(maxWidth: .infinity)
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedTab = index
                }
            }
    }
}
.overlay(alignment: .leading) {
    Capsule()
        .fill(.blue)
        .frame(width: tabWidth, height: 36)
        .offset(x: CGFloat(selectedTab) * tabWidth)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedTab)
}
.sensoryFeedback(.selection, trigger: selectedTab)
```

### 6.7 Text Input

#### Floating Label
```swift
Text("Email")
    .font(isFocused || !text.isEmpty ? .caption : .body)
    .foregroundStyle(isFocused ? .blue : .gray)
    .offset(y: isFocused || !text.isEmpty ? -24 : 0)
    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isFocused)
```

#### Character Count Warning
```swift
Text("\(text.count)/280")
    .foregroundStyle(text.count > 260 ? .red : .secondary)
    .scaleEffect(text.count > 260 ? 1.1 : 1.0)
    .animation(.spring(response: 0.2, dampingFraction: 0.5), value: text.count > 260)
```

### 6.8 Toggle/Switch

```swift
struct JuicyToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Capsule()
            .fill(isOn ? Color.green : Color.gray.opacity(0.3))
            .frame(width: 52, height: 32)
            .overlay(alignment: isOn ? .trailing : .leading) {
                Circle()
                    .fill(.white)
                    .frame(width: 28, height: 28)
                    .padding(2)
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
            }
            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: isOn)
            .sensoryFeedback(.impact(weight: .light), trigger: isOn)
            .onTapGesture { isOn.toggle() }
    }
}
```

### 6.9 List Item Interactions

#### Staggered Appearance
```swift
ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
    ItemRow(item: item)
        .offset(y: appeared ? 0 : 30)
        .opacity(appeared ? 1 : 0)
        .animation(
            .spring(response: 0.4, dampingFraction: 0.75)
            .delay(Double(index) * 0.05),
            value: appeared
        )
}
```

#### Swipe Actions with Spring
```swift
.offset(x: swipeOffset)
.gesture(
    DragGesture()
        .onChanged { value in
            // Asymmetric: easy to reveal, rubber-band the other way
            let raw = value.translation.width
            if raw < 0 {
                swipeOffset = raw  // smooth reveal
            } else {
                swipeOffset = pow(raw, 0.6)  // rubber band
            }
        }
        .onEnded { value in
            if value.translation.width < -80 {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    swipeOffset = -100  // snap to action position
                }
            } else {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                    swipeOffset = 0
                }
            }
        }
)
```

### 6.10 Navigation Transitions

#### Shared Element (matchedGeometryEffect)
```swift
// Source view
ContinueButton()
    .matchedGeometryEffect(id: "cta", in: ns)

// Destination view
ContinueButton()
    .matchedGeometryEffect(id: "cta", in: ns)

// Trigger
withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) {
    showModal = true
}
```

Already implemented in the codebase's `SharedElementTransition.swift`.

#### Custom Navigation Transition (iOS 18+)
```swift
.navigationTransition(.zoom(sourceID: item.id, in: namespace))
```

---

## 7. Performance Tips

### 7.1 What to Animate

**Fast (GPU-composited, no layout recalc)**:
- `.opacity`
- `.scaleEffect`
- `.offset`
- `.rotationEffect`
- `.rotation3DEffect`
- `.shadow` (moderate use)
- `.blur` (moderate use)

**Slow (triggers layout)**:
- `.frame()` changes
- `.padding()` changes
- `.font()` changes
- Content changes (adding/removing views)
- `GeometryReader` recalculations

### 7.2 The visualEffect Modifier (iOS 17+)

Applies visual changes after layout, avoiding expensive recalculation:

```swift
.visualEffect { view, proxy in
    view
        .scaleEffect(computeScale(proxy))
        .offset(y: computeOffset(proxy))
        .opacity(computeOpacity(proxy))
}
// Layout happens once, visual effects are GPU-only
```

### 7.3 drawingGroup()

Renders a view hierarchy as a single Metal texture. Use for:
- Complex overlapping animations
- Many simultaneous shape animations
- Heavy blend modes

```swift
ZStack {
    ForEach(0..<50) { i in
        Circle()
            .fill(.blue.opacity(0.3))
            .frame(width: 20, height: 20)
            .offset(x: offsets[i].x, y: offsets[i].y)
    }
}
.drawingGroup()  // renders entire ZStack as one texture
```

**Do NOT use drawingGroup() for**:
- Simple view hierarchies (adds overhead)
- Views needing hit testing on children
- Text rendering (can reduce quality)

### 7.4 Avoid Expensive Operations in Animation Callbacks

```swift
// BAD: complex computation every frame
TimelineView(.animation) { timeline in
    let result = expensiveComputation()  // blocks main thread
    // ...
}

// GOOD: precompute, only do fast lookups per frame
TimelineView(.animation) { timeline in
    let t = timeline.date.timeIntervalSinceReferenceDate
    let index = Int(t * 60) % precomputed.count
    // ...
}
```

### 7.5 CADisplayLink vs Timer for Custom Animation

The codebase uses both patterns. CADisplayLink is preferred for frame-accurate animation:

```swift
// CADisplayLink (used in BlackHoleView, StretchyTextView, AudioWavePlayerView)
let link = CADisplayLink(target: self, selector: #selector(tick))
link.add(to: .main, forMode: .common)

// Timer.publish (used in WaveTextView, KineticTextView)
let timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()
```

CADisplayLink syncs with display refresh, Timer does not. For 120fps ProMotion displays, CADisplayLink automatically adjusts.

### 7.6 Reduce Motion Accessibility

Always respect the user's preference:

```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion

.animation(reduceMotion ? nil : .spring(response: 0.3), value: state)

// Or provide a simpler alternative
if reduceMotion {
    content.opacity(isVisible ? 1 : 0)
} else {
    content
        .offset(y: isVisible ? 0 : 30)
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.9)
}
```

### 7.7 Profile with Instruments

Key instruments for animation performance:
- **Core Animation Commits**: measures render server work
- **Time Profiler**: find CPU bottlenecks
- **View Body**: tracks SwiftUI view re-evaluation frequency
- **Hangs**: detects main thread blocking
- **Metal System Trace**: for shader performance

Target: all frames under 8.3ms (120fps) or 16.6ms (60fps).

### 7.8 State Isolation

Keep animated state isolated to prevent unnecessary re-renders:

```swift
// BAD: animating a property on a large view model
@State private var viewModel = LargeViewModel()
// Changing viewModel.animatedValue redraws everything

// GOOD: isolate animated state
@State private var animatedValue: CGFloat = 0
// Only views depending on animatedValue redraw
```

---

## 8. The "Feel" Spectrum

### 8.1 Playful vs Professional

#### Playful
```swift
// High bounce, fast response, exaggerated scale
.spring(response: 0.3, dampingFraction: 0.4)
// Scale range: 0.85 - 1.15
// Add rotation, squash/stretch
// More haptic feedback
// Overshoot on every interaction
```

Example: A children's app, game, social media

#### Professional
```swift
// Minimal or no bounce, smooth, restrained
.spring(response: 0.4, dampingFraction: 0.9)
// Or: .smooth(duration: 0.3)
// Scale range: 0.97 - 1.02
// Opacity-based transitions preferred
// Haptics only on significant actions
```

Example: Banking app, productivity tool, health app

### 8.2 Heavy vs Light

#### Heavy (Objects with Mass)
```swift
// Slow response, visible overshoot, momentum matters
.spring(response: 0.7, dampingFraction: 0.6)
// Add velocity-dependent behavior
// Longer settle time
// Stronger haptic (.medium or .heavy)
```

Used for: drag-and-drop heavy objects, large modals, heavy toggles

#### Light (Airy, Weightless)
```swift
// Fast response, minimal overshoot
.spring(response: 0.25, dampingFraction: 0.85)
// Quick settle
// Light haptic or none
// Small displacement values
```

Used for: tooltips, badges, floating action buttons, notifications

### 8.3 Energetic vs Calm

#### Energetic
```swift
// Fast, multiple bounces, wider range
.spring(response: 0.2, dampingFraction: 0.3)
// Combine with rotation, scale, and color change
// Stagger delays: 0.03-0.05s between elements
// Use PhaseAnimator for multi-step celebration
```

Example: Achievement unlocked, streak counter, confetti

#### Calm
```swift
// Slow, fully damped, gentle
.spring(response: 0.8, dampingFraction: 1.0)
// Or: .easeInOut(duration: 0.6)
// Breathing animations: 2-3s cycle
// Subtle opacity changes: 0.7-1.0
// No haptics
```

Example: Meditation app, reading mode, ambient backgrounds

### 8.4 Quick Reference Chart

| Feel | Response | Damping | Scale Range | Haptic |
|------|----------|---------|-------------|--------|
| Snappy toggle | 0.25 | 0.65 | 0.95-1.0 | .impact(light) |
| Bouncy button | 0.2 | 0.4 | 0.88-1.05 | .impact(soft) |
| Smooth modal | 0.35 | 0.8 | 0.95-1.0 | .medium |
| Heavy drag | 0.7 | 0.6 | - | .heavy |
| Airy float | 0.3 | 0.9 | 0.98-1.02 | none |
| Elastic pull | 0.5 | 0.4 | - | .light |
| Error shake | 0.15 | 0.3 | - | .error |
| Success pop | 0.25 | 0.45 | 0.0-1.2 | .success |
| Breathing | 2.0 (easeInOut) | - | 1.0-1.02 | none |
| Celebration | 0.2 | 0.3 | 0.5-1.3 | .success |

---

## 9. Advanced Techniques

### 9.1 Chained/Sequenced Animations

```swift
func presentWithSequence() {
    // Step 1: Background dim
    withAnimation(.easeOut(duration: 0.2)) {
        showBackdrop = true
    }

    // Step 2: Card slides up (overlapping start)
    withAnimation(.spring(response: 0.35, dampingFraction: 0.75).delay(0.05)) {
        showCard = true
    }

    // Step 3: Content fades in (staggered)
    withAnimation(.easeOut(duration: 0.25).delay(0.12)) {
        showIcon = true
    }
    withAnimation(.easeOut(duration: 0.28).delay(0.16)) {
        showTitle = true
    }
    withAnimation(.easeOut(duration: 0.3).delay(0.2)) {
        showBody = true
    }

    // Step 4: Haptic at peak moment
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}
```

### 9.2 Staggered Group Animations

```swift
struct StaggeredGrid: View {
    let items: [Item]
    @State private var appeared = false

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))]) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                ItemCard(item: item)
                    .scaleEffect(appeared ? 1.0 : 0.5)
                    .opacity(appeared ? 1.0 : 0.0)
                    .animation(
                        .spring(response: 0.4, dampingFraction: 0.65)
                        .delay(staggerDelay(for: index)),
                        value: appeared
                    )
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                appeared = true
            }
        }
    }

    // Create a wave pattern: items closer to center appear first
    func staggerDelay(for index: Int) -> Double {
        let row = index / 4
        let col = index % 4
        let distance = sqrt(Double(row * row + col * col))
        return distance * 0.06
    }
}
```

### 9.3 Physics-Based Interactions

#### Custom Spring Engine (from codebase AudioWavePlayerView)

```swift
// Per-bar spring simulation
let springStiffness: CGFloat = 320
let springDamping: CGFloat = 18

for i in 0..<barCount {
    let displacement = barHeights[i] - barTargets[i]
    let springForce = -springStiffness * displacement
    let dampingForce = -springDamping * barVelocities[i]
    barVelocities[i] += (springForce + dampingForce) * dt
    barHeights[i] += barVelocities[i] * dt
}
```

#### Smooth Chase with Velocity (from codebase BlackHoleView)

```swift
if isDragging {
    // Exponential smoothing: chase finger
    currentPos.x += (targetPos.x - currentPos.x) * 0.08
    currentPos.y += (targetPos.y - currentPos.y) * 0.08
} else {
    // Damped spring drift back
    velocity.x = (velocity.x + (targetPos.x - currentPos.x) * 0.02) * 0.95
    velocity.y = (velocity.y + (targetPos.y - currentPos.y) * 0.02) * 0.95
    currentPos.x += velocity.x
    currentPos.y += velocity.y
}
```

#### Gravity Simulation
```swift
@objc func tick() {
    let dt: CGFloat = 1.0 / 60.0
    let gravity: CGFloat = 980  // pixels/s^2

    velocity.y += gravity * dt
    position.y += velocity.y * dt

    // Floor collision with energy loss
    if position.y > floorY {
        position.y = floorY
        velocity.y = -velocity.y * 0.6  // 40% energy loss
    }
}
```

### 9.4 Parallax Effects

#### Gyroscope-Based (from codebase)
```swift
class MotionManager: ObservableObject {
    private let manager = CMMotionManager()
    @Published var pitch: Double = 0
    @Published var roll: Double = 0
    private let smoothing: Double = 0.15

    init() {
        manager.deviceMotionUpdateInterval = 1.0 / 60.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion, let self else { return }
            self.pitch = self.pitch * (1 - smoothing) + motion.attitude.pitch * smoothing
            self.roll = self.roll * (1 - smoothing) + motion.attitude.roll * smoothing
        }
    }
}

// Usage: offset layers at different rates
Image("background").offset(x: roll * 5, y: pitch * 5)
Image("midground").offset(x: roll * 15, y: pitch * 15)
Image("foreground").offset(x: roll * 30, y: pitch * 30)
```

#### Scroll-Based Parallax
```swift
ScrollView {
    GeometryReader { geo in
        let minY = geo.frame(in: .global).minY
        Image("hero")
            .resizable()
            .scaledToFill()
            .offset(y: minY > 0 ? -minY * 0.5 : 0)  // parallax rate: 0.5x
            .scaleEffect(minY > 0 ? 1 + minY / 500 : 1)  // stretch on overscroll
    }
}
```

### 9.5 Morphing Between Shapes

```swift
// Use .contentTransition for text morphing
Text(words[currentIndex])
    .contentTransition(.numericText())
    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: currentIndex)

// Shape morphing with animatable properties
struct MorphShape: Shape {
    var morph: CGFloat  // 0 = circle, 1 = star

    var animatableData: CGFloat {
        get { morph }
        set { morph = newValue }
    }

    func path(in rect: CGRect) -> Path {
        // Interpolate between circle and star paths
        let circleRadius = min(rect.width, rect.height) / 2
        let starRadius = circleRadius * (1 - morph * 0.4)
        // ... path computation
    }
}
```

### 9.6 Breathing/Pulsing Effects

#### Subtle Breathing (Idle State)
```swift
// From codebase HoldToFillButton
withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
    breathScale = 1.02  // very subtle: 2% scale change
}
```

#### Glow Pulse
```swift
Circle()
    .fill(.blue)
    .frame(width: 12, height: 12)
    .shadow(
        color: .blue.opacity(glowing ? 0.8 : 0.2),
        radius: glowing ? 20 : 4
    )
    .animation(
        .easeInOut(duration: 1.4).repeatForever(autoreverses: true),
        value: glowing
    )
```

#### Heartbeat
```swift
PhaseAnimator([false, true]) { phase in
    Image(systemName: "heart.fill")
        .foregroundStyle(.red)
        .scaleEffect(phase ? 1.15 : 1.0)
} animation: { phase in
    phase
        ? .spring(response: 0.15, dampingFraction: 0.3)
        : .easeOut(duration: 0.6)
}
```

### 9.7 Contextual Animations (Respond to Content)

#### Dynamic Spring Based on Distance
```swift
// Further throws get heavier springs
let distance = hypot(translation.width, translation.height)
let response = 0.3 + (distance / 500) * 0.4  // 0.3 to 0.7
let damping = 0.6 + (distance / 500) * 0.2   // 0.6 to 0.8

withAnimation(.spring(response: response, dampingFraction: damping)) {
    position = snapTarget
}
```

#### Speed-Dependent Animation
```swift
// Fast gesture = snappy animation, slow gesture = smooth animation
let speed = hypot(velocity.width, velocity.height)
let response = speed > 1000 ? 0.25 : 0.45
let damping = speed > 1000 ? 0.7 : 0.85

withAnimation(.spring(response: response, dampingFraction: damping)) {
    state = newState
}
```

#### Content-Aware Stagger
```swift
// Longer text gets slightly longer animation
let characterCount = text.count
let duration = 0.3 + Double(characterCount) * 0.01  // scales with content

withAnimation(.spring(response: duration, dampingFraction: 0.7)) {
    showText = true
}
```

### 9.8 Metal Shader Animations

The codebase extensively uses Metal shaders for effects that SwiftUI cannot achieve natively:

| Shader | Effect | File |
|--------|--------|------|
| `waveEffect` | Sine-wave distortion | WaveText.metal |
| `stretchEffect` | Radial pull deformation | StretchyText.metal |
| `parallaxEffect` | Depth-shifted sampling | (via ParallaxImageView) |
| `blackHoleEffect` | Gravitational lensing | BlackHole.metal |
| `glossyReflection` | Gyroscope-driven specular | GlossySticker.metal |
| `liquidText` | Fluid simulation on text | LiquidText.metal |
| `vortexText` | Spiral distortion | VortexText.metal |
| `glitchText` | Digital artifact effect | GlitchText.metal |
| `noiseDissolve` | Perlin noise fade | NoiseDissolve.metal |
| `frozenImage` | Ice crystallization | FrozenImage.metal |
| `coinFlip` | 3D coin rotation | CoinFlip.metal |

These are applied via `.distortionEffect()`, `.colorEffect()`, and `.layerEffect()`.

### 9.9 DisplayLink-Based Custom Animators

For animations that need frame-by-frame control beyond what SwiftUI springs offer, the codebase pattern is:

```swift
@Observable
final class CustomAnimator {
    var current: CGFloat = 0
    var target: CGFloat = 0
    var velocity: CGFloat = 0
    private var displayLink: CADisplayLink?

    func start() {
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func tick() {
        let dt: CGFloat = 1.0 / 60.0
        // Custom physics here
        let force = -stiffness * (current - target)
        let damping = -dampingCoeff * velocity
        velocity += (force + damping) * dt
        current += velocity * dt
    }
}
```

Used in: `BlackHoleAnimator`, `StretchAnimator`, `AudioWaveEngine`.

---

## 10. Codebase Patterns Already in Use

### 10.1 Animation Architecture Summary

The Motion app uses these core patterns:

| Pattern | Where Used | Description |
|---------|-----------|-------------|
| Metal shaders + gesture | WaveTextView, StretchyTextView, ParallaxImageView | Shader uniforms driven by drag/tap |
| DisplayLink custom physics | BlackHoleView, StretchyTextView, AudioWavePlayerView | Frame-by-frame spring simulation |
| Gyroscope + Metal | GlossySticker, ParallaxImageView | Device tilt drives shader parameters |
| Staggered withAnimation | SharedElementTransition | Sequential delays for staged reveal |
| GeometryEffect | HoldToFillButton (ShakeEffect), AudioWavePlayerView (WarpEffect) | Custom animatable transforms |
| matchedGeometryEffect | SharedElementTransition, AudioWavePlayerView | Shared element transitions |
| TimelineView | KineticTextView | Continuous per-frame animation |
| Timer.publish | WaveTextView, BlackHoleView | 60fps time driver |
| Breathing animation | HoldToFillButton, SharedElementTransition | Idle-state scale pulse |
| Rubber banding | SharedElementTransition (pow 0.72), AudioWavePlayerView (asymptotic) | Soft boundary feedback |
| Multi-haptic sequencing | HoldToFillButton | Different system sounds at each stage |

### 10.2 What the Codebase Does NOT Yet Use

- **PhaseAnimator** -- could simplify multi-step sequences
- **KeyframeAnimator** -- could replace some DisplayLink physics with declarative keyframes
- **sensoryFeedback modifier** -- used in HoldToFillButton but not elsewhere (SharedElementTransition still uses UIKit haptics)
- **visualEffect modifier** -- could improve performance of scroll-based animations
- **Custom spring presets** (.bouncy, .snappy, .smooth) -- still using explicit response/dampingFraction
- **NavigationTransition** (.zoom) -- iOS 18 navigation transition API
- **Reduce Motion** support -- no `@Environment(\.accessibilityReduceMotion)` checks found

### 10.3 Patterns Worth Adopting

1. Replace staggered `DispatchQueue.main.asyncAfter` chains with `PhaseAnimator` for cleaner code.
2. Add `@Environment(\.accessibilityReduceMotion)` to all animation views.
3. Use `.visualEffect` for scroll-based position-dependent animations to avoid layout recalculation.
4. Consider `KeyframeAnimator` for the celebration/shake sequences in HoldToFillButton -- would be more declarative.
5. Consolidate `MotionManager` and `ParallaxMotionManager` into a single shared gyroscope manager.

---

## Sources

- [UI/UX Evolution 2026: Micro-Interactions and Motion](https://primotech.com/ui-ux-evolution-2026-why-micro-interactions-and-motion-matter-more-than-ever/)
- [iOS 2025 UX Trends: Micro-interactions and Fluid Animations](https://medium.com/@bhumibhuva18/hot-ios-2025-ux-trends-micro-interactions-fluid-animations-and-design-principles-developers-b52673769cd6)
- [Micro-Interactions in SwiftUI -- Subtle Animations That Make Apps Feel Premium](https://dev.to/sebastienlato/micro-interactions-in-swiftui-subtle-animations-that-make-apps-feel-premium-2ldn)
- [SwiftUI Animation Masterclass -- Springs, Curves and Smooth Motion](https://dev.to/sebastienlato/swiftui-animation-masterclass-springs-curves-smooth-motion-3e4o)
- [Understanding Spring Animations in SwiftUI](https://www.createwithswift.com/understanding-spring-animations-in-swiftui/)
- [Spring Animation Parameters (Apple Documentation)](https://developer.apple.com/documentation/SwiftUI/Animation/spring(response:dampingFraction:blendDuration:))
- [Advanced SwiftUI Animations Part 7: PhaseAnimator (SwiftUI Lab)](https://swiftui-lab.com/swiftui-animations-part7/)
- [Creating Advanced Animations with KeyframeAnimator (AppCoda)](https://www.appcoda.com/keyframeanimator/)
- [PhaseAnimator (Apple Documentation)](https://developer.apple.com/documentation/swiftui/phaseanimator)
- [Designing Fluid Interfaces (WWDC 2018)](https://developer.apple.com/videos/play/wwdc2018/803/)
- [Apple Human Interface Guidelines: Motion](https://developer.apple.com/design/human-interface-guidelines/motion)
- [SwiftUI Scroll Performance: The 120FPS Challenge](https://blog.jacobstechtavern.com/p/swiftui-scroll-performance-the-120fps)
- [SwiftUI Performance Optimization](https://dev.to/sebastienlato/swiftui-performance-optimization-smooth-uis-less-recomputing-422k)
- [Haptic Feedback with sensoryFeedback (Hacking with Swift)](https://www.hackingwithswift.com/quick-start/swiftui/how-to-add-haptic-effects-using-sensory-feedback)
- [Sensory Feedback in SwiftUI (Swift with Majid)](https://swiftwithmajid.com/2023/10/10/sensory-feedback-in-swiftui/)
- [The 12 Principles of UI/UX Animation](https://aviramaulani.medium.com/the-12-principles-of-ui-ux-animation-elevating-digital-experiences-baa9a4b416bf)
- [Disney's 12 Principles Applied to UI Design (IxDF)](https://ixdf.org/literature/article/ui-animation-how-to-apply-disney-s-12-principles-of-animation-to-ui-design)
- [Combining Gestures and Animations with SwiftUI](https://www.createwithswift.com/combining-gestures-and-animations-with-swiftui/)
- [The Art of Sequential Animations in SwiftUI](https://holyswift.app/how-to-do-sequential-animations-in-swiftui/)
- [GetStream SwiftUI Spring Animations Reference](https://github.com/GetStream/swiftui-spring-animations)
- [Bring Your SwiftUI Apps to Life: 7 Playful Micro-Interactions](https://gauravtakjaipur.medium.com/bring-your-swiftui-apps-to-life-7-playful-micro-interactions-every-ios-developer-should-know-68d24840d1b9)
