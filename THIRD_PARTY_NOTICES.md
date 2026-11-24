# Third-party notices

Wobbo's own code is MIT licensed ([LICENSE](LICENSE)); its artwork and name are
covered by [ARTWORK.md](ARTWORK.md). The parts below come from others and keep
their own licences. Every release of the app carries the full texts in
`Wobbo.app/Contents/Resources/Licenses/`, written by `tools/release.sh`.

## In the app

| Part | What it is | Licence | Full text |
| --- | --- | --- | --- |
| [Godot Engine](https://godotengine.org) 4.7 | the engine the app runs on, with its own third-party components (FreeType, HarfBuzz, ThorVG, ICU and others) | MIT, components under their own licences | `godot-engine.txt` in the app, written from the engine itself by `godot/tools/godot_notices.gd` |
| [godot-cpp](https://github.com/godotengine/godot-cpp) | C++ bindings compiled into the native extension (`native/godot-cpp`, a git submodule) | MIT, © 2017-present Godot Engine contributors | `native/godot-cpp/LICENSE.md` |
| [Baloo 2](https://github.com/EkType/Baloo2) | the font of the trailer title (`godot/assets/fonts/`) | SIL Open Font License 1.1, © 2019 The Baloo 2 Project Authors | [`godot/assets/fonts/OFL.txt`](godot/assets/fonts/OFL.txt) |
| [Bun](https://bun.com) | the runtime compiled into the `wobbo-bridge` binary | MIT; see [Bun and the LGPL](#bun-and-the-lgpl) | [bun.com/docs/project/licensing](https://bun.com/docs/project/licensing) |
| npm packages | the bridge's runtime dependencies, bundled into `wobbo-bridge` ([list below](#npm-packages-in-the-bridge)) | MIT, ISC, BSD-2-Clause, BSD-3-Clause | `wobbo-bridge-packages.txt` in the app, written by `bridge/scripts/licenses.ts` |

## Only in the repository

| Part | What it is | Licence | Full text |
| --- | --- | --- | --- |
| [godot-ai](https://github.com/hi-godot/godot-ai) 4.4.1 | an editor addon that lets an AI agent drive the Godot editor (`godot/addons/godot_ai/`); left out of every export | MIT, © 2025 Godot AI contributors | [`godot/addons/godot_ai/LICENSE`](godot/addons/godot_ai/LICENSE) |

## Bun and the LGPL

The `wobbo-bridge` binary is made with `bun build --compile`, so it contains the
Bun runtime. Bun is MIT licensed, but statically links JavaScriptCore and WebKit
(GNU Library General Public License, version 2) and tinycc (GNU Lesser General
Public License, version 2.1), plus libraries under permissive licences listed on
[Bun's licensing page](https://bun.com/docs/project/licensing).

To meet the LGPL:
- the licence texts are in [`licenses/LGPL-2.0.txt`](licenses/LGPL-2.0.txt) and
  [`licenses/LGPL-2.1.txt`](licenses/LGPL-2.1.txt), and in the app;
- Bun publishes the source of its JavaScriptCore and WebKit at
  [github.com/oven-sh/webkit](https://github.com/oven-sh/webkit), with
  instructions to build Bun from a changed copy;
- the bridge's own source is in this repository (`bridge/`), so anyone can
  rebuild `wobbo-bridge` with a Bun they built themselves:
  `cd bridge && bun install && bun run build:plugin`.

## npm packages in the bridge

The runtime dependencies of `bridge/` and their dependencies. Regenerate this
table with `bun bridge/scripts/licenses.ts table` after changing
`bridge/package.json`.

| Package | Version | Licence |
| --- | --- | --- |
| @hono/node-server | 2.1.11 | MIT |
| @modelcontextprotocol/sdk | 1.32.2 | MIT |
| accepts | 2.0.0 | MIT |
| ajv | 8.20.0 | MIT |
| ajv-formats | 3.0.1 | MIT |
| body-parser | 2.4.0 | MIT |
| bytes | 3.1.2 | MIT |
| call-bind-apply-helpers | 1.0.2 | MIT |
| call-bound | 1.0.4 | MIT |
| content-disposition | 2.0.1 | MIT |
| content-type | 1.0.5 | MIT |
| content-type | 2.1.0 | MIT |
| cookie | 0.7.2 | MIT |
| cookie-signature | 1.2.2 | MIT |
| cors | 2.8.6 | MIT |
| cross-spawn | 7.0.6 | MIT |
| debug | 4.4.3 | MIT |
| depd | 2.0.0 | MIT |
| dunder-proto | 1.0.1 | MIT |
| ee-first | 1.1.1 | MIT |
| encodeurl | 2.0.3 | MIT |
| es-define-property | 1.0.1 | MIT |
| es-errors | 1.3.0 | MIT |
| es-object-atoms | 1.1.2 | MIT |
| escape-html | 1.0.3 | MIT |
| etag | 1.8.1 | MIT |
| eventsource | 3.0.7 | MIT |
| eventsource-parser | 3.1.1 | MIT |
| express | 5.3.0 | MIT |
| express-rate-limit | 8.7.5 | MIT |
| fast-deep-equal | 3.1.3 | MIT |
| fast-uri | 3.1.9 | BSD-3-Clause |
| finalhandler | 2.1.1 | MIT |
| forwarded | 0.2.0 | MIT |
| fresh | 2.0.0 | MIT |
| function-bind | 1.1.2 | MIT |
| get-intrinsic | 1.3.0 | MIT |
| get-proto | 1.0.1 | MIT |
| gopd | 1.2.0 | MIT |
| has-symbols | 1.1.0 | MIT |
| hasown | 2.0.4 | MIT |
| hono | 4.13.21 | MIT |
| http-errors | 2.0.1 | MIT |
| iconv-lite | 0.7.3 | MIT |
| inherits | 2.0.4 | ISC |
| ip-address | 10.7.6 | MIT |
| ipaddr.js | 1.9.1 | MIT |
| is-promise | 4.0.0 | MIT |
| isexe | 2.0.0 | ISC |
| jose | 6.2.18 | MIT |
| json-schema-traverse | 1.0.0 | MIT |
| json-schema-typed | 8.0.2 | BSD-2-Clause |
| math-intrinsics | 1.1.0 | MIT |
| media-typer | 1.1.1 | MIT |
| merge-descriptors | 2.0.0 | MIT |
| mime-db | 1.54.0 | MIT |
| mime-types | 3.0.2 | MIT |
| ms | 2.1.3 | MIT |
| negotiator | 1.1.0 | MIT |
| object-assign | 4.1.1 | MIT |
| object-inspect | 1.14.0 | MIT |
| on-finished | 2.4.2 | MIT |
| once | 1.4.0 | ISC |
| parseurl | 1.3.3 | MIT |
| path-key | 3.1.1 | MIT |
| path-to-regexp | 8.4.2 | MIT |
| pkce-challenge | 5.0.2 | MIT |
| proxy-addr | 2.0.8 | MIT |
| qs | 6.17.1 | BSD-3-Clause |
| range-parser | 1.3.0 | MIT |
| raw-body | 3.0.2 | MIT |
| require-from-string | 2.0.2 | MIT |
| router | 2.3.0 | MIT |
| safer-buffer | 2.1.2 | MIT |
| send | 1.2.1 | MIT |
| serve-static | 2.2.1 | MIT |
| setprototypeof | 1.2.0 | ISC |
| shebang-command | 2.0.0 | MIT |
| shebang-regex | 3.0.0 | MIT |
| side-channel | 1.1.1 | MIT |
| side-channel-list | 1.0.1 | MIT |
| side-channel-map | 1.0.1 | MIT |
| side-channel-weakmap | 1.0.2 | MIT |
| statuses | 2.0.2 | MIT |
| toidentifier | 1.0.1 | MIT |
| type-is | 2.1.0 | MIT |
| unpipe | 1.0.0 | MIT |
| vary | 1.1.2 | MIT |
| which | 2.0.2 | ISC |
| wrappy | 1.0.2 | ISC |
| zod | 4.6.7 | MIT |
| zod-to-json-schema | 3.25.2 | ISC |
