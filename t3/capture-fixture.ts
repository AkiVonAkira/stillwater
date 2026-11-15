// Synthetic data for t3/capture.ts. Nothing here comes from a real T3 install.

export type FixtureProject = { id: string; title: string; root: string };

export type FixtureThread = {
  id: string;
  projectId: string;
  title: string;
  ageMinutes: number;
};

export type FixtureMessage = { role: "user" | "assistant"; text: string };

// The owner's client settings, written to the same localStorage key the app uses.
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
];

export const threads: FixtureThread[] = [
  { id: "thread-row", projectId: "project-glass", title: "Match the row shadow to the bubble", ageMinutes: 4 },
  { id: "thread-header", projectId: "project-glass", title: "Header gradient behind the scroller", ageMinutes: 40 },
  { id: "thread-dialog", projectId: "project-tide", title: "Dialog corner radius", ageMinutes: 180 },
  { id: "thread-menu", projectId: "project-tide", title: "Menu glass opacity", ageMinutes: 600 },
  { id: "thread-fonts", projectId: "project-glass", title: "Mono font in the composer", ageMinutes: 1500 },
];

// The thread the capture opens. Long enough that the chat scroller shows a scrollbar.
export const selectedThreadId = "thread-row";

const answer = (n: number): string =>
  [
    `Step ${n}. The selected row and the user bubble share one shadow token.`,
    "The bubble keeps its glass fill, and the row keeps the accent fill. Only the shadow is shared, so neighbors stay flat.",
    "```css\n[data-thread-item] {\n  border-radius: 8px;\n}\n```",
  ].join("\n\n");

export const messages: FixtureMessage[] = Array.from({ length: 10 }, (_, n) => [
  { role: "user" as const, text: `Check ${n + 1}: does the selected row read as glass next to this bubble?` },
  { role: "assistant" as const, text: answer(n + 1) },
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
