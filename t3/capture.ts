import assert from "node:assert/strict";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { homedir, tmpdir } from "node:os";
import { basename, dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { chromium, type Browser, type BrowserContext, type Page, type WebSocketRoute } from "playwright";
import * as fixture from "./capture-fixture.ts";

const ROOT = dirname(dirname(fileURLToPath(import.meta.url)));
const ENVIRONMENT_ID = "fixture-env";
const NOW = Date.parse("2026-11-14T12:00:00.000Z");
const STATIC_PATH = /^\/(assets\/|favicon|apple-touch-icon|manifest\.webmanifest|[\w.-]+\.(?:js|css|woff2?|ttf|png|svg|ico|wasm|webp)$)/;

type Theme = { id: string; file: string; json: Record<string, unknown> };
type Viewport = { name: "wide" | "desktop" | "phone"; width: number; height: number };
type Json = Record<string, unknown>;

const VIEWPORTS: Viewport[] = [
  { name: "wide", width: 2000, height: 1258 },
  { name: "desktop", width: 1440, height: 900 },
  { name: "phone", width: 390, height: 844 },
];

function arg(name: string): string | undefined {
  const i = process.argv.indexOf(`--${name}`);
  return i === -1 ? undefined : process.argv[i + 1];
}

function loadTheme(file: string): Theme {
  const json = JSON.parse(readFileSync(file, "utf8")) as Json;
  const id = typeof json.id === "string" ? json.id : basename(file, ".json");
  return { id, file, json };
}

/** The selected thread's messages. `--bench` swaps in a longer list. */
let timeline: fixture.FixtureMessage[] = fixture.messages;

const iso = (minutesAgo: number): string => new Date(NOW - minutesAgo * 60_000).toISOString();

function threadShell(thread: fixture.FixtureThread): Json {
  const at = iso(thread.ageMinutes);
  return {
    id: thread.id,
    projectId: thread.projectId,
    title: thread.title,
    providerInstanceId: "codex",
    modelSelection: { instanceId: "codex", model: "gpt-5.4" },
    runtimeMode: "full-access",
    interactionMode: "default",
    branch: null,
    worktreePath: null,
    activeProviderThreadId: null,
    lineage: { rootThreadId: thread.id, parentThreadId: null, relationshipToParent: null },
    forkedFrom: null,
    createdBy: "user",
    creationSource: "web",
    latestRunId: null,
    activeRunId: null,
    status: "idle",
    pendingRuntimeRequest: null,
    latestVisibleMessage: null,
    latestUserMessageAt: at,
    hasActionableProposedPlan: false,
    itemCount: thread.id === fixture.selectedThreadId ? timeline.length : 2,
    visibleItemCount: thread.id === fixture.selectedThreadId ? timeline.length : 2,
    createdAt: at,
    updatedAt: at,
    archivedAt: null,
    settledOverride: null,
    settledAt: null,
    lastVisitedAt: at,
    deletedAt: null,
    ...shelfFields(thread),
  };
}

function shelfFields(thread: fixture.FixtureThread): Json {
  switch (thread.state) {
    case "working":
      return { status: "running", activeRunId: `${thread.id}-run`, latestRunId: `${thread.id}-run`, activityRunStatus: "running", activityRunStartedAt: iso(thread.ageMinutes) };
    case "pinned":
      return { pinnedAt: iso(thread.ageMinutes) };
    case "snoozed":
      return { snoozedAt: iso(thread.ageMinutes), snoozedUntil: new Date(NOW + 2 * 86_400_000).toISOString() };
    case "settled":
      return { settledOverride: "settled", settledAt: iso(thread.ageMinutes - 1) };
    default:
      return {};
  }
}

function threadProjection(thread: fixture.FixtureThread): Json {
  const shell = threadShell(thread);
  const at = iso(thread.ageMinutes);
  const messages = timeline.map((message, index) => {
    const created = new Date(NOW - (timeline.length - index) * 60_000 - thread.ageMinutes * 60_000).toISOString();
    return {
      id: `${thread.id}-message-${index}`,
      threadId: thread.id,
      runId: null,
      nodeId: null,
      role: message.role,
      text: message.text,
      attachments: [],
      streaming: false,
      createdBy: message.role === "user" ? "user" : "agent",
      creationSource: message.role === "user" ? "web" : "provider",
      createdAt: created,
      updatedAt: created,
    };
  });
  const turnItems = messages.map((message, ordinal) => ({
    id: `${message.id}-item`,
    threadId: thread.id,
    runId: null,
    nodeId: null,
    providerThreadId: null,
    providerTurnId: null,
    nativeItemRef: null,
    parentItemId: null,
    ordinal,
    status: "completed",
    title: null,
    startedAt: message.createdAt,
    completedAt: message.createdAt,
    updatedAt: message.createdAt,
    messageId: message.id,
    text: message.text,
    attachments: [],
    ...(message.role === "user"
      ? { type: "user_message", createdBy: "user", creationSource: "web", inputIntent: "turn_start" }
      : { type: "assistant_message", streaming: false }),
  }));
  const pendingInput = thread.id === fixture.questionThreadId;
  const allTurnItems = [...turnItems, ...(pendingInput ? [{
    ...turnItems.at(-1), id: "fixture-question-item", nodeId: "fixture-question-node",
    type: "user_input_request", requestId: "fixture-question", questions: fixture.questions,
    responseMode: "message",
  }] : [])];
  const visibleTurnItems = allTurnItems.map((item, position) => ({ position, visibility: "local", sourceThreadId: thread.id, sourceItemId: item.id, item }));
  const keys = ["id", "projectId", "title", "providerInstanceId", "modelSelection", "runtimeMode", "interactionMode", "branch", "worktreePath", "activeProviderThreadId", "lineage", "forkedFrom", "createdBy", "creationSource", "createdAt", "updatedAt", "archivedAt", "settledOverride", "settledAt", "lastVisitedAt", "deletedAt"];
  return {
    thread: Object.fromEntries(keys.map((key) => [key, shell[key]])),
    runs: [],
    attempts: [],
    nodes: [],
    subagents: [],
    providerSessions: [],
    providerThreads: [],
    providerTurns: [],
    runtimeRequests: pendingInput ? [{
      id: "fixture-question", nodeId: "fixture-question-node", providerTurnId: null, nativeRequestRef: null,
      kind: "user_input", status: "pending", responseCapability: { type: "message" },
      createdAt: iso(0), resolvedAt: null,
    }] : [],
    messages,
    plans: [],
    turnItems: allTurnItems,
    checkpointScopes: [],
    checkpoints: [],
    contextHandoffs: [],
    contextTransfers: [],
    visibleTurnItems,
    updatedAt: at,
  };
}

async function fixtureEnvironment(origin: string) {
  const real = (await (await fetch(`${origin}/.well-known/t3/environment`)).json()) as Json;
  const descriptor = {
    environmentId: ENVIRONMENT_ID,
    label: "Fixture",
    platform: { os: (real.platform as Json).os, arch: (real.platform as Json).arch },
    serverVersion: real.serverVersion,
    orchestrationProtocolVersion: real.orchestrationProtocolVersion,
    capabilities: real.capabilities,
  };
  const scopes = ["orchestration:read", "orchestration:operate", "settings:write", "providers:manage", "environment:maintain", "preview:operate", "diagnostics:read", "terminal:read", "terminal:operate", "source-control:write", "filesystem:read", "filesystem:write"];
  const auth = { policy: "loopback-browser", bootstrapMethods: ["one-time-token"], sessionMethods: ["browser-session-cookie"], sessionCookieName: "t3_session_fixture" };
  const expiresAt = new Date(Date.now() + 3_600_000).toISOString();
  const projects = fixture.projects.map((project) => ({
    id: project.id,
    title: project.title,
    workspaceRoot: project.root,
    repositoryIdentity: null,
    defaultModelSelection: null,
    scripts: [],
    createdAt: iso(10_000),
    updatedAt: iso(10_000),
  }));
  const shell = { schemaVersion: 1, snapshotSequence: 1, projects, threads: fixture.threads.map(threadShell), archivedThreads: [] };
  const config = {
    environment: descriptor,
    auth,
    cwd: "C:/fixture",
    keybindingsConfigPath: "C:/fixture/keybindings.json",
    keybindings: [],
    issues: [],
    providers: [{ instanceId: "codex", driver: "codex", enabled: true, installed: true, version: "1.0.0", status: "ready", auth: { status: "authenticated" }, checkedAt: iso(5), models: [{ slug: "gpt-5.4", name: "GPT-5.4", isCustom: false, isDefault: true, capabilities: null }] }],
    availableEditors: [],
    observability: { logsDirectoryPath: "C:/fixture/logs", localTracingEnabled: false, otlpTracesEnabled: false, otlpMetricsEnabled: false },
    settings: {},
  };
  const http: Record<string, unknown> = {
    "GET /.well-known/t3/environment": descriptor,
    "GET /api/auth/session": { authenticated: true, auth, scopes, permissions: scopes, sessionMethod: "browser-session-cookie", expiresAt },
    "POST /api/auth/websocket-ticket": { ticket: "fixture-ticket", expiresAt },
    "GET /api/orchestration/shell": shell,
  };
  return { descriptor, config, shell, http, serverVersion: String(real.serverVersion) };
}

type Environment = Awaited<ReturnType<typeof fixtureEnvironment>>;

type Traffic = { fixtures: Set<string>; blocked: Set<string>; rpc: Set<string>; offOrigin: number };

function answerSocket(ws: WebSocketRoute, env: Environment, theme: Theme, traffic: Traffic): void {
  const send = (message: Json) => ws.send(JSON.stringify(message));
  const chunk = (requestId: unknown, values: unknown[]) => send({ _tag: "Chunk", requestId, values });
  ws.onMessage((raw) => {
    const message = JSON.parse(String(raw)) as Json;
    if (message._tag === "Ping") return send({ _tag: "Pong" });
    if (message._tag !== "Request") return;
    const tag = String(message.tag);
    traffic.rpc.add(tag);
    const payload = (message.payload ?? {}) as Json;
    if (tag === "subscribeServerConfig") {
      chunk(message.id, [
        { version: 1, type: "snapshot", config: env.config },
        { version: 1, type: "environmentThemesUpdated", payload: { themes: [{ ...theme.json, id: theme.id }] } },
      ]);
    } else if (tag === "orchestration.subscribeShell") {
      chunk(message.id, [{ kind: "synchronized" }]);
    } else if (tag === "orchestration.subscribeThread") {
      const thread = fixture.threads.find((t) => t.id === payload.threadId);
      if (thread) {
        chunk(message.id, [{ kind: "snapshot", snapshotSequence: 1, projection: threadProjection(thread) }, { kind: "synchronized" }]);
      }
    }
  });
}

async function openContext(browser: Browser, env: Environment, theme: Theme, viewport: Viewport, origin: string, traffic: Traffic, video?: string): Promise<BrowserContext> {
  const context = await browser.newContext({
    viewport: { width: viewport.width, height: viewport.height },
    deviceScaleFactor: viewport.name === "phone" ? 2 : 1,
    isMobile: viewport.name === "phone",
    hasTouch: viewport.name === "phone",
    colorScheme: "dark",
    serviceWorkers: "block",
    ...(video ? { recordVideo: { dir: video, size: { width: viewport.width, height: viewport.height } } } : {}),
  });
  await context.route("**/*", async (route) => {
    const request = route.request();
    const url = new URL(request.url());
    const key = `${request.method()} ${url.pathname}`;
    if (url.href === fixture.skyUrl) {
      traffic.fixtures.add(key);
      return route.fulfill({ contentType: "image/png", body: readFileSync(join(ROOT, "t3", "capture-sky.png")) });
    }
    if (url.origin !== origin) {
      traffic.offOrigin += 1;
      return route.abort();
    }
    if (key in env.http) {
      traffic.fixtures.add(key);
      return route.fulfill({ json: env.http[key] });
    }
    if (request.method() === "GET" && request.resourceType() === "document") {
      return route.fulfill({ response: await route.fetch({ url: `${origin}/`, headers: {} }) });
    }
    if (request.method() === "GET" && STATIC_PATH.test(url.pathname)) {
      return route.fulfill({ response: await route.fetch({ headers: {} }) });
    }
    traffic.blocked.add(key);
    return route.abort();
  });
  await context.routeWebSocket(/.*/, (ws) => answerSocket(ws, env, theme, traffic));
  // Thread ages are relative to NOW, so pin the page clock to it. Timers keep running.
  await context.clock.setFixedTime(NOW);
  await context.addInitScript(
    ({ preferences, themeId }) => {
      localStorage.setItem("t3code:client-settings:v1", JSON.stringify({ ...preferences, onboardingCompletedAt: "2026-01-01T00:00:00.000Z" }));
      localStorage.setItem("t3code:theme", themeId);
      localStorage.setItem("t3code:theme-appearance-mode", "dark");
      localStorage.setItem("t3code:theme-follow-system", "false");
    },
    { preferences: fixture.preferences, themeId: theme.id },
  );
  return context;
}

async function withPage<T>(env: Environment, theme: Theme, viewport: Viewport, origin: string, traffic: Traffic, action: (page: Page) => Promise<T>, video?: string): Promise<T> {
  const browser = await chromium.launch({ headless: true });
  let context: BrowserContext | undefined;
  try {
    context = await openContext(browser, env, theme, viewport, origin, traffic, video);
    const page = await context.newPage();
    const errors: Error[] = [];
    page.on("pageerror", (error) => errors.push(error));
    await openThread(page, origin);
    await scrollChatToEnd(page);
    const result = await action(page);
    assert.equal(errors.length, 0, `Client errors: ${errors.map((error) => error.message).join("; ")}`);
    return result;
  } finally {
    try {
      await context?.close();
    } finally {
      await browser.close();
    }
  }
}

async function openThread(page: Page, origin: string): Promise<void> {
  await page.goto(`${origin}/${ENVIRONMENT_ID}/${fixture.selectedThreadId}`, { waitUntil: "domcontentloaded" });
  try {
    await page.waitForSelector("[data-user-message-bubble]", { timeout: 20_000 });
  } catch (error) {
    const path = join(tmpdir(), `stillwater-t3-capture-failed-${Date.now()}.png`);
    await page.screenshot({ path });
    throw new Error(`The thread did not render. Page at ${path}.`, { cause: error });
  }
  // The Windows desktop app adds this class, which pads #root on the right for the resize grab zone.
  // Headless Chromium never gets it, so add it here or the gutter check misses that lane.
  const inset = await page.evaluate(() => {
    document.documentElement.classList.add("electron-windows");
    return getComputedStyle(document.getElementById("root")!).paddingRight;
  });
  assert(inset !== "0px", "T3 no longer pads #root for .electron-windows. Check the desktop resize inset in apps/web/src/index.css.");
  await page.evaluate(() => document.fonts.ready);
  await page.waitForTimeout(800);
}

async function scrollChatToEnd(page: Page): Promise<void> {
  await page.evaluate(() => {
    const scroller = document.querySelector<HTMLElement>(".messages-timeline-scroll");
    if (scroller) scroller.scrollTop = scroller.scrollHeight;
  });
  await page.waitForTimeout(500);
}

// A string, because tsx wraps named functions in a helper the page does not have.
const MEASURE = `(() => {
  const style = (el) => (el ? getComputedStyle(el) : null);
  const describe = (el) => el.tagName.toLowerCase() + [...el.attributes].filter((a) => a.name.startsWith("data-") || a.name === "aria-current").map((a) => "[" + a.name + "=" + a.value.slice(0, 30) + "]").join("");
  const current = document.querySelector("[data-thread-item] [aria-current='page']");
  const row = current ? current.closest("[data-thread-item]") : null;
  const bubble = document.querySelector("[data-user-message-bubble]");
  const scroller = document.querySelector(".messages-timeline-scroll");
  const box = scroller ? scroller.getBoundingClientRect() : null;
  return {
    theme: document.documentElement.dataset.themeId || null,
    font: style(document.body).fontFamily,
    selectedRow: current ? { element: describe(current), shadow: style(current).boxShadow, rowShadow: style(row).boxShadow, fill: style(current).backgroundColor, radius: style(current).borderRadius } : null,
    bubble: bubble ? { shadow: style(bubble).boxShadow, radius: style(bubble).borderRadius } : null,
    scroller: box ? { scrollbarWidth: scroller.offsetWidth - scroller.clientWidth, gutter: document.elementsFromPoint(box.right - 3, box.bottom - 40).slice(0, 5).map((el) => describe(el) + " " + style(el).backgroundColor + " " + style(el).backgroundImage.slice(0, 30)) } : null,
  };
})()`;

async function measure(page: Page): Promise<unknown> {
  return page.evaluate(MEASURE);
}

async function measureGutter(page: Page, enforce: boolean): Promise<unknown> {
  const png = (await page.screenshot()).toString("base64");
  const facts = await page.evaluate(`(async () => {
    const s = document.querySelector('.messages-timeline-scroll');
    const image = new Image();
    image.src = 'data:image/png;base64,${png}';
    await image.decode();
    const canvas = document.createElement('canvas');
    canvas.width = image.width; canvas.height = image.height;
    const ctx = canvas.getContext('2d'); ctx.drawImage(image, 0, 0);
    const pixel = (x, y) => Array.from(ctx.getImageData(x, y, 1, 1).data).slice(0, 3);
    const samples = [.35, .6, .88, .96].map(fraction => {
      const y = Math.round(innerHeight * fraction);
      const inside = pixel(innerWidth - 36, y), edge = pixel(innerWidth - 1, y);
      return { y, inside, edge, darkening: Math.max(...inside.map((value, i) => value - edge[i])) };
    });
    const styles = ['', '::-webkit-scrollbar', '::-webkit-scrollbar-track', '::-webkit-scrollbar-corner'].map(pseudo => {
      const c = getComputedStyle(s, pseudo || null);
      return { pseudo, background: c.background, clip: c.backgroundClip, mask: c.maskImage };
    });
    return { samples, styles, scrollTop: s.scrollTop, scrollHeight: s.scrollHeight, clientHeight: s.clientHeight };
  })()`) as { samples: Array<{ y: number; darkening: number }> };
  for (const sample of enforce ? facts.samples : []) {
    assert(sample.darkening <= 3, `Gradient stops before the right edge at y=${sample.y}, RGB drop ${sample.darkening}.`);
  }
  return facts;
}

async function probe(page: Page, file: string): Promise<unknown> {
  return page.evaluate(readFileSync(file, "utf8"));
}

async function openMenu(page: Page): Promise<void> {
  await page.locator("[data-chat-composer-form] button", { hasText: "GPT-5.4" }).click();
  await page.waitForSelector("[data-slot='menu-popup'], [data-slot='popover-popup']", { timeout: 5_000 });
  await page.waitForTimeout(300);
}

async function dragRowOverComposer(page: Page): Promise<() => Promise<void>> {
  const row = page.locator(`[data-thread-item="${ENVIRONMENT_ID}:${fixture.threads[1].id}"] > [role='button']`);
  const target = page.locator("[data-slot='composer-host']");
  const from = await row.boundingBox();
  const to = await target.boundingBox();
  if (!from || !to) throw new Error("The sidebar row or the composer is not on screen.");
  await page.mouse.move(from.x + from.width / 2, from.y + from.height / 2);
  await page.mouse.down();
  await page.mouse.move(to.x + to.width / 2, to.y + to.height / 2, { steps: 12 });
  await page.mouse.move(to.x + to.width / 2 + 6, to.y + to.height / 2, { steps: 2 });
  await page.waitForSelector("[data-thread-context-over]", { timeout: 5_000 });
  return async () => {
    await page.mouse.up();
    await page.waitForTimeout(400);
  };
}

async function focusComposer(page: Page): Promise<void> {
  await page.locator("[data-chat-composer-form] [contenteditable='true']").first().click();
  await page.keyboard.type("Fixture draft");
  await page.waitForTimeout(300);
}

async function openDialog(page: Page): Promise<void> {
  await page.keyboard.press("Escape");
  await page.keyboard.press("Escape");
  await page.getByRole("button", { name: "Settings", exact: true }).click({ timeout: 3_000 });
  await page.waitForSelector("[data-slot='dialog-popup']", { timeout: 5_000 });
  await page.waitForTimeout(300);
}

async function openPhoneSidebar(page: Page): Promise<void> {
  await page.locator("[data-sidebar='trigger'], button[aria-label*='sidebar' i]").first().click();
  await page.waitForSelector("[data-thread-item] [aria-current='page']", { state: "visible", timeout: 5_000 });
  await page.waitForTimeout(400);
}

async function captureTheme(env: Environment, label: string, theme: Theme, origin: string, out: string, stamp: string, traffic: Traffic) {
  const shots: string[] = [];
  const facts: Record<string, unknown> = {};
  const shot = async (page: Page, name: string) => {
    const path = join(out, `${stamp}-${label}-${name}.png`);
    await page.screenshot({ path });
    shots.push(path);
  };
  const clip = async (page: Page, name: string, area: { x: number; y: number; width: number; height: number }) => {
    const path = join(out, `${stamp}-${label}-${name}.png`);
    await page.screenshot({ path, clip: area });
    shots.push(path);
  };
  const composerShot = async (page: Page, name: string) => {
    const box = await page.locator("[data-slot='composer-host']").boundingBox();
    assert(box, "Composer must be visible for capture.");
    await clip(page, name, { x: Math.max(0, box.x - 20), y: Math.max(0, box.y - 50), width: box.width + 40, height: box.height + 60 });
  };
  for (const viewport of VIEWPORTS) {
    await withPage(env, theme, viewport, origin, traffic, async (page) => {
      if (viewport.name !== "phone") {
        facts[viewport.name] = await measure(page);
        if (label === "after") {
          assert(await page.evaluate(() => {
            const row = document.querySelector("[data-thread-item] [aria-current='page']");
            const bubble = document.querySelector("[data-user-message-bubble]");
            return row && bubble && getComputedStyle(bubble).boxShadow !== "none" && getComputedStyle(row).boxShadow.endsWith(getComputedStyle(bubble).boxShadow);
          }), "Selected row must retain the user bubble's glass shadow.");
        }
        await shot(page, `${viewport.name}-thread`);
        facts[`${viewport.name}-gutter-end`] = await measureGutter(page, label === "after");
        await clip(page, `${viewport.name}-gutter`, { x: viewport.width - 220, y: viewport.height - 480, width: 220, height: 480 });
        await page.evaluate(() => {
          const scroller = document.querySelector<HTMLElement>(".messages-timeline-scroll")!;
          scroller.scrollTop = (scroller.scrollHeight - scroller.clientHeight) / 2;
        });
        await page.waitForTimeout(400);
        await page.mouse.move(viewport.width - 3, viewport.height - 100);
        await page.mouse.wheel(0, 1);
        await shot(page, `${viewport.name}-scroll-middle`);
        facts[`${viewport.name}-gutter-middle`] = await measureGutter(page, label === "after");
        await scrollChatToEnd(page);
        const rowBox = await page.locator("[data-thread-item]:has([aria-current='page'])").boundingBox();
        assert(rowBox, "The selected sidebar row is not on screen.");
        await clip(page, `${viewport.name}-row`, { x: 0, y: Math.max(0, rowBox.y - 60), width: 260, height: 170 });
        await page.locator(".chat-markdown img").last().click();
        const lightbox = page.locator("[data-slot='dialog-popup']");
        await lightbox.waitFor({ state: "visible", timeout: 5_000 });
        await page.waitForTimeout(400);
        await shot(page, `${viewport.name}-lightbox`);
        if (label === "after") {
          const fill = await lightbox.evaluate((el) => getComputedStyle(el).backgroundColor);
          assert.equal(fill, "rgba(0, 0, 0, 0)", "The image lightbox must stay transparent. Scope dialog sheet rules to .dialog-glass.");
        }
        await page.keyboard.press("Escape");
        await lightbox.waitFor({ state: "detached", timeout: 5_000 });
        const drop = await dragRowOverComposer(page);
        await composerShot(page, `${viewport.name}-drag-over`);
        await drop();
        const mention = page.locator("[data-chat-composer-form]").getByText(fixture.threads[1].title, { exact: true });
        await mention.hover({ timeout: 5_000 });
        await page.locator("[data-slot='tooltip-popup']").waitFor({ state: "visible", timeout: 5_000 });
        await composerShot(page, `${viewport.name}-mention-tooltip`);
        await page.locator("[data-chat-header]").click();
        const unfocusedBorder = await page.locator("[data-slot='composer-host']").evaluate((el) => getComputedStyle(el).borderColor);
        await focusComposer(page);
        assert(await page.locator("[data-slot='composer-host']").evaluate((el) => el.matches(":focus-within")), "Composer must receive keyboard focus.");
        const focusedBorder = await page.locator("[data-slot='composer-host']").evaluate((el) => getComputedStyle(el).borderColor);
        assert.notEqual(focusedBorder, unfocusedBorder, "Focus must change the composer's border.");
        await composerShot(page, `${viewport.name}-composer-focus`);
        await openMenu(page);
        await shot(page, `${viewport.name}-menu`);
        await openDialog(page);
        await shot(page, `${viewport.name}-dialog`);
        await page.keyboard.press("Escape");
        await page.goto(`${origin}/${ENVIRONMENT_ID}/${fixture.questionThreadId}`, { waitUntil: "domcontentloaded" });
        await page.locator("[data-pending-user-input-toggle]").waitFor({ state: "visible", timeout: 10_000 });
        await page.locator("[data-chat-header]").click();
        const questionSurface = page.locator("[data-chat-composer-main-surface]");
        const questionBorder = await questionSurface.evaluate((el) => getComputedStyle(el, "::after").borderColor);
        await page.locator("[data-chat-composer-form] [contenteditable='true']").first().click();
        await composerShot(page, `${viewport.name}-question`);
        if (label === "after") {
          assert(await page.locator("[data-slot='composer-host']").evaluate((el) => getComputedStyle(el).borderColor === "rgba(0, 0, 0, 0)"), "Questions must not draw the extra outer frame.");
          assert.notEqual(await questionSurface.evaluate((el) => getComputedStyle(el, "::after").borderColor), questionBorder, "The question answer input must retain focus feedback.");
        }
      } else {
        await shot(page, `${viewport.name}-thread`);
        await openPhoneSidebar(page);
        facts[viewport.name] = await measure(page);
        await shot(page, `${viewport.name}-sidebar`);
      }
    });
  }
  return { shots, facts };
}

async function record(env: Environment, label: string, theme: Theme, origin: string, out: string, stamp: string, traffic: Traffic): Promise<string> {
  const dir = join(out, `${stamp}-video`);
  const path = join(out, `${stamp}-${label}-desktop.webm`);
  return withPage(env, theme, VIEWPORTS[0], origin, traffic, async (page) => {
    await page.mouse.move(800, 450);
    for (const delta of [-900, -900, 900, 900]) {
      await page.mouse.wheel(0, delta);
      await page.waitForTimeout(500);
    }
    await page.locator("[data-thread-item]").nth(2).hover();
    await page.waitForTimeout(600);
    const video = page.video();
    assert(video, "Recording must be enabled for the capture page.");
    await page.close();
    await video.saveAs(path);
    return path;
  }, dir);
}

// Swaps the theme's adopted stylesheet in place, the way a theme switch does, then scrolls the
// timeline top to bottom and reads Chromium's style and layout counters for that scroll alone.
const SCROLL = `(async ({ step, frames }) => {
  const s = document.querySelector(".messages-timeline-scroll");
  const frame = () => new Promise((resolve) => requestAnimationFrame(resolve));
  const gaps = [];
  let last = await frame();
  for (let i = 0; i < frames; i++) {
    s.scrollTop += step;
    const now = await frame();
    gaps.push(now - last);
    last = now;
  }
  return { gaps, scrollTop: s.scrollTop, scrollHeight: s.scrollHeight };
})`;

// Stillwater measures about 1.08x and one `div:has(:hover)` rule pushes it to 1.27x, so 1.2x catches a rule like that.
const BENCH_LIMIT = 1.2;

type Stage = { stage: string; recalcMs: number; recalcCount: number; layoutMs: number; frameP95Ms: number; runs: number[] };

const median = (values: number[]): number => [...values].sort((a, b) => a - b)[Math.floor(values.length / 2)];

async function bench(env: Environment, theme: Theme, origin: string, out: string, stamp: string, traffic: Traffic): Promise<void> {
  const messages = Number(arg("messages") ?? 400);
  const reps = Number(arg("reps") ?? 5);
  const step = 45;
  const frames = 120;
  // Cycle the text-only pairs; the last pair carries the sky image.
  timeline = Array.from({ length: messages }, (_, i) => fixture.messages[i % (fixture.messages.length - 2)]);
  const full = String(theme.json.css ?? "");
  const seed = ":root { --stillwater-bench: 0; }";
  const baseTheme: Theme = { ...theme, json: { ...theme.json, css: seed } };
  const viewport = VIEWPORTS[1];
  // "switch" loads the theme and removes it again in one session, the sequence that left T3 Clawd's
  // style cost behind after a theme switch. "no-has" is the same theme without its :has() rules.
  const sessions: Array<{ name: string; stages: Array<"base" | "theme" | "no-has"> }> = [
    { name: "switch", stages: ["base", "base", "theme", "base", "theme", "base"] },
    { name: "no-has", stages: ["base", "no-has", "base", "no-has", "base"] },
  ];
  const report: Record<string, Stage[]> = {};
  for (const session of sessions) {
    report[session.name] = await withPage(env, baseTheme, viewport, origin, traffic, async (page) => {
      const cdp = await page.context().newCDPSession(page);
      await cdp.send("Performance.enable");
      const metrics = async () => Object.fromEntries(((await cdp.send("Performance.getMetrics")).metrics).map((m) => [m.name, m.value]));
      const css = await page.evaluate(({ full, seed }) => {
        const sheet = document.adoptedStyleSheets.find((s) => [...s.cssRules].some((r) => r.cssText.includes("--stillwater-bench")));
        if (!sheet) throw new Error("No adopted theme stylesheet. T3 changed how it applies theme CSS.");
        const probe = new CSSStyleSheet();
        probe.replaceSync(full);
        const noHas = [...probe.cssRules].map((r) => r.cssText).filter((text) => !text.includes(":has(")).join("\n");
        (window as unknown as { __benchSheet: CSSStyleSheet }).__benchSheet = sheet;
        return { base: seed, theme: full, "no-has": noHas };
      }, { full, seed });
      const stages: Stage[] = [];
      for (const name of session.stages) {
        await page.evaluate((text) => (window as unknown as { __benchSheet: CSSStyleSheet }).__benchSheet.replaceSync(text), css[name]);
        await page.waitForTimeout(300);
        const runs: Array<{ recalc: number; count: number; layout: number; p95: number }> = [];
        for (let rep = 0; rep < reps; rep++) {
          const box = await page.evaluate(() => {
            const scroller = document.querySelector<HTMLElement>(".messages-timeline-scroll")!;
            scroller.scrollTop = 0;
            const { x, y, width, height } = scroller.getBoundingClientRect();
            return { x: x + width / 2, y: y + height / 2 };
          });
          // The cursor rests on the timeline, as it does under a wheel scroll, so hover moves with the content.
          await page.mouse.move(box.x, box.y);
          await page.waitForTimeout(400);
          const before = await metrics();
          const scroll = (await page.evaluate(`${SCROLL}(${JSON.stringify({ step, frames })})`)) as { gaps: number[]; scrollTop: number; scrollHeight: number };
          const after = await metrics();
          assert(scroll.scrollTop >= step * frames * 0.95, `Timeline too short to scroll ${step * frames}px: reached ${scroll.scrollTop} of ${scroll.scrollHeight}.`);
          const gaps = [...scroll.gaps].sort((a, b) => a - b);
          runs.push({
            recalc: (after.RecalcStyleDuration - before.RecalcStyleDuration) * 1000,
            count: after.RecalcStyleCount - before.RecalcStyleCount,
            layout: (after.LayoutDuration - before.LayoutDuration) * 1000,
            p95: gaps[Math.floor(gaps.length * 0.95)],
          });
        }
        const stage = {
          stage: name,
          recalcMs: +median(runs.map((r) => r.recalc)).toFixed(1),
          recalcCount: median(runs.map((r) => r.count)),
          layoutMs: +median(runs.map((r) => r.layout)).toFixed(1),
          frameP95Ms: +median(runs.map((r) => r.p95)).toFixed(1),
          runs: runs.map((r) => +r.recalc.toFixed(1)),
        };
        stages.push(stage);
        console.log(`${session.name.padEnd(7)} ${name.padEnd(11)} recalc ${String(stage.recalcMs).padStart(6)} ms (${stage.recalcCount} recalcs)  layout ${String(stage.layoutMs).padStart(6)} ms  frame p95 ${stage.frameP95Ms} ms  runs ${stage.runs.join(" ")}`);
      }
      return stages;
    });
  }
  const [, base, themed, after] = report.switch.map((stage) => stage.recalcMs);
  const verdict = { themeOverBase: +(themed / base).toFixed(2), afterSwitchOverBase: +(after / base).toFixed(2), limit: BENCH_LIMIT };
  const path = join(out, `${stamp}-bench.json`);
  writeFileSync(path, `${JSON.stringify({ client: env.serverVersion, theme: theme.file, messages, reps, scrollPx: step * frames, viewport, verdict, report }, null, 2)}\n`);
  console.log(`Theme ${verdict.themeOverBase}x base, ${verdict.afterSwitchOverBase}x after switching away. Bench report: ${path}`);
  assert(verdict.themeOverBase <= BENCH_LIMIT, `The theme makes scroll style recalc ${verdict.themeOverBase}x the base. Look for :has() or [class*=] rules that match timeline rows.`);
  assert(verdict.afterSwitchOverBase <= BENCH_LIMIT, `Style recalc stays at ${verdict.afterSwitchOverBase}x the base after the theme is removed.`);
}

async function main(): Promise<void> {
  const origin = arg("origin") ?? "http://127.0.0.1:3773";
  const out = arg("out") ?? join(tmpdir(), "stillwater-t3-capture");
  const liveBefore = join(homedir(), ".t3", "userdata", "themes", "stillwater.json");
  const beforeFile = arg("before") ?? (existsSync(liveBefore) ? liveBefore : undefined);
  const after = loadTheme(arg("after") ?? join(ROOT, "t3", "stillwater.json"));
  mkdirSync(out, { recursive: true });
  const stamp = new Date().toISOString().replace(/[-:]/g, "").replace(/\..*/, "");
  const env = await fixtureEnvironment(origin);
  const traffic: Traffic = { fixtures: new Set(), blocked: new Set(), rpc: new Set(), offOrigin: 0 };

  const probeFile = arg("probe");
  if (probeFile) {
    await withPage(env, after, VIEWPORTS[0], origin, traffic, async (page) => {
      console.log(JSON.stringify(await probe(page, probeFile), null, 2));
      await page.mouse.move(VIEWPORTS[0].width - 3, VIEWPORTS[0].height - 100);
      await page.mouse.wheel(0, 1);
      await page.screenshot({ path: join(out, `${stamp}-probe.png`) });
    });
    return;
  }

  if (process.argv.includes("--bench")) {
    await bench(env, after, origin, out, stamp, traffic);
    return;
  }

  const showcase = arg("showcase");
  if (showcase) {
    await withPage(env, after, VIEWPORTS[0], origin, traffic, async (page) => {
      await page.evaluate((layout) => {
        for (const [key, value] of Object.entries(layout)) localStorage.setItem(key, value);
      }, fixture.showcaseLayout);
      await page.reload({ waitUntil: "domcontentloaded" });
      await page.waitForSelector("[data-user-message-bubble]", { timeout: 20_000 });
      await page.evaluate(() => document.fonts.ready);
      await scrollChatToEnd(page);
      await page.mouse.move(VIEWPORTS[0].width / 2, VIEWPORTS[0].height / 2);
      await page.screenshot({ path: showcase });
    });
    console.log(`wrote ${showcase}`);
    return;
  }

  const runs = [...(beforeFile ? [["before", loadTheme(beforeFile)] as const] : []), ["after", after] as const];
  const report: Record<string, unknown> = { client: env.serverVersion };
  for (const [label, theme] of runs) {
    report[label] = { theme: theme.id, ...(await captureTheme(env, label, theme, origin, out, stamp, traffic)) };
  }
  const rowFill = (label: string, viewport: string) => {
    const run = report[label] as { facts: Record<string, { selectedRow: { fill: string } }> } | undefined;
    return run?.facts[viewport]?.selectedRow?.fill;
  };
  if (report.before) {
    for (const viewport of VIEWPORTS) {
      assert.equal(rowFill("before", viewport.name), rowFill("after", viewport.name), "Theme must preserve the selected row's active fill.");
    }
  }
  report.video = await record(env, "after", after, origin, out, stamp, traffic);
  report.traffic = {
    fixtureHttp: [...traffic.fixtures],
    blockedHttp: [...traffic.blocked],
    rpcAnsweredOrIgnored: [...traffic.rpc],
    offOriginAborted: traffic.offOrigin,
    serverSockets: 0,
  };
  const reportPath = join(out, `${stamp}-report.json`);
  writeFileSync(reportPath, `${JSON.stringify(report, null, 2)}\n`);
  console.log(`Captured ${env.serverVersion}. Report: ${reportPath}`);
}

await main();
