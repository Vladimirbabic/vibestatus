# VibeStatus Landing Page Specification

## Overview
A modern, dark-themed landing page for VibeStatus - a macOS menu bar app that shows Claude Code's real-time status. The design follows a clean, minimal aesthetic similar to typebetter.app.

---

## Technical Stack
- **Framework**: Next.js 14+ (App Router)
- **Styling**: Tailwind CSS
- **Fonts**: Inter (Google Fonts)
- **Hosting**: Vercel or GitHub Pages
- **Domain**: vibestatus.app (or similar)

---

## Color Scheme

```css
/* Background */
--bg-primary: #0a0a0a;
--bg-secondary: #1a1a1a;
--bg-card: #141414;

/* Text */
--text-primary: #ffffff;
--text-secondary: #a1a1a1;
--text-muted: #6b6b6b;

/* Accent Colors (matching app status colors) */
--accent-orange: #C15F3C;  /* Working */
--accent-green: #22c55e;   /* Ready/Idle */
--accent-blue: #3b82f6;    /* Needs Input */
--accent-gray: #6b7280;    /* Not Running */

/* Borders */
--border-subtle: rgba(255, 255, 255, 0.1);
```

---

## Page Sections

### 1. Navigation Header (Fixed)

```
┌─────────────────────────────────────────────────────────────────┐
│  [Logo] VibeStatus                              [Download] btn  │
└─────────────────────────────────────────────────────────────────┘
```

**Elements:**
- Logo: Simple icon matching the app icon (rounded square with status indicator)
- App name: "VibeStatus" in bold Inter
- Download button: Primary CTA, links to latest GitHub release
- Subtle backdrop blur effect on scroll

---

### 2. Hero Section

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│              Know When Claude Needs You                         │
│                                                                 │
│     A tiny macOS widget that shows Claude Code's status         │
│        in real-time. Never miss a prompt again.                 │
│                                                                 │
│              [Download for macOS]  [View on GitHub]             │
│                                                                 │
│                    macOS 13+ • Free Forever                     │
│                                                                 │
│                   ┌─────────────────────┐                       │
│                   │   [Hero Screenshot] │                       │
│                   │   Widget + Menu Bar │                       │
│                   └─────────────────────┘                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Content:**
- **Headline**: "Know When Claude Needs You"
- **Subheadline**: "A tiny macOS widget that shows Claude Code's status in real-time. Never miss a prompt again."
- **Primary CTA**: "Download for macOS" (orange accent button)
- **Secondary CTA**: "View on GitHub" (ghost button)
- **Meta text**: "macOS 13+ • Free Forever"
- **Hero image**: Screenshot of the widget on desktop with terminal in background

---

### 3. Problem/Solution Section

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│                    The Vibe Coding Problem                      │
│                                                                 │
│  ┌──────────────────────┐    ┌──────────────────────┐          │
│  │    Without VibeStatus │    │    With VibeStatus   │          │
│  │                       │    │                      │          │
│  │  • Tab back and forth │    │  • Glance at widget  │          │
│  │  • Check terminal     │    │  • See status        │          │
│  │  • Miss prompts       │    │  • Hear notification │          │
│  │  • Lose flow state    │    │  • Stay in flow      │          │
│  │                       │    │                      │          │
│  │    ~30 context        │    │    0 context         │          │
│  │    switches/hour      │    │    switches needed   │          │
│  └──────────────────────┘    └──────────────────────┘          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Content:**
- Two-column comparison (cards with subtle borders)
- Left: Pain points of checking Claude manually
- Right: Benefits of VibeStatus
- Metrics at bottom of each card

---

### 4. Status States Section

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│                   Four States. Zero Guessing.                   │
│                                                                 │
│   ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐          │
│   │ 🟠      │  │ 🟢      │  │ 🔵      │  │ ⚫      │          │
│   │ Working │  │ Ready   │  │ Input   │  │ Offline │          │
│   │         │  │         │  │ Needed  │  │         │          │
│   │ Claude  │  │ Task    │  │ Claude  │  │ Claude  │          │
│   │ is      │  │ done,   │  │ asked   │  │ isn't   │          │
│   │ thinking│  │ check   │  │ you a   │  │ running │          │
│   │         │  │ results │  │ question│  │         │          │
│   └─────────┘  └─────────┘  └─────────┘  └─────────┘          │
│                                                                 │
│              Sound notifications • Pulsing animations           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Content:**
- Four status cards in a row
- Each with colored indicator, status name, and description
- Subtle animation on hover
- Footer note about sound notifications

---

### 5. Features Section

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│                     Built for Vibe Coders                       │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  🖥️ Always Visible Widget                                │   │
│  │  Floating widget stays on top of all windows.           │   │
│  │  Drag it anywhere. Never loses focus.                   │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  📊 Menu Bar Icon                                        │   │
│  │  Minimal footprint. Color-coded status at a glance.     │   │
│  │  Click for quick actions.                               │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  🔔 Custom Sound Alerts                                  │   │
│  │  Choose from 12 system sounds or disable entirely.      │   │
│  │  Different sounds for idle vs input needed.             │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  🖥️ Multi-Terminal Support                               │   │
│  │  Track multiple Claude sessions at once.                │   │
│  │  Aggregated status with session count.                  │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  ⚡ One-Click Setup                                      │   │
│  │  Automatic Claude Code hooks configuration.             │   │
│  │  No terminal commands. No manual config files.          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  🔒 100% Local                                           │   │
│  │  No cloud. No tracking. No data leaves your Mac.        │   │
│  │  Open source on GitHub.                                 │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Content:**
- 6 feature cards in a 2-column grid (3 rows)
- Each with icon, title, and 2-line description
- Subtle hover effect (slight lift + border glow)

---

### 6. Screenshot Gallery

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│                      See It In Action                           │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                                                         │   │
│  │              [Large Screenshot/GIF]                     │   │
│  │              Widget with all 4 states                   │   │
│  │                                                         │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│    [thumb1]    [thumb2]    [thumb3]    [thumb4]                │
│    Working     Ready       Input       Setup                    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Content:**
- Large main screenshot (or animated GIF showing state transitions)
- 4 thumbnail images below (clickable to swap main image)
- Clean browser-style frame around screenshots

---

### 7. How It Works Section

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│                       How It Works                              │
│                                                                 │
│      ①                    ②                    ③               │
│   Download             Click Setup           Start Coding       │
│                                                                 │
│   Get the app          One button            Claude status      │
│   from GitHub          configures            appears in         │
│   releases             everything            your menu bar      │
│                                                                 │
│             ─────────────────────────────────                   │
│                                                                 │
│   Uses Claude Code's hook system to receive status updates.    │
│   No polling. No performance impact. Just works.               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Content:**
- 3-step horizontal flow
- Numbered circles with icons
- Brief description under each
- Technical note at bottom (smaller text)

---

### 8. Pricing Section

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│                    Free. Open Source. Forever.                  │
│                                                                 │
│                  ┌─────────────────────────┐                   │
│                  │                         │                   │
│                  │          $0             │                   │
│                  │                         │                   │
│                  │   ✓ All features        │                   │
│                  │   ✓ Unlimited use       │                   │
│                  │   ✓ No account needed   │                   │
│                  │   ✓ No data collection  │                   │
│                  │   ✓ Open source         │                   │
│                  │                         │                   │
│                  │   [Download Now]        │                   │
│                  │                         │                   │
│                  └─────────────────────────┘                   │
│                                                                 │
│          Built with ❤️ for the vibe coding community            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Content:**
- Single centered card
- Large "$0" price
- Checklist of what's included
- Download CTA button
- Tagline at bottom

---

### 9. FAQ Section

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│                   Frequently Asked Questions                    │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ ▸ Does this work with Claude in the browser?            │   │
│  └─────────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ ▸ Will this slow down my Mac?                           │   │
│  └─────────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ ▸ How do I customize the notification sounds?           │   │
│  └─────────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ ▸ Can I move or resize the widget?                      │   │
│  └─────────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ ▸ Is my data sent anywhere?                             │   │
│  └─────────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ ▸ What happens when I run multiple Claude sessions?     │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**FAQ Content:**

**Q: Does this work with Claude in the browser?**
A: No, VibeStatus is specifically designed for Claude Code (the CLI/terminal version). It uses Claude Code's hook system to receive status updates.

**Q: Will this slow down my Mac?**
A: No. VibeStatus is extremely lightweight (~2MB) and uses virtually no CPU. It simply reads status files that Claude Code writes.

**Q: How do I customize the notification sounds?**
A: Click the gear icon in the menu bar dropdown to access settings. You can choose from 12 different system sounds or disable sounds entirely.

**Q: Can I move or resize the widget?**
A: Yes! The widget can be dragged anywhere on your screen. It automatically stays on top of other windows.

**Q: Is my data sent anywhere?**
A: No. VibeStatus is 100% local. No analytics, no tracking, no network requests. The source code is open on GitHub.

**Q: What happens when I run multiple Claude sessions?**
A: VibeStatus tracks all sessions and shows an aggregated status with the count (e.g., "Working (3)"). If any session needs input, that takes priority.

---

### 10. Footer

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  VibeStatus                                                     │
│                                                                 │
│  Download  •  GitHub  •  Changelog  •  Report Issue             │
│                                                                 │
│  ─────────────────────────────────────────────────────────────  │
│                                                                 │
│  Made for vibe coders who'd rather ship than watch terminals.   │
│                                                                 │
│  © 2025 • Not affiliated with Anthropic                         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Content:**
- App name/logo
- Navigation links
- Tagline
- Copyright + disclaimer

---

## Interactive Elements

### Animations

1. **Hero Screenshot**: Subtle floating animation (translateY oscillation)
2. **Status Cards**: Color pulse on the indicator dots
3. **Feature Cards**: Lift + border glow on hover
4. **Download Button**: Subtle scale on hover
5. **FAQ Items**: Smooth accordion expand/collapse

### Scroll Effects

1. **Navigation**: Backdrop blur increases on scroll
2. **Sections**: Fade-in-up on scroll into view (intersection observer)
3. **Stats/Numbers**: Count-up animation when visible

---

## Responsive Breakpoints

| Breakpoint | Layout Changes |
|------------|----------------|
| Desktop (1024px+) | Full layout, 2-column features |
| Tablet (768px) | Single column features, smaller screenshots |
| Mobile (< 768px) | Stacked layout, hamburger nav, hide some decorative elements |

---

## Assets Needed

1. **App Icon**: High-res PNG (512x512) for hero
2. **Screenshots**:
   - Widget in all 4 states (4 images)
   - Menu bar dropdown
   - Settings panel
   - Full desktop context shot
3. **Animated GIF**: State transitions (optional)
4. **Open Graph Image**: 1200x630 for social sharing
5. **Favicon**: Multiple sizes

---

## SEO & Meta

```html
<title>VibeStatus - Claude Code Status for macOS Menu Bar</title>
<meta name="description" content="A tiny macOS widget that shows Claude Code's real-time status. Never miss a prompt again. Free and open source.">
<meta name="keywords" content="Claude, Claude Code, macOS, menu bar, status, vibe coding, AI coding assistant">

<!-- Open Graph -->
<meta property="og:title" content="VibeStatus - Know When Claude Needs You">
<meta property="og:description" content="A tiny macOS widget for Claude Code status. Free forever.">
<meta property="og:image" content="/og-image.png">
<meta property="og:url" content="https://vibestatus.app">

<!-- Twitter -->
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="VibeStatus - Claude Code Status for macOS">
<meta name="twitter:description" content="Never miss a Claude prompt again.">
<meta name="twitter:image" content="/og-image.png">
```

---

## Download Flow

1. User clicks "Download for macOS"
2. Redirects to GitHub releases (latest)
3. Downloads `VibeStatus.zip`
4. User extracts and drags to Applications
5. First launch: Click "Setup" to configure hooks

---

## Future Considerations

- **Changelog page**: `/changelog` with version history
- **Documentation page**: `/docs` with detailed setup guide
- **Blog**: For updates and vibe coding tips
- **Analytics**: Privacy-respecting (Plausible or Fathom)
