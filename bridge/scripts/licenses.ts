// Lists the licences of the bridge's runtime npm packages, which `bun build`
// bundles into the wobbo-bridge binary (open-source-readiness D5).
//
//   bun bridge/scripts/licenses.ts table   a Markdown table for THIRD_PARTY_NOTICES.md
//   bun bridge/scripts/licenses.ts texts   every package's licence text, for the app bundle
//
// Run `bun install` in bridge/ first. Development dependencies are left out.
import { existsSync, readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";

interface Pkg {
  name: string;
  version: string;
  license: string;
  dir: string;
}

const BRIDGE = join(import.meta.dir, "..");

function readPkg(dir: string): Record<string, any> | null {
  const file = join(dir, "package.json");
  return existsSync(file) ? JSON.parse(readFileSync(file, "utf8")) : null;
}

/** Node's lookup: a nested node_modules first, then the top-level one. */
function findDir(name: string, from: string): string | null {
  const nested = join(from, "node_modules", name);
  if (existsSync(join(nested, "package.json"))) return nested;
  const top = join(BRIDGE, "node_modules", name);
  return existsSync(join(top, "package.json")) ? top : null;
}

function runtimePackages(): Pkg[] {
  const found = new Map<string, Pkg>();
  const visit = (name: string, from: string) => {
    const dir = findDir(name, from);
    if (!dir) return;
    const pkg = readPkg(dir)!;
    const key = `${pkg.name}@${pkg.version}`;
    if (found.has(key)) return;
    const license = typeof pkg.license === "string" ? pkg.license : JSON.stringify(pkg.license ?? pkg.licenses ?? "unknown");
    found.set(key, { name: pkg.name, version: pkg.version, license, dir });
    for (const dep of Object.keys(pkg.dependencies ?? {})) visit(dep, dir);
  };
  for (const dep of Object.keys(readPkg(BRIDGE)!.dependencies ?? {})) visit(dep, BRIDGE);
  return [...found.values()].sort((a, b) => a.name.localeCompare(b.name));
}

function licenseText(pkg: Pkg): string {
  const file = readdirSync(pkg.dir).find((f) => /^(licen[cs]e|copying)(\.(md|txt))?$/i.test(f));
  return file ? readFileSync(join(pkg.dir, file), "utf8").trim() : `(No licence file in the package; package.json says ${pkg.license}.)`;
}

const mode = process.argv[2];
const packages = runtimePackages();
if (mode === "table") {
  console.log("| Package | Version | Licence |\n| --- | --- | --- |");
  for (const p of packages) console.log(`| ${p.name} | ${p.version} | ${p.license} |`);
} else if (mode === "texts") {
  for (const p of packages) console.log(`${"=".repeat(72)}\n${p.name} ${p.version} (${p.license})\n${"=".repeat(72)}\n\n${licenseText(p)}\n`);
} else {
  console.error("usage: bun bridge/scripts/licenses.ts table|texts");
  process.exit(2);
}
