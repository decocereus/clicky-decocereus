# Clicky Marketing Site Design

## Brand Foundation

**Product**: Clicky - An AI companion that lives next to your cursor on macOS
**Tagline**: "An AI teacher that lives as a buddy next to your cursor"
**Core Value**: Instant voice-controlled AI assistance with screen awareness and visual guidance

## Color System

### Primary Palette (from mac app - keeping it consistent)
- **Background**: `#121212` (deep dark)
- **Surface**: `#1F1F1F` (elevated cards)
- **Primary Accent**: `#53CFAF` (mint/teal)
- **Secondary Accent**: `#7A5EFF` (purple - for light mode)
- **Text Primary**: `#FBF8F5` (warm white)
- **Text Secondary**: `#ADB5B2` (muted gray)
- **Text Tertiary**: `#6B736F` (subtle)
- **Success**: `#34D399` (emerald)
- **Glow Colors**: `#0F2C26`, `#172120` (aura effects)

### Gradients
- **Hero Glow**: Radial from `#53CFAF` at 20% opacity to transparent
- **Card Surface**: Linear from `#1F1F1F` to `#171918`
- **CTA Button**: Linear from `#53CFAF` to `#3DB894`

## Typography

- **Display**: Playfair Display (serif) - for headlines
- **Body**: Poppins (sans) - for UI text
- **Mono**: JetBrains Mono - for code/labels

## Site Structure

### 1. Hero Section (Full viewport)
- **Headline**: "An AI companion that lives next to your cursor"
- **Subhead**: "Push-to-talk voice control. Sees your screen. Points to guide you. Like having a teacher right next to you."
- **CTA**: "Download for Mac" (prominent button)
- **Secondary**: "Free to try · macOS 14.2+"
- **Visual**: Interactive demo showing Clicky cursor flying around

### 2. Live Demo Section
- Simulated macOS desktop environment
- Clicky cursor demonstrates:
  - Push-to-talk interaction
  - Screen capture visualization
  - Pointing to UI elements
  - Voice wave visualization
- Interactive: User can click to trigger demo sequences

### 3. Features Grid (3 features)
1. **Push to Talk** - "Hold Ctrl+Option. Speak naturally. No wake words."
2. **See Everything** - "Clicky captures your screen to understand context."
3. **Point & Guide** - "The blue cursor flies to UI elements to show you where to click."

### 4. How It Works (3 steps)
1. Press Ctrl+Option to talk
2. Clicky sees your screen and understands
3. Get voice guidance with visual pointing

### 5. Use Cases
- Learning new software
- Coding assistance
- Design tool guidance
- General troubleshooting

### 6. Social Proof
- Twitter/X testimonials
- GitHub stars count
- Usage stats

### 7. Final CTA
- "Ready to meet your companion?"
- Download button
- Open source link

## Micro-interactions

### Buttons
- Hover: Scale 1.02, glow shadow appears
- Press: Scale 0.98
- Primary button: Breathing glow animation when idle

### Cards
- Hover: Subtle lift (translateY -2px), enhanced shadow
- Border: Gradient shimmer on hover

### Cursor (Clicky)
- Idle: Gentle floating animation
- Moving: Arc trajectory with rotation following path
- Speaking: Pulsing glow, speech bubble appears
- Listening: Waveform visualization around cursor

### Scroll Triggers
- Elements fade in + translateY as they enter viewport
- Staggered timing for lists/grids
- Parallax on hero background

## Animation Specs

### Timing Functions
- **Default**: `cubic-bezier(0.23, 1, 0.32, 1)` (easeOutExpo)
- **Bounce**: `cubic-bezier(0.34, 1.56, 0.64, 1)`
- **Smooth**: `cubic-bezier(0.4, 0, 0.2, 1)`

### Durations
- **Fast**: 150ms (hover states)
- **Normal**: 300ms (transitions)
- **Slow**: 500ms (page transitions)
- **Dramatic**: 800ms (hero animations)

## Interactive Demo Sequence

1. **Intro** (0-3s)
   - Clicky flies in from bottom-right
   - "hey! i'm clicky ✨" bubble appears
   - Floats near center

2. **Push-to-Talk Demo** (3-8s)
   - Visual: Key combo "Ctrl+Option" appears
   - Waveform animates around cursor
   - "ask me anything..." bubble

3. **Screen Capture** (8-13s)
   - Flash effect on simulated screen
   - Screen content "analyzes" with scan effect
   - "i can see what you're working on"

4. **Pointing Demo** (13-18s)
   - Clicky flies to mock UI element
   - Circle highlight appears on target
   - "click right here!"

5. **CTA** (18s+)
   - Returns to center
   - "download me and let's work together!"
   - Pulse animation on download button

## Technical Implementation

- React + TypeScript + Vite
- Tailwind CSS for styling
- Framer Motion for animations
- Canvas/WebGL for waveform effects (optional)
- Lucide icons

## Responsive Breakpoints

- **Mobile**: < 640px - Stack layout, simplified demo
- **Tablet**: 640px - 1024px - 2-column grids
- **Desktop**: > 1024px - Full experience
