#!/usr/bin/env python3
"""Static checks for the Scaling Journey sources.

This is not a Swift compiler. It is the strongest verification available on a
machine without an Apple toolchain, and it catches the mistakes that are both
most likely and most expensive to find in Xcode:

  * unbalanced braces/parens/brackets (with a real Swift lexer, so strings,
    interpolation, raw strings and nested block comments do not confuse it)
  * duplicate or missing type declarations across the module
  * references to project types that are never declared
  * missing imports for the frameworks a file actually uses
  * malformed project file, asset catalog JSON, plists and scheme XML

Run: python3 Scripts/validate_sources.py
"""

from __future__ import annotations

import json
import pathlib
import re
import sys
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parent.parent
APP_DIR = ROOT / "ScalingJourney"
TEST_DIR = ROOT / "ScalingJourneyTests"

errors: list[str] = []
warnings: list[str] = []


def fail(msg: str) -> None:
    errors.append(msg)


def warn(msg: str) -> None:
    warnings.append(msg)


# ---------------------------------------------------------------- lexer ----

def strip_swift(source: str) -> str:
    """Replace comments and string contents with spaces, preserving offsets.

    A context stack handles the case that trips up naive scanners: string
    interpolation, which re-enters code (and can open further strings) in the
    middle of a literal. Keeping the output the same length means reported line
    numbers stay accurate.
    """
    out = list(source)
    n = len(source)
    i = 0
    # Each frame is either {"kind": "string", "quote": ..., "hashes": ...}
    # or {"kind": "interp", "depth": int}.
    stack: list[dict] = []

    def blank(a: int, b: int) -> None:
        for k in range(a, min(b, n)):
            if out[k] != "\n":
                out[k] = " "

    while i < n:
        top = stack[-1] if stack else None

        # ---- inside a string literal ----
        if top is not None and top["kind"] == "string":
            quote, hashes = top["quote"], top["hashes"]
            terminator = quote + hashes
            if source.startswith(terminator, i):
                blank(i, i + len(terminator))
                i += len(terminator)
                stack.pop()
                continue
            interpolation = "\\" + hashes + "("
            if source.startswith(interpolation, i):
                blank(i, i + len(interpolation))
                i += len(interpolation)
                stack.append({"kind": "interp", "depth": 1})
                continue
            if source[i] == "\\" and not hashes:
                blank(i, i + 2)
                i += 2
                continue
            if quote == '"' and source[i] == "\n":
                # An unterminated single-line string; recover at the newline.
                stack.pop()
                i += 1
                continue
            if source[i] != "\n":
                out[i] = " "
            i += 1
            continue

        # ---- code context (top level, or inside an interpolation) ----
        if source.startswith("//", i):
            j = source.find("\n", i)
            j = n if j == -1 else j
            blank(i, j)
            i = j
            continue

        if source.startswith("/*", i):
            depth, j = 1, i + 2
            while j < n and depth:
                if source.startswith("/*", j):
                    depth += 1
                    j += 2
                elif source.startswith("*/", j):
                    depth -= 1
                    j += 2
                else:
                    j += 1
            blank(i, j)
            i = j
            continue

        opener = re.match(r'(#*)("""|")', source[i:])
        if opener:
            blank(i, i + len(opener.group(0)))
            i += len(opener.group(0))
            stack.append({"kind": "string", "quote": opener.group(2), "hashes": opener.group(1)})
            continue

        ch = source[i]
        if top is not None and top["kind"] == "interp":
            if ch == "(":
                top["depth"] += 1
            elif ch == ")":
                top["depth"] -= 1
                if top["depth"] == 0:
                    stack.pop()
                    out[i] = " "
                    i += 1
                    continue
        i += 1

    return "".join(out)


PAIRS = {"}": "{", ")": "(", "]": "["}


def check_balance(path: pathlib.Path, code: str) -> None:
    stack: list[tuple[str, int]] = []
    line = 1
    for ch in code:
        if ch == "\n":
            line += 1
        elif ch in "{([":
            stack.append((ch, line))
        elif ch in PAIRS:
            if not stack:
                fail(f"{path.relative_to(ROOT)}:{line}: unmatched closing '{ch}'")
                return
            opener, opened_at = stack.pop()
            if opener != PAIRS[ch]:
                fail(
                    f"{path.relative_to(ROOT)}:{line}: '{ch}' closes '{opener}' "
                    f"opened on line {opened_at}"
                )
                return
    if stack:
        opener, opened_at = stack[-1]
        fail(f"{path.relative_to(ROOT)}: unclosed '{opener}' opened on line {opened_at}")


# --------------------------------------------------------- declarations ----

DECL_RE = re.compile(
    r"^\s*(?:@\w+(?:\([^)]*\))?\s+)*"
    r"(?:public\s+|internal\s+|private\s+|fileprivate\s+|final\s+|indirect\s+)*"
    r"(struct|class|enum|protocol|actor|extension)\s+([A-Z_]\w*)",
    re.MULTILINE,
)
TYPEALIAS_RE = re.compile(r"^\s*(?:\w+\s+)*typealias\s+([A-Z_]\w*)", re.MULTILINE)


def collect_declarations(code: str) -> tuple[set[str], set[str]]:
    """Returns (declared type names, extended type names)."""
    declared: set[str] = set()
    extended: set[str] = set()
    for kind, name in DECL_RE.findall(code):
        (extended if kind == "extension" else declared).add(name)
    declared.update(TYPEALIAS_RE.findall(code))
    return declared, extended


# --------------------------------------------------------------- imports ----

# framework -> regex of symbols that require it
IMPORT_RULES = {
    "SwiftUI": r"@State\b|@Binding\b|@Environment\b|@FocusState\b|@ViewBuilder\b|@Bindable\b|\bsome View\b|\b(?:VStack|HStack|ZStack|LazyVGrid|NavigationStack|ScrollView|ViewModifier|ButtonStyle|ToolbarContent|Divider|Spacer|GeometryReader)\b|\bBinding<|\bText\(|\bImage\(|\bColor\.",
    "SwiftData": r"\b(?:ModelContext|ModelContainer|FetchDescriptor|ModelConfiguration|PersistentModel|VersionedSchema|SchemaMigrationPlan|Schema)\b|@Model\b|@Relationship\b",
    "UIKit": r"\b(?:UIImage|UIGraphicsImageRenderer|UIViewControllerRepresentable|UIImagePickerController|UIColor|UIGraphicsImageRendererFormat)\b",
    "PhotosUI": r"\bPhotosPicker(?:Item)?\b",
    "ImageIO": r"\bCGImageSource\w*\b|\bkCGImageProperty\w+\b",
    "Security": r"\bSecItem\w+\b|\bkSec\w+\b",
    "OSLog": r"\bLogger\(",
    "Observation": r"@Observable\b",
    "Foundation": r"\b(?:Date|UUID|URL|Data|Calendar|Locale|NumberFormatter|DateFormatter)\b",
}
# Frameworks that re-export another, so importing the key satisfies the value.
REEXPORTS = {
    "SwiftUI": {"Foundation", "Observation"},
    "UIKit": {"Foundation"},
    "PhotosUI": {"Foundation"},
    "SwiftData": {"Foundation", "Observation"},
    "XCTest": {"Foundation"},
}


def check_imports(path: pathlib.Path, code: str) -> None:
    imports = set(re.findall(r"^\s*(?:@testable\s+)?import\s+(\w+)", code, re.MULTILINE))
    satisfied = set(imports)
    for imported in imports:
        satisfied |= REEXPORTS.get(imported, set())

    for framework, pattern in IMPORT_RULES.items():
        if framework in satisfied:
            continue
        match = re.search(pattern, code)
        if match:
            line = code[: match.start()].count("\n") + 1
            fail(
                f"{path.relative_to(ROOT)}:{line}: uses '{match.group(0)}' "
                f"but does not import {framework}"
            )


# ------------------------------------------------------------ file sweep ----

def swift_files(directory: pathlib.Path) -> list[pathlib.Path]:
    return sorted(directory.rglob("*.swift"))


app_files = swift_files(APP_DIR)
test_files = swift_files(TEST_DIR)

if not app_files:
    fail("No Swift sources found in ScalingJourney/")

app_declared: dict[str, pathlib.Path] = {}
app_extended: set[str] = set()
app_code: dict[pathlib.Path, str] = {}

for path in app_files + test_files:
    raw = path.read_text()
    code = strip_swift(raw)
    app_code[path] = code
    check_balance(path, code)
    check_imports(path, raw)

    declared, extended = collect_declarations(code)
    if path in app_files:
        app_extended |= extended
        for name in declared:
            if name in app_declared:
                fail(
                    f"{path.relative_to(ROOT)}: '{name}' is declared twice "
                    f"(also in {app_declared[name].relative_to(ROOT)})"
                )
            else:
                app_declared[name] = path

# Exactly one @main entry point.
main_count = sum(1 for c in app_code.values() if re.search(r"^\s*@main\b", c, re.MULTILINE))
if main_count != 1:
    fail(f"Expected exactly one @main entry point, found {main_count}")

# Every project-prefixed symbol referenced must exist. Restricted to names the
# project owns so Apple SDK symbols do not produce noise.
PROJECT_SYMBOL_RE = re.compile(r"\b(SJ[A-Z]\w+|Theme|AppLog|AppTab|ChangeTint|MassUnit|PhotoPose|PhotoVariant|EntrySource|SyncState|AppSchema\w*|AppMigrationPlan|AppConfiguration|AppDependencies|JourneyStore|AuthController|Account|AuthProvider|AuthCredentials|AuthError|WeightFormatter|WeightParser|StoneComponents|ProgressStatistics|DateRangeFilter|WeightEntry\w*|ProgressPhoto|UserProfile|PhotoSnapshot|ProfileSnapshot|StoredPhoto|PhotoStore\w*|FilePhotoStore|ImageProcessing|ImageMetadata|ModelContainerFactory|ProfileEdits|ProfileRepository|SwiftData\w*Repository|RepositoryError|SyncEngine|DisabledSyncEngine|LogEntry\w*|CameraPicker|HomeView|HomeHeroCard|GoalProgressSection|LatestPhotoCard|RecentEntriesCard|PhotoAttachmentSection|ProgressDashboardView|EntryCalendarView|CalendarMonthGrid|CalendarDayCell|CalendarDay|DayDetailSheet|SettingsView|GoalEditorView|MainTabView|RootView|AccountIdentifierStore|KeychainAccountIdentifierStore|InMemoryAccountIdentifierStore|LocalAccountAuthenticationService|AuthenticationService|PhotoStore)\b")

test_declared: set[str] = set()
for path in test_files:
    declared, extended = collect_declarations(app_code[path])
    test_declared |= declared | extended

known = set(app_declared) | app_extended | test_declared
for path, code in app_code.items():
    for symbol in set(PROJECT_SYMBOL_RE.findall(code)):
        if symbol not in known:
            fail(f"{path.relative_to(ROOT)}: references undeclared project type '{symbol}'")

# Private types must not be referenced from another file.
for path in app_files:
    code = app_code[path]
    for match in re.finditer(r"^\s*private\s+(?:struct|class|enum|actor)\s+([A-Z]\w*)", code, re.MULTILINE):
        name = match.group(1)
        for other in app_files:
            if other == path:
                continue
            if re.search(rf"\b{name}\b", app_code[other]):
                fail(
                    f"{other.relative_to(ROOT)}: uses '{name}', which is "
                    f"declared private in {path.relative_to(ROOT)}"
                )

# ------------------------------------------------------- project & assets ---

pbx = ROOT / "ScalingJourney.xcodeproj" / "project.pbxproj"
if not pbx.exists():
    fail("Missing ScalingJourney.xcodeproj/project.pbxproj")
else:
    text = pbx.read_text()
    if text.count("{") != text.count("}"):
        fail(f"project.pbxproj brace mismatch: {text.count('{')} open, {text.count('}')} close")

    defined = set(re.findall(r"^\t\t(SJ[0-9A-F]{22})\s+/?\*?", text, re.MULTILINE))
    referenced = set(re.findall(r"\b(SJ[0-9A-F]{22})\b", text))
    for missing in sorted(referenced - defined):
        fail(f"project.pbxproj references object {missing}, which is never defined")
    for unused in sorted(defined - (referenced - defined)):
        # Every object should be reachable from at least one other place.
        if text.count(unused) < 2:
            warn(f"project.pbxproj object {unused} is defined but never referenced")

    # The Info.plist the target points at must exist.
    for match in re.finditer(r"^\s*INFOPLIST_FILE = ([^;]+);", text, re.MULTILINE):
        plist_path = ROOT / match.group(1).strip().strip('"')
        if not plist_path.exists():
            fail(f"INFOPLIST_FILE points at missing file: {match.group(1).strip()}")

    for match in re.finditer(r"^\s*CODE_SIGN_ENTITLEMENTS = ([^;]+);", text, re.MULTILINE):
        ent = ROOT / match.group(1).strip().strip('"')
        if not ent.exists():
            fail(f"CODE_SIGN_ENTITLEMENTS points at missing file: {match.group(1).strip()}")

for json_path in (APP_DIR / "Resources").rglob("Contents.json"):
    try:
        json.loads(json_path.read_text())
    except json.JSONDecodeError as exc:
        fail(f"{json_path.relative_to(ROOT)}: invalid JSON ({exc})")

for xml_path in list(ROOT.rglob("*.plist")) + list(ROOT.rglob("*.xcscheme")) + list(ROOT.rglob("*.entitlements")):
    if ".git" in xml_path.parts or "build" in xml_path.parts:
        continue
    try:
        ET.parse(xml_path)
    except ET.ParseError as exc:
        fail(f"{xml_path.relative_to(ROOT)}: invalid XML ({exc})")

# --------------------------------------------------------------- secrets ---

gitignore = (ROOT / ".gitignore").read_text() if (ROOT / ".gitignore").exists() else ""
if "Config/Secrets.xcconfig" not in gitignore:
    fail(".gitignore must exclude Config/Secrets.xcconfig")
if (ROOT / "Config" / "Secrets.xcconfig").exists():
    fail("Config/Secrets.xcconfig exists in the working tree and must never be committed")

# ---------------------------------------------------------------- report ---

print(f"Checked {len(app_files)} app sources and {len(test_files)} test sources.")
for w in warnings:
    print(f"  warning: {w}")
for e in errors:
    print(f"  error:   {e}")

if errors:
    print(f"\nFAILED with {len(errors)} error(s).")
    sys.exit(1)
print(f"\nPASSED{f' with {len(warnings)} warning(s)' if warnings else ''}.")
