# AI Agent Rules

## Language Policy
- All OpenSpec-related content MUST be written in Simplified Chinese.
- This includes:
  - proposal.md
  - specs/*.md
  - tasks.md
- Do not generate English narrative text.
- English is allowed only for:
  - Code identifiers
  - Protocol names (HTTP, REST, JWT, etc.)
  - Standard technical acronyms
- Code comments MUST be in English, kept concise.

## Tech Stack
- **Framework**: Flutter 3.x + Dart 3.x
- **State management**: Riverpod (flutter_riverpod + riverpod_annotation)
- **Local storage**: drift (SQLite ORM) with typed DSL and migration support
- **Routing**: go_router (declarative)
- **Architecture**: Feature-First + 三层架构 (Data → Domain → Presentation)
- **ID strategy**: UUID v4
- **Platform**: iOS + Android, local-first, offline-capable
- **Coding conventions**: See `.cursor/skills/flutter-development/SKILL.md` for full guide

## Dart/Flutter Coding Rules
- Follow Effective Dart naming: `UpperCamelCase` types, `lowerCamelCase` members, `snake_case` files.
- Use `const` constructors wherever possible.
- Explicit return types on public APIs; avoid `var`/`dynamic`.
- Use `final` for local variables; prefer immutable data models.
- Functions ≤ 50 lines; max nesting 3 levels.
- No `print()` — use `debugPrint()` or a logging package.
- Format all Dart code with `dart format`.

## Spec Discipline
- Specs describe system behavior, not UI.
- Avoid UI terms such as 页面、按钮、点击、弹窗.
- Use SHALL / MUST for mandatory behavior.

## Source of Truth
- PRD is the only requirement source.
- Do not introduce assumptions beyond PRD.