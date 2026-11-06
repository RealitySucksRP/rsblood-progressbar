# Third-Party Notices — rsblood-progressbar

This package redistributes the third-party components listed below. Each remains
under its own license, which is reproduced or referenced here as that license
requires. Nothing in `LICENSE.md` restricts your rights under these licenses.

---

## Vue.js 3.5.40

- File: `html/vue.global.prod.js`
- Project: https://github.com/vuejs/core
- Copyright © 2018-present Yuxi (Evan) You and Vue contributors
- License: MIT

Vue is vendored locally on purpose. FiveM's CEF client cannot be relied on to
have outbound internet access, and a blocked CDN fetch leaves `window.Vue`
undefined, which silently disables the NUI.

```
The MIT License (MIT)

Copyright (c) 2018-present, Yuxi (Evan) You

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## keep-progressbar

Parts of this resource's progress engine, NUI protocol, and stage/prop handling
originate from the free community resource **keep-progressbar**.

> **Action required before any paid distribution.** Record the upstream
> repository URL and its license here, and confirm that license permits
> commercial redistribution and, if applicable, escrowed distribution. If the
> upstream license is GPL-family or is missing entirely, this package cannot be
> sold as-is; obtain written permission from the author or replace the derived
> code. See `TEBEX_RELEASE_CHECKLIST.md`.

- Upstream repository: _to be recorded_
- Upstream license: _to be verified_
- Attribution: engine foundation credited to keep-progressbar

---

## Fonts

No webfonts are bundled or fetched. The UI uses a local system-font stack
(`Consolas`, `Courier New`, `Arial Narrow`, `Roboto Condensed`, and generic
fallbacks) so the NUI has no external runtime dependency.
