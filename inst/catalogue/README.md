# The methods catalogue

`methods.csv` is the literature scan's `methods_catalogue.csv` (roadmap step 2,
2026-10-28; 115 rows, 23 columns; SHA-256
`a6b549bfc210c75cda924de031ba6f139f63acdbfe93313e42660b8ff34de61d`), unchanged, with
nine columns added for the engine (design section 3.2):

| column | meaning |
|---|---|
| `role` | `primary_eligible`, `agreement`, `describe_only` (F1), `diagnostic`, `adjustment`, `read_external` (F2), `excluded` |
| `question` | the question it answers (Q0-Q11) |
| `needs_unit` | units it accepts (`count`, `proportion`, `presence`, `any`, joined by `|`) |
| `needs` | what the bundle must have: `tree`, `denominator`, `subject_id`, `negative_controls`, `set_column`, `paired_layer`, `two_layers`, `pairs`, `external_result` |
| `handles_repeated` | `yes` / `no` |
| `min_group` | smallest group size (rule R-MINGRP) |
| `priority` | order for the override rule (E4) among Q4 methods |
| `milestone` | the milestone that builds it |
| `engine_note` | why it has its role; for `excluded`, the reason (F3 GitHub-only, C5/C10/C11 not in v1, or not in the approved method tables) |

It is a table of methods, not data, so the repository's no-data check allows it by name.
