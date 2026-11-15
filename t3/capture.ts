// Screenshots the installed T3 Code web client with Stillwater themes and synthetic data.
//   npm run t3:capture
//   npm run t3:capture -- --before <theme.json> --after <theme.json> --out <dir>
//
// The page loads the real frontend assets from the local T3 server, then every
// API call and the RPC WebSocket are answered here from t3/capture-fixture.ts.
// The browser never opens a socket to the server and sends no credentials.
import { existsSync, mkdirSync, readFileSync, renameSync } from "node:fs";
import { homedir, tmpdir } from "node:os";
import { basename, dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { chromium, type BrowserContext, type Page, type WebSocketRoute } from "playwright";
import * as fixture from "./capture-fixture.ts";

const ROOT = dirname(dirname(fileURLToPath(import.meta.url)));
const ENVIRONMENT_ID = "fixture-env";
const NOW = Date.parse("2026-11-14T12:00:00.000Z");
const STATIC_PATH = /^\/(assets\/|favicon|apple-touch-icon|manifest\.webmanifest|[\w.-]+\.(?:js|css|woff2?|ttf|png|svg|ico|wasm|webp)$)/;

type Theme = { id: string; file: string; json: Record<string, unknown> };
type Viewport = { name: "desktop" | "phone"; width: number; height: number };
type Json = Record<string, unknown>;

const VIEWPORTS: Viewport[] = [
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
    itemCount: thread.id === fixture.selectedThreadId ? fixture.messages.length : 2,
    visibleItemCount: thread.id === fixture.selectedThreadId ? fixture.messages.length : 2,
    createdAt: at,
    updatedAt: at,
    archivedAt: null,
    settledOverride: null,
    settledAt: null,
    lastVisitedAt: at,
    deletedAt: null,
  };
}

function threadProjection(thread: fixture.FixtureThread): Json {
  const shell = threadShell(thread);
  const at = iso(thread.ageMinutes);
  const messages = fixture.messages.map((message, index) => {
    const created = new Date(NOW - (fixture.messages.length - index) * 60_000 - thread.ageMinutes * 60_000).toISOString();
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
  const visibleTurnItems = turnItems.map((item, position) => ({ position, visibility: "local", sourceThreadId: thread.id, sourceItemId: item.id, item }));
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
    runtimeRequests: [],
    messages,
    plans: [],
    turnItems,
    checkpointScopes: [],
    checkpoints: [],
    contextHandoffs: [],
    contextTransfers: [],
    visibleTurnItems,
    updatedAt: at,
  };
}

// Only the protocol fields of the real descriptor are kept. Its id and label stay on the server.
async function fixtureEnvironment(origin: string) {
  const real = (await (await fetch(`${origin}/.well-known/t3/environment`)).json()) as Json;
  const descriptor = {
    environmentId: ENVIRONMENT_ID,
    label: "Fixture",
    platform: real.platform,
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

async function openContext(env: Environment, theme: Theme, viewport: Viewport, origin: string, traffic: Traffic, video?: string): Promise<BrowserContext> {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    viewport: { width: viewport.width, height: viewport.height },
    deviceScaleFactor: viewport.name === "phone" ? 2 : 1,
    isMobile: viewport.name === "phone",
    hasTouch: viewport.name === "phone",
    colorScheme: "dark",
    serviceWorkers: "block",
    ...(video ? { recordVideo: { dir: video, size: { width: viewport.width, height: viewport.height } } } : {}),
  });
  context.on("close", () => void browser.close());
  await context.route("**/*", async (route) => {
    const request = route.request();
    const url = new URL(request.url());
    const key = `${request.method()} ${url.pathname}`;
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

async function openThread(page: Page, origin: string): Promise<void> {
  await page.goto(`${origin}/${ENVIRONMENT_ID}/${fixture.selectedThreadId}`, { waitUntil: "domcontentloaded" });
  try {
    await page.waitForSelector("[data-user-message-bubble]", { timeout: 20_000 });
  } catch (error) {
    const path = join(tmpdir(), `stillwater-t3-capture-failed-${Date.now()}.png`);
    await page.screenshot({ path });
    throw new Error(`The thread did not render. Page at ${path}.`, { cause: error });
  }
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

// Facts a reviewer compares across themes: shared shadow, kept fill, and who paints the gutter.
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

// --probe <file.js> runs an expression in the loaded thread page and prints the result, for finding selectors.
async function probe(page: Page, file: string): Promise<unknown> {
  return page.evaluate(readFileSync(file, "utf8"));
}

async function openMenu(page: Page): Promise<void> {
  await page.locator("[data-chat-composer-form] button", { hasText: "GPT-5.4" }).click();
  await page.waitForSelector("[data-slot='menu-popup'], [data-slot='popover-popup']", { timeout: 5_000 });
  await page.waitForTimeout(300);
}

// A real pointer drag of a sidebar row onto the composer, held over the drop target.
async function dragRowOverComposer(page: Page): Promise<() => Promise<void>> {
  const row = page.locator("[data-thread-item] > [role='button']").nth(1);
  const target = page.locator("[data-slot='composer-host']");
  const from = await row.boundingBox();
  const to = await target.boundingBox();
  if (!from || !to) throw new Error("The sidebar row or the composer is not on screen.");
  await page.mouse.move(from.x + from.width / 2, from.y + from.height / 2);
  await page.mouse.down();
  await page.mouse.move(to.x + to.width / 2, to.y + to.height / 2, { steps: 12 });
  await page.mouse.move(to.x + to.width / 2 + 6, to.y + to.height / 2, { steps: 2 });
  await page.waitForTimeout(300);
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
  await page.getByText("Search", { exact: true }).first().click({ timeout: 3_000 });
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
  for (const viewport of VIEWPORTS) {
    const context = await openContext(env, theme, viewport, origin, traffic);
    const page = await context.newPage();
    await openThread(page, origin);
    await scrollChatToEnd(page);
    if (viewport.name === "desktop") {
      facts[viewport.name] = await measure(page);
      await shot(page, `${viewport.name}-thread`);
      await clip(page, `${viewport.name}-gutter`, { x: viewport.width - 220, y: viewport.height - 480, width: 220, height: 480 });
      await clip(page, `${viewport.name}-row`, { x: 0, y: 90, width: 260, height: 170 });
      const drop = await dragRowOverComposer(page);
      await clip(page, `${viewport.name}-drag-over`, { x: 360, y: 700, width: 780, height: 200 });
      await drop();
      await focusComposer(page);
      await clip(page, `${viewport.name}-composer-focus`, { x: 360, y: 700, width: 780, height: 200 });
      await openMenu(page);
      await shot(page, `${viewport.name}-menu`);
      await openDialog(page).then(() => shot(page, `${viewport.name}-dialog`), () => { facts.dialog = "no dialog opened from the sidebar search"; });
    } else {
      await shot(page, `${viewport.name}-thread`);
      await openPhoneSidebar(page);
      facts[viewport.name] = await measure(page);
      await shot(page, `${viewport.name}-sidebar`);
    }
    await context.close();
  }
  return { shots, facts };
}

async function record(env: Environment, label: string, theme: Theme, origin: string, out: string, stamp: string, traffic: Traffic): Promise<string> {
  const dir = join(out, `${stamp}-video`);
  const context = await openContext(env, theme, VIEWPORTS[0], origin, traffic, dir);
  const page = await context.newPage();
  await openThread(page, origin);
  await page.mouse.move(800, 450);
  for (const delta of [-900, -900, 900, 900]) {
    await page.mouse.wheel(0, delta);
    await page.waitForTimeout(500);
  }
  await page.locator("[data-thread-item]").nth(2).hover();
  await page.waitForTimeout(600);
  const video = page.video();
  await context.close();
  const path = join(out, `${stamp}-${label}-desktop.webm`);
  if (video) renameSync(await video.path(), path);
  return path;
}

async function main(): Promise<void> {
  const origin = arg("origin") ?? "http://127.0.0.1:3773";
  const out = arg("out") ?? join(tmpdir(), "stillwater-t3-capture");
  const liveBefore = join(homedir(), ".t3", "userdata", "themes", "stillwater-observatory.json");
  const beforeFile = arg("before") ?? (existsSync(liveBefore) ? liveBefore : undefined);
  const after = loadTheme(arg("after") ?? join(ROOT, "t3", "stillwater.json"));
  mkdirSync(out, { recursive: true });
  const stamp = new Date().toISOString().replace(/[-:]/g, "").replace(/\..*/, "");
  const env = await fixtureEnvironment(origin);
  const traffic: Traffic = { fixtures: new Set(), blocked: new Set(), rpc: new Set(), offOrigin: 0 };

  const probeFile = arg("probe");
  if (probeFile) {
    const context = await openContext(env, after, VIEWPORTS[0], origin, traffic);
    const page = await context.newPage();
    await openThread(page, origin);
    await scrollChatToEnd(page);
    console.log(JSON.stringify(await probe(page, probeFile), null, 2));
    await context.close();
    return;
  }

  const runs = [...(beforeFile ? [["before", loadTheme(beforeFile)] as const] : []), ["after", after] as const];
  const report: Record<string, unknown> = { client: env.serverVersion };
  for (const [label, theme] of runs) {
    report[label] = { theme: theme.id, ...(await captureTheme(env, label, theme, origin, out, stamp, traffic)) };
  }
  report.video = await record(env, "after", after, origin, out, stamp, traffic);
  report.traffic = {
    fixtureHttp: [...traffic.fixtures],
    blockedHttp: [...traffic.blocked],
    rpcAnsweredOrIgnored: [...traffic.rpc],
    offOriginAborted: traffic.offOrigin,
    serverSockets: 0,
  };
  console.log(JSON.stringify(report, null, 2));
}

await main();
