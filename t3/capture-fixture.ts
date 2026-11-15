export type FixtureProject = { id: string; title: string; root: string };

export type FixtureThread = {
  id: string;
  projectId: string;
  title: string;
  ageMinutes: number;
  /** Puts the row on the sidebar's Working, Snoozed, or Settled shelf, or pins it to the top. */
  state?: "working" | "pinned" | "snoozed" | "settled";
};

export type FixtureMessage = { role: "user" | "assistant"; text: string };

export type FixturePreferences = {
  fontFamilySans: string;
  fontFamilyCode: string;
  fontFamilyComposer: string;
  fontFamilyTerminal: string;
  fontSizeInterface: number;
  fontSizePrompt: number;
  fontSizeCode: number;
  fontSizeTerminal: number;
  fontSmoothing: boolean;
  appearanceContrast: number;
  glassOpacity: number;
  chatWidth: "comfortable";
  boringSidebarEnabled: boolean;
  boringSidebarMultilineRows: boolean;
  sidebarWorkingShelfEnabled: boolean;
  sidebarProjectGroupingMode: "repository";
};

export const projects: FixtureProject[] = [
  { id: "project-glass", title: "glass-panels", root: "C:/fixture/glass-panels" },
  { id: "project-tide", title: "tide-tables", root: "C:/fixture/tide-tables" },
  { id: "project-harbor", title: "harbor-lights", root: "C:/fixture/harbor-lights" },
  { id: "project-sky", title: "night-sky", root: "C:/fixture/night-sky" },
];

export const threads: FixtureThread[] = [
  { id: "thread-row", projectId: "project-glass", title: "Match the row shadow to the bubble", ageMinutes: 4 },
  { id: "thread-header", projectId: "project-glass", title: "Header gradient behind the scroller", ageMinutes: 40 },
  { id: "thread-dialog", projectId: "project-tide", title: "Dialog corner radius", ageMinutes: 180 },
  { id: "thread-menu", projectId: "project-tide", title: "Menu glass opacity", ageMinutes: 600 },
  { id: "thread-fonts", projectId: "project-glass", title: "Mono font in the composer", ageMinutes: 1500 },
  { id: "thread-question", projectId: "project-glass", title: "Choose the observation details", ageMinutes: 1600 },
  { id: "thread-deck", projectId: "project-harbor", title: "Sketch the observation deck layout", ageMinutes: 90, state: "pinned" },
  { id: "thread-lantern", projectId: "project-harbor", title: "Lantern fade timing", ageMinutes: 300 },
  { id: "thread-chart", projectId: "project-sky", title: "Render the star chart at dusk", ageMinutes: 2, state: "working" },
  { id: "thread-gauge", projectId: "project-tide", title: "Calibrate the tide gauge readings", ageMinutes: 25, state: "working" },
  { id: "thread-beacon", projectId: "project-harbor", title: "Beacon sweep and keybinds", ageMinutes: 2900, state: "snoozed" },
  { id: "thread-moon", projectId: "project-sky", title: "Moon phase icons", ageMinutes: 4300, state: "settled" },
  { id: "thread-swell", projectId: "project-tide", title: "Swell height legend", ageMinutes: 5800, state: "settled" },
];

/** Local storage for `--showcase`: a wide sidebar with the Working and Snoozed shelves open. */
export const showcaseLayout: Record<string, string> = {
  chat_thread_sidebar_width: "404",
  "t3code:sidebar:working-expanded": "true",
  "t3code:sidebar:snoozed-expanded": "true",
};

export const selectedThreadId = "thread-row";
export const questionThreadId = "thread-question";

export const questions = [{
  id: "detail", header: "Details", question: "How much detail should the observation cards show?",
  options: [
    { label: "Keep it compact", description: "Show the next observation and current conditions." },
    { label: "Show more", description: "Include the full list of observation details." },
  ],
  allowCustomAnswer: true,
  multiSelect: false,
}];

const answers: Array<(n: number) => string[]> = [
  (n) => [
    `Step ${n}. The selected row and the user bubble share one shadow token.`,
    "The bubble keeps its glass fill, and the row keeps the accent fill. Only the shadow is shared, so neighbors stay flat.",
    "```css\n[data-thread-item] {\n  border-radius: 8px;\n}\n```",
  ],
  (n) => [
    `Step ${n}. The tide chart now reads the gauge every \`15 min\` instead of every hour.`,
    "- **Readings:** `tide-tables/gauge.ts` keeps the last 96 samples, one day.",
    "- **Legend:** swell height uses the warm ink, so it stays readable on the dark canvas.",
    "- **Not checked:** the harbor feed on a slow connection.",
  ],
  (n) => [
    `Step ${n}. **Deck layout:** the observation cards sit on one 12px grid, and the lantern row fades over \`400 ms\`.`,
    "**Proof:** captured at 2000 by 1258 and 390 by 844, before and after, with the same fixture sky.",
  ],
];

const answer = (n: number): string => answers[n % answers.length]!(n).join("\n\n");

/** The last reply shows this made-up sky, so a click opens T3's image lightbox. T3 drops `data:`
    image URLs, so capture serves `capture-sky.png` at this address. */
export const skyUrl = "https://fixture.invalid/sky.png";

export const messages: FixtureMessage[] = Array.from({ length: 10 }, (_, n) => [
  { role: "user" as const, text: `Check ${n + 1}: does the selected row read as glass next to this bubble?` },
  { role: "assistant" as const, text: n === 9 ? `${answer(n + 1)}\n\n![Fixture sky at dusk](${skyUrl})` : answer(n + 1) },
]).flat();

export const preferences: FixturePreferences = {
  fontFamilySans: "CaskaydiaMono Nerd Font",
  fontFamilyCode: "CaskaydiaMono Nerd Font Mono",
  fontFamilyComposer: "",
  fontFamilyTerminal: "",
  fontSizeInterface: 16,
  fontSizePrompt: 14,
  fontSizeCode: 13,
  fontSizeTerminal: 12,
  fontSmoothing: true,
  appearanceContrast: 100,
  glassOpacity: 80,
  chatWidth: "comfortable",
  boringSidebarEnabled: false,
  boringSidebarMultilineRows: true,
  sidebarWorkingShelfEnabled: true,
  sidebarProjectGroupingMode: "repository",
};
