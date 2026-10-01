# Model list

Adopted from OpenResponses on 2026-10-01, at Gunnar's request, so that both apps offer the same models with the
same settings. OpenCone carries a copy of OpenResponses' built-in list and the code that reads it (ported files name
their source at the top). Keep the two copies in step: when OpenResponses changes its list, copy
`OpenResponses/Resources/ModelCatalog/ModelCatalog.json` over `OpenCone/Resources/ModelCatalog/ModelCatalog.json`,
keeping OpenCone's `notes` line.

| Source | What it gives | When |
|---|---|---|
| `OpenCone/Resources/ModelCatalog/ModelCatalog.json`, built in | The models the app knows, in menu order, with their reasoning efforts and summaries; the default model; retired models and where a saved one moves | Always |
| GET /models with the person's OpenAI key | Which models the account can use, and each one's `shutdown_date` | Once per launch (`SettingsViewModel.refreshAccountModels`) |
| The model's page on OpenAI's docs site, `https://developers.openai.com/api/docs/models/<id>.md` | Reasoning efforts, a summary, and whether the Responses API supports it, for a model the built-in list does not name | The first time the account lists the model, again after 7 days, at most 3 pages per launch |

A new general-purpose model (for example `gpt-6.2-sol`) appears at the top of the model menu at the next launch after
the account lists it. Until its page has been read, its reasoning options start at low (GPT-6 Astra and GPT-6.1 Sol
reject `none` with HTTP 400). A page that says the Responses API does not support the model takes it out of the menu.

A model whose GET /models entry has a `shutdown_date` within 30 days, or past, counts as retired: it leaves the model
menu, and a saved choice of it moves to its replacement when Settings loads or the account list is refreshed. A
retired model with no replacement of its own follows the longest retired entry that has one (`o1-mini` follows `o1`
to `gpt-5.6-sol`), or moves to `defaultModel` when none matches.

## What OpenCone uses from it

| Piece | Where |
|---|---|
| Default model | `Configuration.completionModel`, which is `CurrentModelCatalog.defaultModel` |
| Model menu | `SettingsViewModel.availableCompletionModels`, `CurrentModelCatalog.selectionModels` |
| Reasoning efforts offered, and the effort sent | `CurrentModelCatalog.reasoningEfforts(for:)` and `normalizedEffort(_:model:)`, applied in Settings and to routing calls |
| Retired models | `CurrentModelCatalog.isRetired` and `replacement(for:)`, applied when Settings loads |
| Background model | `CurrentModelCatalog.utilityModel` (`gpt-6-luna`) drafts each index's one-line summary |

OpenResponses also reads `pro` (reasoning mode) and `asyncTools` from the list; OpenCone keeps those fields so the
file stays identical, but does not send either.

The file's format, its validation (`ModelCatalog.problem()`) and its upkeep are described in OpenResponses'
`docs/model-catalog.md`.
